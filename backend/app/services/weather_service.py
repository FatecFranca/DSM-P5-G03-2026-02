"""Integracao com a API Open-Meteo para obtencao de dados climaticos em tempo real.

Fonte: https://api.open-meteo.com/v1/forecast
Documentacao: https://open-meteo.com/en/docs
"""

from __future__ import annotations

import logging
import math
import time
from datetime import datetime, timezone

import httpx

from app.config import settings
from app.models.schemas import WeatherData

logger = logging.getLogger(__name__)

OPEN_METEO_URL = settings.OPEN_METEO_URL

CURRENT_FIELDS = (
    "temperature_2m",
    "relative_humidity_2m",
    "apparent_temperature",
    "dew_point_2m",
    "precipitation",
    "cloud_cover",
    "wind_speed_10m",
    "wind_gusts_10m",
)

#: Limites fisicos usados para sanity check antes de devolver ao modelo.
LIMITE_TEMPERATURA_C = (-70.0, 65.0)
LIMITE_UMIDADE = (-1.0, 101.0)
LIMITE_PRECIPITACAO = (-0.5, 400.0)
LIMITE_VENTO_KMH = (-1.0, 250.0)
