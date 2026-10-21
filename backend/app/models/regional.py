"""Contrato da amostragem regional de risco; a resolução não implica precisão por rua."""

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict

from app.models.schemas import LocalizacaoResponse, LocationRequest, RiskResponse


class RegionalRequest(LocationRequest):
    model_config = ConfigDict(extra="forbid")


class CellProperties(BaseModel):
    amostra: LocalizacaoResponse
    estado: Literal["ok", "sem_dados"]
    resultado: RiskResponse | None = None
    consultado_em: datetime | None = None
    expira_em: datetime | None = None
    horario_meteorologico: datetime | None = None
    celula_meteorologica: LocalizacaoResponse | None = None


class RegionalFeature(BaseModel):
    type: Literal["Feature"] = "Feature"
    id: str
    geometry: dict[str, Any]
    properties: CellProperties


class RegionalResponse(BaseModel):
    type: Literal["FeatureCollection"] = "FeatureCollection"
    estado: Literal["completo", "parcial", "sem_dados"]
    centro: LocalizacaoResponse
    bbox: list[float]
    resolucao_graus: float
    versao_modelo: str
    gerado_em: datetime
    features: list[RegionalFeature]
