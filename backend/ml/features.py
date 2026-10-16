"""Engenharia de features do FireWatch.

Este e o unico lugar onde as features sao definidas. O treinamento
(`ml/treinamento.py`) e a inferencia em producao
(`app/services/prediction_service.py`) importam daqui, garantindo que o modelo
receba exatamente as mesmas colunas, na mesma ordem, com a mesma formula.

Semantica do dataset de risco de incendio (tabela `firewatch_dados`):

- As cinco variaveis climaticas (``temp_max``, ``temp_min``, ``umidade``,
  ``precipitacao_mm``, ``velocidade_vento``) sao medias climatologicas por
  municipio, em unidades fisicas (graus Celsius, %, mm e km/h).
- ``dias_sem_chuva`` e o numero de dias consecutivos sem chuva (dinamico).
  No dataset ele foi disponibilizado ja padronizado (z-score); a escala
  bruta usada para converter o valor calculado em producao esta em
  :data:`ESCALA_DIAS_SEM_CHUVA`.

No banco as colunas climaticas aparecem com o prefixo ``avg_`` e em z-score;
:data:`DESPADRONIZACAO` guarda as medias/desvios que revertem essa
padronizacao para as unidades fisicas originais.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from typing import Any

#: Ordem canonica das features. Nao reordenar sem retreinar o modelo.
FEATURES: tuple[str, ...] = (
    "temp_max",
    "temp_min",
    "umidade",
    "precipitacao_mm",
    "velocidade_vento",
    "dias_sem_chuva",
)

#: (media, desvio) de cada coluna climatica, usados para DESPADRONIZAR as
#: colunas ``avg_*`` do banco (que estao em z-score) de volta para unidades
#: fisicas. Valores calculados sobre o dataset FireWatch 2024 (2024-01-01 a
#: 2024-09-30, 177.779 registros).
DESPADRONIZACAO: dict[str, tuple[float, float]] = {
    "temp_max": (29.351207751048904, 2.8806145456908023),
    "temp_min": (20.673921365422, 3.509741905308333),
    "umidade": (71.91912512718264, 9.0274019718513),
    "precipitacao_mm": (3.829831744268072, 1.7716769719344598),
    "velocidade_vento": (16.38251736973688, 2.7418845978464566),
}

#: (media, desvio) para converter o numero de dias sem chuva (unidades brutas)
#: na escala z-score em que o modelo foi treinado. A escala bruta do dataset
#: nao foi preservada: foi recuperada mapeando a faixa observada de z-score
#: (-0.7398 .. 3.1731) para o intervalo fisico 0 .. 60 dias sem chuva.
ESCALA_DIAS_SEM_CHUVA: tuple[float, float] = (11.344, 15.334)

#: Limites fisicos plausiveis. Valores fora sao recortados (clip) para evitar
#: que um outlier da Open-Meteo exploda a predicao.
LIMITES: dict[str, tuple[float, float]] = {
    "temp_max": (-20.0, 60.0),
    "temp_min": (-30.0, 45.0),
    "umidade": (1.0, 100.0),
    "precipitacao_mm": (0.0, 300.0),
    "velocidade_vento": (0.0, 200.0),
    "dias_sem_chuva": (0.0, 180.0),
}

#: Valores usados quando a fonte nao devolve um campo (mediana do dataset).
VALOR_POR_OMISSAO: dict[str, float] = {
    "temp_max": 29.0,
    "temp_min": 21.0,
    "umidade": 72.0,
    "precipitacao_mm": 3.8,
    "velocidade_vento": 16.4,
    "dias_sem_chuva": 8.0,
}


def despadronizar(coluna: str, z: float) -> float:
    """Reverte o z-score de uma coluna climatica para unidades fisicas."""
    media, desvio = DESPADRONIZACAO[coluna]
    return z * desvio + media


def padronizar_dias_sem_chuva(dias: float) -> float:
    """Converte dias sem chuva (bruto) para a escala z-score do modelo."""
    media, desvio = ESCALA_DIAS_SEM_CHUVA
    return (dias - media) / desvio


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
    """Converte um dicionario de clima em um vetor de features do modelo.

    ``bruto`` deve trazer as variaveis em unidades fisicas:
    ``temp_max``, ``temp_min``, ``umidade``, ``precipitacao_mm``,
    ``velocidade_vento`` e ``dias_sem_chuva`` (dias consecutivos sem chuva).
    """
    dias_bruto = _valor(bruto, "dias_sem_chuva")
    return {
        "temp_max": round(_valor(bruto, "temp_max"), 4),
        "temp_min": round(_valor(bruto, "temp_min"), 4),
        "umidade": round(_valor(bruto, "umidade"), 4),
        "precipitacao_mm": round(_valor(bruto, "precipitacao_mm"), 4),
        "velocidade_vento": round(_valor(bruto, "velocidade_vento"), 4),
        "dias_sem_chuva": round(padronizar_dias_sem_chuva(dias_bruto), 4),
    }


def vetor_features(bruto: Mapping[str, Any]) -> list[float]:
    """Features como lista na ordem canonica (formato exigido pelo modelo)."""
    features = construir_features(bruto)
    return [features[nome] for nome in FEATURES]
