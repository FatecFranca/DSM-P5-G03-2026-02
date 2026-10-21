"""Endpoints de consulta de risco de incendio florestal."""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, status

from app.models.regional import RegionalRequest, RegionalResponse
from app.models.schemas import LocationRequest, RiskResponse
from app.services.prediction_service import (
    ModelNotAvailableError,
    prediction_service,
)
from app.services.regional_service import (
    OutsideCoverageError,
    RegionalBusyError,
    regional_service,
)
from app.services.weather_service import WeatherServiceError, weather_service

logger = logging.getLogger(__name__)

risk_router = APIRouter(prefix="/api/v1", tags=["risco"])


@risk_router.post("/risco-regional", response_model=RegionalResponse,
                  summary="Amostra até nove zonas de risco no Brasil")
async def risco_regional(localizacao: RegionalRequest) -> RegionalResponse:
    try:
        return await regional_service.analyze(localizacao.latitude, localizacao.longitude)
    except OutsideCoverageError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RegionalBusyError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except ModelNotAvailableError as exc:
        raise HTTPException(status_code=503, detail="Modelo de previsão indisponível.") from exc


@risk_router.post(
    "/prever-risco",
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
            detail="Serviço de clima indisponível no momento. Tente novamente em instantes.",
        ) from exc

    try:
        resultado = prediction_service.prever(
            clima=clima,
            latitude=localizacao.latitude,
            longitude=localizacao.longitude,
            local=None,
        )
    except ModelNotAvailableError as exc:
        logger.error("Modelo indisponivel: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Modelo de previsao indisponivel: {exc}",
        ) from exc

    return RiskResponse(**resultado)
