"""Configuração da aplicação via variáveis de ambiente."""

from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configurações do FireWatch Backend."""

    OPEN_METEO_URL: str = "https://api.open-meteo.com/v1/forecast"
    OPEN_METEO_TIMEOUT: float = 10.0
    CACHE_TTL_SEGUNDOS: float = 300.0
    PERMITIR_FALLBACK_CLIMA: bool = False
    CORS_ORIGINS: List[str] = ["*"]

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: str | List[str]) -> List[str]:
        if isinstance(v, list):
            return v
        if isinstance(v, str):
            if v.strip() == "*":
                return ["*"]
            # separa por vírgula
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
