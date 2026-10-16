"""Carregamento e execucao do modelo de Machine Learning (Random Forest).

O modelo e um ``RandomForestClassifier`` treinado com dados do banco
(``firewatch_dados``) para prever a classe de risco de fogo do dia
(``Risco Baixo`` / ``Risco Moderado`` / ``Risco Crítico``).

A API expoe as tres probabilidades por classe; o campo ``probabilidade``
principal e a probabilidade de a classe ser ``Risco Crítico``.
"""

from __future__ import annotations

import logging
import threading
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd

from app.models.schemas import WeatherData
from app.services.classificacao import (
    CLASSES,
    RECOMENDACOES,
    classe_do_codigo,
    cor_do_codigo,
    nivel_do_codigo,
)
from ml.alvo import N_CLASSES
from ml.features import FEATURES, construir_features

logger = logging.getLogger(__name__)

#: Caminho padrao do artefato treinado.
MODELO_PADRAO = Path(__file__).resolve().parents[2] / "ml" / "modelo.pkl"


class ModelNotAvailableError(RuntimeError):
    """O artefato modelo.pkl nao existe ou nao pode ser desserializado."""


def _bruto_de_clima(clima: WeatherData) -> dict[str, Any]:
    """Mapeia o clima de producao para as features fisicas do modelo."""
    temp_max = clima.temperatura_max_c if clima.temperatura_max_c is not None else clima.temperatura_c
    temp_min = clima.temperatura_min_c if clima.temperatura_min_c is not None else clima.temperatura_c
    precipitacao = (
        clima.precipitacao_diaria_mm
        if clima.precipitacao_diaria_mm is not None
        else clima.precipitacao_mm
    )
    vento = clima.vento_max_kmh if clima.vento_max_kmh is not None else clima.velocidade_vento_kmh
    dias_sem_chuva = clima.dias_sem_chuva if clima.dias_sem_chuva is not None else 0.0

    return {
        "temp_max": temp_max,
        "temp_min": temp_min,
        "umidade": clima.umidade_relativa,
        "precipitacao_mm": precipitacao,
        "velocidade_vento": vento,
        "dias_sem_chuva": dias_sem_chuva,
    }


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

            classes_do_modelo = tuple(bundle.get("classes") or CLASSES)
            if classes_do_modelo != CLASSES:
                raise ModelNotAvailableError(
                    "Incompatibilidade das classes: "
                    f"modelo treinado com {classes_do_modelo}, codigo espera {CLASSES}. "
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
            "alvo": bundle.get("alvo", "classe_risco"),
            "classes": list(bundle.get("classes") or CLASSES),
            "features": list(bundle.get("features") or FEATURES),
            "treinado_em": bundle.get("treinado_em"),
            "dataset": bundle.get("dataset"),
            "metricas": bundle.get("metricas", {}),
            "importancias": bundle.get("importancias", {}),
        }

    # ---------------------------------------------------------------- predicao

    def prever_probabilidades(self, clima: WeatherData) -> np.ndarray:
        """Probabilidade de cada classe, na ordem dos codigos 0/1/2."""
        bundle = self.carregar()
        modelo = bundle["modelo"]

        features = construir_features(_bruto_de_clima(clima))
        matriz = pd.DataFrame([[features[nome] for nome in FEATURES]], columns=list(FEATURES))

        try:
            proba = np.asarray(modelo.predict_proba(matriz)).ravel()
        except Exception as exc:  # noqa: BLE001
            raise ModelNotAvailableError(f"Erro na predicao: {exc}") from exc

        classes = list(getattr(modelo, "classes_", range(len(proba))))
        ordenado = np.zeros(N_CLASSES, dtype=float)
        for codigo, valor in zip(classes, proba, strict=True):
            ordenado[int(codigo)] = float(valor)
        return ordenado

    def prever_classe(self, clima: WeatherData) -> int:
        """Codigo da classe mais provavel (0=Baixo, 1=Moderado, 2=Critico)."""
        return int(np.argmax(self.prever_probabilidades(clima)))

    def prever(
        self,
        clima: WeatherData,
        latitude: float,
        longitude: float,
        local: str | None = None,
    ) -> dict[str, Any]:
        """Executa a predicao completa e monta o dicionario de resposta."""
        proba = self.prever_probabilidades(clima)
        codigo = int(np.argmax(proba))
        nivel_risco = nivel_do_codigo(codigo)
        classe = classe_do_codigo(codigo)
        cor_alerta = cor_do_codigo(codigo)
        recomendacao = RECOMENDACOES[nivel_risco]

        # Campo principal: probabilidade de a classe ser Risco Critico.
        probabilidade = round(float(np.clip(proba[2], 0.0, 1.0)), 4)
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
                "classe": classe,
                "cor_alerta": cor_alerta,
                "recomendacao": recomendacao,
                "probabilidades": {
                    "risco_baixo": round(float(proba[0]), 4),
                    "risco_moderado": round(float(proba[1]), 4),
                    "risco_critico": round(float(proba[2]), 4),
                },
            },
        }


prediction_service = PredictionService()
