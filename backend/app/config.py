"""Configuração da aplicação via variáveis de ambiente."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configurações do FireWatch Backend."""

    OPEN_METEO_URL: str = "https://api.open-meteo.com/v1/forecast"
    OPEN_METEO_TIMEOUT: float = 10.0
    CACHE_TTL_SEGUNDOS: float = 300.0
    PERMITIR_FALLBACK_CLIMA: bool = False
    CORS_ORIGINS: str | list[str] = []
    RISK_RATE_PER_MINUTE: int = Field(default=60, ge=1, le=10000)
    REGIONAL_RATE_PER_MINUTE: int = Field(default=6, ge=1, le=1000)

    # Configurações do banco de dados
    DB_HOST: str = "localhost"
    DB_PORT: int = 5432
    DB_NAME: str = "firewatch_db"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = ""

    model_config = SettingsConfigDict(
        # caminho absoluto: o .env e encontrado independente do diretorio de execucao
        env_file=str(Path(__file__).resolve().parent.parent / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: Any) -> list[str]:
        if isinstance(v, list):
            origins = v
        elif isinstance(v, str):
            origins = [origin.strip() for origin in v.split(",") if origin.strip()]
        else:
            raise ValueError("CORS_ORIGINS deve conter origens explícitas.")
        if any(not isinstance(origin, str) or "*" in origin for origin in origins):
            raise ValueError("Use origens explícitas em CORS_ORIGINS; curingas não são permitidos.")
        return origins

@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
