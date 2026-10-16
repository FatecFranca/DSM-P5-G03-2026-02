"""Schemas de entrada e saida da API FireWatch."""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class RiskLevel(StrEnum):
    """Niveis de risco de incendio florestal."""

    BAIXO = "BAIXO"
    MODERADO = "MODERADO"
    CRITICO = "CRÍTICO"

    @property
    def label(self) -> str:
        return {
            RiskLevel.BAIXO: "Baixo",
            RiskLevel.MODERADO: "Moderado",
            RiskLevel.CRITICO: "Crítico",
        }[self]


class LocationRequest(BaseModel):
    """Payload enviado pelo app mobile com a localizacao do usuario."""

    model_config = ConfigDict(
        json_schema_extra={"example": {"latitude": -20.5386, "longitude": -47.4008}}
    )

    latitude: float = Field(
        ..., ge=-90.0, le=90.0, description="Latitude em graus decimais (WGS84)."
    )
    longitude: float = Field(
        ..., ge=-180.0, le=180.0, description="Longitude em graus decimais (WGS84)."
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
    # Campos diarios usados pelas features do modelo (unidades fisicas).
    temperatura_max_c: float | None = Field(
        default=None, description="Temperatura maxima do dia, em graus Celsius."
    )
    temperatura_min_c: float | None = Field(
        default=None, description="Temperatura minima do dia, em graus Celsius."
    )
    precipitacao_diaria_mm: float | None = Field(
        default=None, ge=0.0, description="Precipitacao acumulada do dia, em mm."
    )
    vento_max_kmh: float | None = Field(
        default=None, ge=0.0, description="Velocidade maxima do vento no dia, em km/h."
    )
    dias_sem_chuva: float | None = Field(
        default=None, ge=0.0, description="Dias consecutivos sem chuva."
    )
    horario: datetime | None = Field(
        default=None, description="Horario de referencia da observacao (UTC)."
    )


class LocalizacaoResponse(BaseModel):
    latitude: float
    longitude: float


class DadosClimaticosResponse(BaseModel):
    temperatura: float
    umidade_ar: float
    precipitacao_mm: float
    vento_kmh: float


class ProbabilidadesResponse(BaseModel):
    """Probabilidade prevista de cada classe de risco (0.0 a 1.0)."""

    risco_baixo: float = Field(..., ge=0.0, le=1.0)
    risco_moderado: float = Field(..., ge=0.0, le=1.0)
    risco_critico: float = Field(..., ge=0.0, le=1.0)


class PredicaoResponse(BaseModel):
    probabilidade: float = Field(
        ..., ge=0.0, le=1.0, description="Probabilidade da classe Risco Crítico."
    )
    porcentagem: str
    nivel_risco: str = Field(..., description="BAIXO, MODERADO ou CRÍTICO.")
    classe: str = Field(
        ...,
        description="Risco Baixo, Risco Moderado ou Risco Crítico.",
    )
    cor_alerta: str
    recomendacao: str
    probabilidades: ProbabilidadesResponse | None = None


class RiskResponse(BaseModel):
    status: str = "sucesso"
    localizacao: LocalizacaoResponse
    dados_climaticos: DadosClimaticosResponse
    predicao: PredicaoResponse


class HealthResponse(BaseModel):
    """Estado do servico para o endpoint de health check."""

    status: str
    versao: str
    modelo_carregado: bool
    banco: str | None = Field(
        default=None, description="Estado da conexao com o banco de dados."
    )
    features: list[str] | None = None
    classes: list[str] | None = None
    acerto_estimado: float | None = None
