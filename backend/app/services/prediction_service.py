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

from app.models.schemas import WeatherData
from app.services.classificacao import RECOMENDACOES, classificar
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
        matriz = pd.DataFrame([[features[nome] for nome in FEATURES]], columns=list(FEATURES))

        try:
            if hasattr(modelo, "predict_proba"):
                probabilidades = modelo.predict_proba(matriz)
                classes = list(modelo.classes_)
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
        probabilidade = round(float(self.prever_probabilidade(clima)), 3)
        probabilidade = max(0.0, min(1.0, probabilidade))
        cls = classificar(probabilidade)
        nivel_risco = cls["nivel_risco"]
        cor_alerta = cls["cor_alerta"]
        recomendacao = RECOMENDACOES[nivel_risco]
        porcentagem = f"{probabilidade * 100.0:.1f}%"

        return {
            "status": "sucesso",
            "localizacao": {
                "latitude": latitude,
                "longitude": longitude,
            },
            "dados_climaticos": {
                "temperatura": float(clima.temperatura_c),
                "umidade_ar": float(clima.umidade_relativa),
                "precipitacao_mm": float(clima.precipitacao_mm),
                "vento_kmh": float(clima.velocidade_vento_kmh),
            },
            "predicao": {
                "probabilidade": probabilidade,
                "porcentagem": porcentagem,
                "nivel_risco": nivel_risco,
                "cor_alerta": cor_alerta,
                "recomendacao": recomendacao,
            },
        }


prediction_service = PredictionService()
