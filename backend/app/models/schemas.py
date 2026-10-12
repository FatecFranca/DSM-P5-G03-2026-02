"""Schemas de entrada e saida da API FireWatch."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class RiskLevel(str, Enum):
    """Niveis de risco de incendio florestal."""

    BAIXO = "baixo"
    MODERADO = "moderado"
    ALTO = "alto"
    CRITICO = "critico"

    @property
    def label(self) -> str:
        return {
            RiskLevel.BAIXO: "Baixo",
            RiskLevel.MODERADO: "Moderado",
            RiskLevel.ALTO: "Alto",
            RiskLevel.CRITICO: "Critico",
        }[self]

    @classmethod
    def from_probability(cls, probabilidade: float) -> "RiskLevel":
        """Converte a probabilidade continua (0.0 - 1.0) em nivel de risco."""
        if probabilidade >= 0.75:
            return cls.CRITICO
        if probabilidade >= 0.50:
            return cls.ALTO
        if probabilidade >= 0.25:
            return cls.MODERADO
        return cls.BAIXO


class LocationRequest(BaseModel):
    """Payload enviado pelo app mobile com a localizacao do usuario."""

    model_config = ConfigDict(
        json_schema_extra={"example": {"latitude": -23.5505, "longitude": -46.6333}}
    )

    latitude: float = Field(
        ..., ge=-90.0, le=90.0, description="Latitude em graus decimais (WGS84)."
    )
    longitude: float = Field(
        ..., ge=-180.0, le=180.0, description="Longitude em graus decimais (WGS84)."
    )
    nome_local: str | None = Field(
        default=None,
        max_length=120,
        description="Nome opcional do local (cidade/bairro) enviado pelo app.",
    )


class WeatherData(BaseModel):
    """Dados climaticos obtidos da API Open-Meteo."""

    temperatura_c: float = Field(..., description="Temperatura do ar em graus Celsius.")
    umidade_relativa: float = Field(
        ..., ge=0.0, le=100.0, description="Umidade relativa do ar em porcentagem."
    )
    precipitacao_mm: float = Field(
        ..., ge=0.0, description="Precipitacao da ultima hora, em millimetros."
    )
    velocidade_vento_kmh: float = Field(
        ..., ge=0.0, description="Velocidade do vento a 10 metros, em km/h."
    )
    rajada_vento_kmh: float | None = Field(
        default=None, ge=0.0, description="Rajada maxima de vento, em km/h."
    )
    sensacao_termica_c: float | None = Field(
        default=None, description="Sensacao termica apparent, em graus Celsius."
    )
    ponto_de_orvalho_c: float | None = Field(
        default=None, description="Ponto de orvalho, em graus Celsius."
    )
    indice_uv: float | None = Field(
        default=None, ge=0.0, description="Indice UV maximo do dia."
    )
    cobertura_nuvens: float | None = Field(
        default=None, ge=0.0, le=100.0, description="Cobertura de nuvens em porcentagem."
    )
    horario: datetime | None = Field(
        default=None, description="Horario de referencia da observacao (UTC)."
    )


class RiskResponse(BaseModel):
    """Resposta completa do calculo de risco exibida no app."""

    probabilidade: float = Field(
        ..., ge=0.0, le=1.0, description="Probabilidade de incendio (0.0 a 1.0)."
    )
    probabilidade_percentual: float = Field(
        ..., ge=0.0, le=100.0, description="Probabilidade em porcentagem."
    )
    nivel_risco: RiskLevel = Field(..., description="Nivel de risco classificado.")
    descricao: str = Field(..., description="Descricao textual do nivel de risco.")
    recomendacao: str = Field(
        ..., description="Recomendacao de acao para o usuario e a populacao local."
    )
    latitude: float
    longitude: float
    local: str | None = None
    clima: WeatherData
    modelo: dict[str, Any] = Field(
        default_factory=dict, description="Metadados do modelo de Machine Learning."
    )
    gerado_em: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="Instante de geracao da resposta (UTC).",
    )


class HealthResponse(BaseModel):
    """Estado do servico para o endpoint de health check."""

    status: str
    versao: str
    modelo_carregado: bool
    features: list[str] | None = None
    acerto_estimado: float | None = None