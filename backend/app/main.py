"""FireWatch API - classificacao e predicao de risco de incendio florestal.

Fluxo: GPS (app mobile) -> Open-Meteo -> Random Forest -> nivel de risco -> app.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import __version__
from app.models.schemas import HealthResponse
from app.routes.risk import risk_router
from app.services.prediction_service import ModelNotAvailableError, prediction_service
from ml.features import FEATURES

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
logger = logging.getLogger("firewatch")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Pre-aquece o modelo na subida para o primeiro request ser rapido."""
    try:
        prediction_service.carregar()
        logger.info("Modelo ML pronto para uso.")
    except ModelNotAvailableError as exc:
        logger.warning("API subiu sem modelo: %s", exc)
    yield
    logger.info("API FireWatch encerrada.")


app = FastAPI(
    title="FireWatch API",
    description=(
        "API de classificacao e predicao de risco de incendio florestal. "
        "Recebe latitude/longitude do aplicativo mobile, consulta a Open-Meteo "
        "e aplica um modelo Random Forest para retornar probabilidade, nivel "
        "de risco e recomendacao."
    ),
    version=__version__,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.include_router(risk_router)


@app.get("/", tags=["geral"], summary="Informacoes da API")
async def raiz() -> dict[str, str]:
    return {
        "projeto": "FireWatch",
        "descricao": "Classificacao e predicao de risco de incendio florestal",
        "versao": __version__,
        "docs": "/docs",
        "health": "/health",
        "predicao": "POST /api/v1/prever-risco",
    }

@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["geral"],
    summary="Verifica saude do servico e do modelo",
)
async def health() -> HealthResponse:
    carregado = prediction_service.carregado
    metricas = {}
    if carregado:
        metricas = prediction_service.metadados().get("metricas") or {}

    return HealthResponse(
        status="ok" if carregado else "degradado",
        versao=__version__,
        modelo_carregado=carregado,
        features=list(FEATURES),
        acerto_estimado=metricas.get("accuracy") if carregado else None,
    )
