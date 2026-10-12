"""Engenharia de features do FireWatch.

Este modulo e o unico lugar onde as features sao definidas. O treinamento
(`ml/treinamento.py`) e a inferencia em producao
(`app/services/prediction_service.py`) importam daqui, garantindo que o modelo
receba exatamente as mesmas colunas, na mesma ordem, com a mesma formula.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from typing import Any

#: Ordem canonica das features. Nao reordenar sem retreinar o modelo.
FEATURES: tuple[str, ...] = (
    "temperature_2m",
    "relative_humidity_2m",
    "precipitation",
    "wind_speed_10m",
    "apparent_temperature",
    "dew_point_2m",
    "wind_gusts_10m",
    "uv_index_max",
    "cloud_cover",
    "vpd_kpa",
    "aridity_index",
)

#: Features obrigatorias (as quatro variaveis centrais do projeto).
FEATURES_CENTRAIS: tuple[str, ...] = FEATURES[:4]

#: Valor usado quando a Open-Meteo nao devolve um campo opcional.
#: Coerente com as medianas observadas no dataset FireWatch 2024.
VALOR_POR_OMISSAO: dict[str, float] = {
    "apparent_temperature": 22.0,
    "dew_point_2m": 12.0,
    "wind_gusts_10m": 22.0,
    "uv_index_max": 6.0,
    "cloud_cover": 40.0,
}

#: Faixas plausiveis. Valores fora sao recortados (clip) para evitar que um
#: outlier da API exploda a predicao.
LIMITES: dict[str, tuple[float, float]] = {
    "temperature_2m": (-50.0, 60.0),
    "relative_humidity_2m": (1.0, 100.0),
    "precipitation": (0.0, 300.0),
    "wind_speed_10m": (0.0, 200.0),
    "apparent_temperature": (-60.0, 65.0),
    "dew_point_2m": (-60.0, 40.0),
    "wind_gusts_10m": (0.0, 250.0),
    "uv_index_max": (0.0, 16.0),
    "cloud_cover": (0.0, 100.0),
}


def pressao_saturacao_vapor(temperatura_c: float) -> float:
    """Pressao de vapor saturado (kPa) pela equacao de Magnus.

    Tetens/Magnus: es = 0.6108 * exp(17.27 * T / (T + 237.3))
    """
    return 0.6108 * math.exp(17.27 * temperatura_c / (temperatura_c + 237.3))


def deficit_pressao_vapor(temperatura_c: float, umidade_relativa: float) -> float:
    """VPD em kPa: quao seco esta o ar para a vegetacao (principal driver de fogo)."""
    es = pressao_saturacao_vapor(temperatura_c)
    ea = es * (umidade_relativa / 100.0)
    return max(0.0, es - ea)


def indice_aridez(vpd: float, vento_kmh: float, precipitacao: float) -> float:
    """Indice composto de aridez usado pelo modelo.

    Combina deficit de umidade do ar, energia do vento e ausencia de chuva.
    Escala 0 (dia chuvoso e umido) a ~100 (seco, ventoso e sem chuva).
    """
    componente_umidade = min(100.0, vpd * 12.0)
    componente_vento = min(100.0, vento_kmh * 2.5)
    componente_chuva = max(0.0, 100.0 - precipitacao * 60.0)
    return round(
        0.50 * componente_umidade + 0.30 * componente_vento + 0.20 * componente_chuva,
        4,
    )


def _valor(bruto: Mapping[str, Any], chave: str) -> float:
    """Le um campo, aplica omissao e recorte de faixa."""
    default = VALOR_POR_OMISSAO.get(chave)
    valor = bruto.get(chave)
    if valor is None:
        if default is None:
            raise KeyError(f"Feature obrigatoria ausente: {chave}")
        return default
    try:
        numero = float(valor)
    except (TypeError, ValueError) as exc:
        if default is None:
            raise KeyError(f"Feature obrigatoria invalida: {chave}={valor!r}") from exc
        return default
    if math.isnan(numero) or math.isinf(numero):
        if default is None:
            raise KeyError(f"Feature obrigatoria invalida: {chave}={valor!r}")
        return default

    minimo, maximo = LIMITES.get(chave, (-1e9, 1e9))
    return min(max(numero, minimo), maximo)


def construir_features(bruto: Mapping[str, Any]) -> dict[str, float]:
    """Converte um dicionario de clima em um vetor de features do modelo."""
    temperatura = _valor(bruto, "temperature_2m")
    umidade = _valor(bruto, "relative_humidity_2m")
    precipitacao = _valor(bruto, "precipitation")
    vento = _valor(bruto, "wind_speed_10m")

    vpd = deficit_pressao_vapor(temperatura, umidade)

    return {
        "temperature_2m": temperatura,
        "relative_humidity_2m": umidade,
        "precipitation": precipitacao,
        "wind_speed_10m": vento,
        "apparent_temperature": _valor(bruto, "apparent_temperature"),
        "dew_point_2m": _valor(bruto, "dew_point_2m"),
        "wind_gusts_10m": _valor(bruto, "wind_gusts_10m"),
        "uv_index_max": _valor(bruto, "uv_index_max"),
        "cloud_cover": _valor(bruto, "cloud_cover"),
        "vpd_kpa": round(vpd, 4),
        "aridity_index": indice_aridez(vpd, vento, precipitacao),
    }


def vetor_features(bruto: Mapping[str, Any]) -> list[float]:
    """Features como lista na ordem canonica (formato exigido pelo modelo)."""
    features = construir_features(bruto)
    return [features[nome] for nome in FEATURES]