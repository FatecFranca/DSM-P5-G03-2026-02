"""Schemas Pydantic do FireWatch."""

from app.models.schemas import (
    HealthResponse,
    LocationRequest,
    RiskLevel,
    RiskResponse,
    WeatherData,
)

__all__ = [
    "HealthResponse",
    "LocationRequest",
    "RiskLevel",
    "RiskResponse",
    "WeatherData",
]
