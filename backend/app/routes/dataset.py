"""Endpoints de leitura do dataset histórico oficial."""

import math
from datetime import date
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query

from app.models.dataset import DatasetListResponse, DatasetStatsResponse, Paginacao
from app.services.dataset_service import DatasetUnavailableError, dataset_service

dataset_router = APIRouter(prefix="/api/v1/dados", tags=["dados"])
TextoFiltro = Annotated[str | None, Query(min_length=1, max_length=100)]


def _validar_periodo(data_inicio: date | None, data_fim: date | None) -> None:
    if data_inicio and data_fim and data_inicio > data_fim:
        raise HTTPException(status_code=422, detail="data_inicio deve ser anterior a data_fim.")


@dataset_router.get("", response_model=DatasetListResponse, summary="Lista o dataset histórico")
async def listar_dados(
    pagina: Annotated[int, Query(ge=1, le=10_000)] = 1,
    por_pagina: Annotated[int, Query(ge=1, le=100)] = 50,
    data_inicio: date | None = None,
    data_fim: date | None = None,
    estado: TextoFiltro = None,
    municipio: TextoFiltro = None,
    bioma: TextoFiltro = None,
) -> DatasetListResponse:
    _validar_periodo(data_inicio, data_fim)
    try:
        dados, total = await dataset_service.listar(
            pagina=pagina,
            por_pagina=por_pagina,
            data_inicio=data_inicio,
            data_fim=data_fim,
            estado=estado,
            municipio=municipio,
            bioma=bioma,
        )
    except DatasetUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return DatasetListResponse(
        dados=dados,
        paginacao=Paginacao(
            pagina=pagina,
            por_pagina=por_pagina,
            total_registros=total,
            total_paginas=math.ceil(total / por_pagina),
        ),
    )


@dataset_router.get(
    "/estatisticas",
    response_model=DatasetStatsResponse,
    summary="Resume o dataset histórico",
)
async def estatisticas_dados(
    data_inicio: date | None = None,
    data_fim: date | None = None,
    estado: TextoFiltro = None,
    municipio: TextoFiltro = None,
    bioma: TextoFiltro = None,
) -> DatasetStatsResponse:
    _validar_periodo(data_inicio, data_fim)
    try:
        resultado = await dataset_service.estatisticas(
            data_inicio=data_inicio,
            data_fim=data_fim,
            estado=estado,
            municipio=municipio,
            bioma=bioma,
        )
    except DatasetUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return DatasetStatsResponse(**resultado)
