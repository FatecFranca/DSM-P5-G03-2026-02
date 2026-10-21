"""Sanitização de valores meteorológicos fora das faixas físicas.

Na consulta pontual os números finitos são recortados antes de validar o schema.
A análise regional rejeita ajustes para não colorir amostras inválidas.
"""

from __future__ import annotations

import copy
import sys
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app.services.weather_service import WeatherService, WeatherServiceError  # noqa: E402

PAYLOAD = {
    "latitude": -20.5,
    "longitude": -47.4,
    "utc_offset_seconds": -10800,
    "current": {
        "temperature_2m": 25.0,
        "relative_humidity_2m": 50.0,
        "precipitation": 0.0,
        "wind_speed_10m": 10.0,
        "wind_gusts_10m": 20.0,
        "apparent_temperature": 25.0,
        "dew_point_2m": 15.0,
        "cloud_cover": 20.0,
        "time": "2026-10-21T14:00",
    },
    "daily": {
        "uv_index_max": [5.0],
        "temperature_2m_max": [30.0],
        "temperature_2m_min": [20.0],
        "precipitation_sum": [0.0],
        "wind_speed_10m_max": [15.0],
    },
}

CASOS = [
    ("umidade acima de 100%", "relative_humidity_2m", 150.0, "umidade_relativa", 100.0),
    ("precipitação negativa", "precipitation", -1.0, "precipitacao_mm", 0.0),
    ("vento negativo", "wind_speed_10m", -1.0, "velocidade_vento_kmh", 0.0),
    ("rajada negativa", "wind_gusts_10m", -1.0, "rajada_vento_kmh", 0.0),
    ("cobertura de nuvens acima de 100%", "cloud_cover", 150.0, "cobertura_nuvens", 100.0),
]


@pytest.mark.parametrize(
    ("nome", "campo", "valor", "atributo", "esperado"), CASOS
)
def test_valor_fora_da_faixa_eh_recortado(
    nome: str, campo: str, valor: float, atributo: str, esperado: float
):
    payload = copy.deepcopy(PAYLOAD)
    payload["current"][campo] = valor
    dados = WeatherService(permitir_fallback=False)._parse(payload)
    assert getattr(dados, atributo) == esperado, nome


@pytest.mark.parametrize(("nome", "campo", "valor", "atributo", "esperado"), CASOS)
def test_modo_regional_rejeita_ajustes_para_nao_colorir_amostras_invalidas(
    nome: str, campo: str, valor: float, atributo: str, esperado: float
):
    payload = copy.deepcopy(PAYLOAD)
    payload["current"][campo] = valor
    with pytest.raises(WeatherServiceError, match="faixa física"):
        WeatherService(permitir_fallback=False, permitir_ajustes=False)._parse(payload)
