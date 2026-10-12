"""Endpoints de consulta de risco de incendio florestal."""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query, status

from app.models.schemas import LocationRequest, RiskResponse
from app.services.prediction_service import (
    ModelNotAvailableError,
    prediction_service,
)
from app.services.weather_service import WeatherServiceError, weather_service

logger = logging.getLogger(__name__)

risk_router = APIRouter(prefix="/api/v1", tags=["risco"])


@risk_router.post(
    "/risk",
    response_model=RiskResponse,
    summary="Prediz o risco de incendio a partir da localizacao",
    responses={
        200: {"description": "Predicao concluida"},
        422: {"description": "Coordenadas invalidas"},
        503: {"description": "Open-Meteo ou modelo indisponivel"},
    },
)
async def prever_risco(localizacao: LocationRequest) -> RiskResponse:
    """Fluxo completo: GPS -> Open-Meteo -> modelo de ML -> nivel de risco."""
    try:
        clima = await weather_service.obter_clima(
            latitude=localizacao.latitude,
            longitude=localizacao.longitude,
        )
    except WeatherServiceError as exc:
        logger.error("Falha na Open-Meteo: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Nao foi possivel obter dados climaticos: {exc}",
        ) from exc

    try:
        resultado = prediction_service.prever(
            clima=clima,
            latitude=localizacao.latitude,
            longitude=localizacao.longitude,
            local=localizacao.nome_local,
        )
    except ModelNotAvailableError as exc:
        logger.error("Modelo indisponivel: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Modelo de previsao indisponivel: {exc}",
        ) from exc

    return RiskResponse(**resultado)


@risk_router.get(
    "/risk",
    response_model=RiskResponse,
    summary="Prediz o risco por query string (latitude/longitude)",
)
async def prever_risco_por_query(
    latitude: float = Query(
        ..., ge=-90.0, le=90.0, description="Latitude em graus decimais."
    ),
    longitude: float = Query(
        ..., ge=-180.0, le=180.0, description="Longitude em graus decimais."
    ),
    local: str | None = Query(default=None, max_length=120),
) -> RiskResponse:
    """Variante GET do endpoint de risco, util para testes rapidos com curl."""
    return await prever_risco(
        LocationRequest(latitude=latitude, longitude=longitude, nome_local=local)
    )