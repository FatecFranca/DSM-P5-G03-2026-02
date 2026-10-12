"""Carregamento e execucao do modelo de Machine Learning (Random Forest)."""

from __future__ import annotations

import logging
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd

from app.models.schemas import RiskLevel, WeatherData
from ml.features import FEATURES, construir_features

logger = logging.getLogger(__name__)

#: Caminho padrao do artefato treinado.
MODELO_PADRAO = Path(__file__).resolve().parents[2] / "ml" / "modelo.pkl"


class ModelNotAvailableError(RuntimeError):
    """O artefato modelo.pkl nao existe ou nao pode ser desserializado."""


class PredictionService:
    """Carrega o modelo uma vez e responde consultas de risco."""

    def __init__(self, caminho: Path | str | None = None) -> None:
        self.caminho = Path(caminho) if caminho else MODELO_PADRAO
        self._bundle: dict[str, Any] | None = None
        self._lock = threading.Lock()

    # ------------------------------------------------------------- ciclo de vida

    def carregar(self) -> dict[str, Any]:
        """Desserializa o modelo.pkl (uma unica vez, de forma thread-safe)."""
        if self._bundle is not None:
            return self._bundle

        with self._lock:
            if self._bundle is not None:
                return self._bundle

            if not self.caminho.exists():
                raise ModelNotAvailableError(
                    f"Modelo nao encontrado em {self.caminho}. "
                    "Execute: python ml/treinamento.py"
                )
            try:
                bundle = joblib.load(self.caminho)
            except Exception as exc:  # noqa: BLE001
                raise ModelNotAvailableError(
                    f"Falha ao carregar {self.caminho.name}: {exc}"
                ) from exc

            if "modelo" not in bundle:
                raise ModelNotAvailableError(
                    f"{self.caminho.name} invalido: chave 'modelo' ausente."
                )

            features_do_modelo = tuple(bundle.get("features") or FEATURES)
            if features_do_modelo != FEATURES:
                raise ModelNotAvailableError(
                    "Incompatibilidade entre o modelo e o codigo: "
                    f"modelo treinado com {features_do_modelo}, codigo espera {FEATURES}. "
                    "Retreine com: python ml/treinamento.py"
                )

            self._bundle = bundle
            logger.info("Modelo carregado de %s", self.caminho)
            return self._bundle

    @property
    def carregado(self) -> bool:
        return self._bundle is not None

    def metadados(self) -> dict[str, Any]:
        """Informacoes publicas sobre o modelo, sem expor o estimador."""
        bundle = self._bundle or {}
        return {
            "arquivo": self.caminho.name,
            "algoritmo": bundle.get("algoritmo", "RandomForestClassifier"),
            "features": list(bundle.get("features") or FEATURES),
            "treinado_em": bundle.get("treinado_em"),
            "dataset": bundle.get("dataset"),
            "metricas": bundle.get("metricas", {}),
            "limiares": bundle.get("limiares", {}),
            "importancias": bundle.get("importancias", {}),
        }

    # ---------------------------------------------------------------- predicao

    def prever_probabilidade(self, clima: WeatherData) -> float:
        """Retorna a probabilidade de incendio (0.0 - 1.0) para um clima."""
        bundle = self.carregar()
        modelo = bundle["modelo"]

        bruto = {
            "temperature_2m": clima.temperatura_c,
            "relative_humidity_2m": clima.umidade_relativa,
            "precipitation": clima.precipitacao_mm,
            "wind_speed_10m": clima.velocidade_vento_kmh,
            "apparent_temperature": clima.sensacao_termica_c,
            "dew_point_2m": clima.ponto_de_orvalho_c,
            "wind_gusts_10m": clima.rajada_vento_kmh,
            "uv_index_max": clima.indice_uv,
            "cloud_cover": clima.cobertura_nuvens,
        }

        features = construir_features(bruto)
        # DataFrame (e nao ndarray) para preservar os nomes das colunas: o
        # SimpleImputer foi ajustado com nomes e o scikit-learn emite aviso
        # -- e perde a validacao de schema -- quando recebe um array cru.
        matriz = pd.DataFrame([[features[nome] for nome in FEATURES]], columns=list(FEATURES))

        try:
            if hasattr(modelo, "predict_proba"):
                probabilidades = modelo.predict_proba(matriz)
                classes = list(modelo.classes_)
                # Binario: coluna da classe positiva (risco = 1).
                coluna = classes.index(1) if 1 in classes else -1
                return float(np.clip(probabilidades[0][coluna], 0.0, 1.0))
            return float(np.clip(modelo.predict(matriz)[0], 0.0, 1.0))
        except Exception as exc:  # noqa: BLE001
            raise ModelNotAvailableError(f"Erro na predicao: {exc}") from exc

    def prever(
        self,
        clima: WeatherData,
        latitude: float,
        longitude: float,
        local: str | None = None,
    ) -> dict[str, Any]:
        """Executa a predicao completa e monta o dicionario de resposta."""
        probabilidade = self.prever_probabilidade(clima)
        nivel = RiskLevel.from_probability(probabilidade)
        return {
            "probabilidade": probabilidade,
            "probabilidade_percentual": round(probabilidade * 100.0, 1),
            "nivel_risco": nivel,
            "descricao": DESCRICOES[nivel],
            "recomendacao": RECOMENDACOES[nivel],
            "latitude": latitude,
            "longitude": longitude,
            "local": local,
            "clima": clima,
            "modelo": self.metadados(),
            "gerado_em": datetime.now(timezone.utc),
        }


DESCRICOES: dict[RiskLevel, str] = {
    RiskLevel.BAIXO: (
        "Condicoes climaticas favoraveis ao controle da umidade do ambiente. "
        "Risco reduzido de inicio e propagacao de focos de incendio."
    ),
    RiskLevel.MODERADO: (
        "Condicoes climaticas intermediarias. Zonas florestais podem apresentar "
        "pontos isolados de inflamabilidade se houver atividade humana com fogo."
    ),
    RiskLevel.ALTO: (
        "Ambiente seco e/ou ventoso. Favorece a propagacao de incendio emareas "
        "florestais. Cuidado redobrado com qualquer fonte de calor."
    ),
    RiskLevel.CRITICO: (
        "Condicoes severas para o inicio de incendio: ar muito seco, vento forte "
        "e calor elevado. Qualquer foco tem alto potencial de se tornar um grande "
        "incendio."
    ),
}

RECOMENDACOES: dict[RiskLevel, str] = {
RiskLevel.BAIXO: (
        "Nenhuma acao urgente. Evite jogar lixo e faiscas e mantenha-se atento "
        "a avisos oficiais."
    ),
RiskLevel.MODERADO: (
        "Nao realizar queimadas nem usar fogo. Confira se o terreno ao redor da "
        "casa esta limpo e umido o suficiente para impedir a propagacao."
    ),
RiskLevel.ALTO: (
        "Suspenda qualquer atividade com fogo e evite utilizar lenha acesa. "
        "Mantenha mangueiras e extintores prontos e evite circular em estradas "
        "de terra com vegetacao seca."
    ),
RiskLevel.CRITICO: (
        "Alerta maximo. Nao acenda fogueiras, mantenha-se informado nos canais "
        "oficiais (Defesa Civil / IBAMA) e fique preparado para evacuar caso haja "
        "ordem de evacuacao na sua regiao."
    ),
}


prediction_service = PredictionService()