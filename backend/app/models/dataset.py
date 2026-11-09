from datetime import date

from pydantic import BaseModel


class DatasetRecord(BaseModel):
    linha_origem: int
    data: date
    municipio: str
    estado: str
    bioma: str
    avg_numero_dias_sem_chuva: float
    avg_precipitacao: float
    avg_risco_fogo: float
    avg_frp: float
    bioma_ausente_original: bool


class Paginacao(BaseModel):
    pagina: int
    por_pagina: int
    total_registros: int
    total_paginas: int


class DatasetListResponse(BaseModel):
    dados: list[DatasetRecord]
    paginacao: Paginacao


class DatasetStatsResponse(BaseModel):
    total_registros: int
    data_inicial: date | None
    data_final: date | None
    media_dias_sem_chuva: float | None
    media_precipitacao: float | None
    media_risco_fogo: float | None
    media_frp: float | None
