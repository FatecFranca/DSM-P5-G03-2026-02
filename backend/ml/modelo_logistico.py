"""Entradas do modelo logístico gerado pelo projeto de Machine Learning."""

from __future__ import annotations

import math
from datetime import date

FEATURES: tuple[str, ...] = (
    "avg_numero_dias_sem_chuva",
    "precipitacao_mm_estimada",
    "dia_ano_seno",
    "dia_ano_cosseno",
)


def construir_features(
    *,
    dias_sem_chuva: float | None,
    precipitacao_mm: float | None,
    data_referencia: date,
) -> dict[str, float]:
    """Reproduz as quatro entradas usadas no treinamento do artefato final."""

    dia_ano = data_referencia.timetuple().tm_yday
    angulo = 2 * math.pi * dia_ano / 366.0
    return {
        "avg_numero_dias_sem_chuva": float("nan")
        if dias_sem_chuva is None
        else float(dias_sem_chuva),
        "precipitacao_mm_estimada": float("nan")
        if precipitacao_mm is None
        else float(precipitacao_mm),
        "dia_ano_seno": math.sin(angulo),
        "dia_ano_cosseno": math.cos(angulo),
    }
