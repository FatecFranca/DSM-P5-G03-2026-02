"""Contrato do modelo logístico gerado a partir do dataset preprocessado."""

import os
from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from app.models.schemas import WeatherData
from app.services.prediction_service import PredictionService
from ml.modelo_logistico import FEATURES, construir_features


def test_features_reproduzem_exatamente_o_pipeline_do_modelo_novo():
    atributos = construir_features(
        dias_sem_chuva=12.0,
        precipitacao_mm=4.5,
        data_referencia=date(2024, 1, 1),
    )

    assert FEATURES == (
        "avg_numero_dias_sem_chuva",
        "precipitacao_mm_estimada",
        "dia_ano_seno",
        "dia_ano_cosseno",
    )
    assert atributos["avg_numero_dias_sem_chuva"] == 12.0
    assert atributos["precipitacao_mm_estimada"] == 4.5
    assert atributos["dia_ano_seno"] == pytest.approx(0.0171663, abs=1e-7)
    assert atributos["dia_ano_cosseno"] == pytest.approx(0.9998526, abs=1e-7)


def test_modelo_novo_mantem_as_tres_classes_e_probabilidades(modelo_novo: Path):
    servico = PredictionService(modelo_novo)
    clima = WeatherData(
        temperatura_c=30.0,
        umidade_relativa=35.0,
        precipitacao_mm=0.0,
        velocidade_vento_kmh=12.0,
        precipitacao_diaria_mm=4.5,
        dias_sem_chuva=12.0,
        horario=datetime(2026, 9, 5, 12, tzinfo=UTC),
    )

    probabilidades = servico.prever_probabilidades(clima)

    assert servico.metadados()["algoritmo"].startswith("LogisticRegression")
    assert len(probabilidades) == 3
    assert probabilidades.sum() == pytest.approx(1.0)
    assert all(0.0 <= valor <= 1.0 for valor in probabilidades)


@pytest.fixture
def modelo_novo() -> Path:
    caminho = Path(os.getenv("MODEL_PATH", ""))
    if not caminho.is_file():
        pytest.skip("defina MODEL_PATH para testar o artefato final")
    return caminho
