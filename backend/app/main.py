"""FireWatch API - classificacao e predicao de risco de incendio florestal.

Fluxo: GPS (app mobile) -> Open-Meteo -> Random Forest -> nivel de risco -> app.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.config import settings
from app.db import db, get_db_config
from app.models.schemas import HealthResponse
from app.rate_limit import RiskRateLimitMiddleware
from app.routes.risk import risk_router
from app.services.classificacao import CLASSES
from app.services.prediction_service import ModelNotAvailableError, prediction_service
from ml.features import FEATURES

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
logger = logging.getLogger("firewatch")


def _rotas_registradas(app: FastAPI) -> list[tuple[str, str, str]]:
    """Lista (metodo, caminho, resumo) a partir do schema OpenAPI publicado.

    Usar o schema evita depender da estrutura interna de ``app.routes``, que
    muda entre versoes do FastAPI (ex.: ``_IncludedRouter``).
    """
    esquema = app.openapi()
    rotas: list[tuple[str, str, str]] = []
    for caminho, operacoes in sorted(esquema.get("paths", {}).items()):
        for metodo, detalhe in operacoes.items():
            if metodo.upper() in {"HEAD", "OPTIONS"}:
                continue
            rotas.append((metodo.upper(), caminho, detalhe.get("summary", "")))
    return rotas


async def _verificar_banco() -> bool:
    """Garante o pool de conexoes e testa uma consulta simples."""
    cfg = get_db_config()
    destino = f"{cfg['user']}@{cfg['host']}:{cfg['port']}/{cfg['database']}"
    try:
        async with db.get_connection() as conn:
            await conn.fetchval("SELECT 1")
    except Exception as exc:  # noqa: BLE001 - a API deve subir mesmo sem banco
        logger.error("[FALHA] Banco de dados ....... %s (%s)", destino, exc)
        return False
    logger.info("[OK]    Banco de dados ....... %s", destino)
    return True


def _verificar_modelo() -> bool:
    """Carrega o modelo e registra algoritmo, classes, features e acuracia."""
    try:
        prediction_service.carregar()
    except ModelNotAvailableError as exc:
        logger.error("[FALHA] Modelo ML ........... %s", exc)
        return False

    meta = prediction_service.metadados()
    logger.info("[OK]    Modelo ML ........... %s", meta.get("algoritmo"))
    logger.info("        classes ............. %s", ", ".join(meta.get("classes", [])))
    logger.info("        features ............ %s", ", ".join(meta.get("features", [])))
    if meta.get("treinado_em"):
        logger.info("        treinado em ......... %s", meta["treinado_em"])
    acuracia = (meta.get("metricas") or {}).get("accuracy")
    if acuracia is not None:
        logger.info("        acuracia (teste) .... %.4f", acuracia)
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Verifica as dependencias, registra o estado e lista os endpoints na subida."""
    logger.info("=" * 68)
    logger.info("FireWatch API v%s - iniciando", __version__)
    logger.info("=" * 68)

    banco_ok = await _verificar_banco()
    modelo_ok = _verificar_modelo()

    logger.info("-" * 68)
    logger.info(
        "Open-Meteo ...... %s (timeout=%.0fs, cache=%.0fs, fallback=%s)",
        settings.OPEN_METEO_URL,
        settings.OPEN_METEO_TIMEOUT,
        settings.CACHE_TTL_SEGUNDOS,
        settings.PERMITIR_FALLBACK_CLIMA,
    )
    logger.info("CORS ............ %s", ", ".join(settings.CORS_ORIGINS))

    rotas = _rotas_registradas(app)
    logger.info("-" * 68)
    logger.info("Endpoints disponiveis (%d):", len(rotas))
    for metodo, caminho, resumo in rotas:
        logger.info("  %-6s %-26s %s", metodo, caminho, resumo)

    logger.info("-" * 68)
    if banco_ok and modelo_ok:
        logger.info("STATUS: OK - API pronta. Documentacao em http://127.0.0.1:8000/docs")
    else:
        pendentes = [
            nome for nome, ok in (("banco", banco_ok), ("modelo", modelo_ok)) if not ok
        ]
        logger.warning("STATUS: DEGRADADO - indisponivel: %s", ", ".join(pendentes))
    logger.info("=" * 68)

    yield

    # Limpeza ao encerrar
    await db.close()
    logger.info("API FireWatch encerrada.")


app = FastAPI(
    title="FireWatch API",
    description=(
        "API de classificacao e predicao de risco de incendio florestal. "
        "Recebe latitude/longitude do aplicativo mobile, consulta a Open-Meteo "
        "e aplica um classificador Random Forest que retorna a classe de risco "
        "(Risco Baixo / Risco Moderado / Risco Critico), as probabilidades de "
        "cada classe e uma recomendacao."
    ),
    version=__version__,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    RiskRateLimitMiddleware,
    limits={
        "/api/v1/prever-risco": settings.RISK_RATE_PER_MINUTE,
        "/api/v1/risco-regional": settings.REGIONAL_RATE_PER_MINUTE,
    },
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.include_router(risk_router)


@app.exception_handler(RequestValidationError)
async def entrada_invalida(_request, exc: RequestValidationError) -> JSONResponse:
    # O JSON recebido pode conter NaN/Infinity. Não ecoar o campo input evita
    # falha de serialização e mantém o contrato 422 sem devolver dados enviados.
    erros = [
        {chave: erro[chave] for chave in ("loc", "msg", "type")}
        for erro in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": erros})


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

    # Verifica conectividade com banco de dados
    db_status = "desconectado"
    try:
        async with db.get_connection() as conn:
            await conn.fetchval("SELECT 1")
            db_status = "ok"
    except Exception:  # noqa: BLE001
        db_status = "erro"

    return HealthResponse(
        status="ok" if carregado else "degradado",
        versao=__version__,
        modelo_carregado=carregado,
        banco=db_status,
        features=list(FEATURES),
        classes=list(CLASSES),
        acerto_estimado=metricas.get("accuracy"),
    )
