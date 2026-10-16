"""Endpoints de consulta de risco de incendio florestal."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status

from app.db import db
from app.models.schemas import LocationRequest, RiskResponse
from app.services.prediction_service import (
    ModelNotAvailableError,
    prediction_service,
)
from app.services.weather_service import WeatherServiceError, weather_service

logger = logging.getLogger(__name__)

risk_router = APIRouter(prefix="/api/v1", tags=["risco"])


async def get_db():
    """Dependency que fornece uma conexão do pool de DB."""
    async with db.get_connection() as conn:
        yield conn


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


@risk_router.get("/db-test", tags=["geral"], summary="Testa conexão com banco de dados")
async def db_test(conn=Depends(get_db)):
    """Testa a conexão com o banco de dados."""
    try:
        result = await conn.fetchrow(
            "SELECT current_user AS usuario, current_database() AS banco"
        )
        return {"status": "ok", "usuario": str(result["usuario"]), "banco": str(result["banco"])}
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao conectar com o banco de dados: {exc}",
        ) from exc
