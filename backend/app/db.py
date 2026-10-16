"""Database connection module for FireWatch Backend.

Provides async PostgreSQL connection support using asyncpg.
Integrates with the FastAPI app via dependency injection.
"""

import asyncio
import logging
import os
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from pathlib import Path

import asyncpg
from dotenv import load_dotenv

# Carrega variaveis do .env localizado na pasta do backend
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

logger = logging.getLogger(__name__)


def get_db_config() -> dict:
    """Return database configuration from environment variables."""
    password = os.getenv("DB_PASSWORD", "")
    # Remove surrounding quotes if present (common in .env files)
    if (password.startswith('"') and password.endswith('"')) or (
        password.startswith("'") and password.endswith("'")
    ):
        password = password[1:-1]
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432")),
        "database": os.getenv("DB_NAME", "firewatch_db"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": password,
    }


class Database:
    """Manages a single asyncpg connection pool for the application."""

    def __init__(self) -> None:
        self.pool: asyncpg.Pool | None = None
        self._lock = asyncio.Lock()

    async def init(self) -> None:
        """Inicializa o pool de conexoes (idempotente e seguro sob concorrencia)."""
        if self.pool is not None:
            return
        async with self._lock:
            if self.pool is not None:  # outra corrotina ja inicializou
                return
            config = get_db_config()
            self.pool = await asyncpg.create_pool(
                host=config["host"],
                port=config["port"],
                database=config["database"],
                user=config["user"],
                password=config["password"],
                min_size=1,
                max_size=10,
                command_timeout=60,
            )
        logger.info(
            "Pool de conexoes DB inicializado: %s:%s/%s",
            config["host"],
            config["port"],
            config["database"],
        )

    async def close(self) -> None:
        """Close the connection pool."""
        if self.pool:
            await self.pool.close()
            self.pool = None

    @asynccontextmanager
    async def get_connection(self) -> AsyncGenerator[asyncpg.Connection, None]:
        """Get a connection from the pool (context manager)."""
        if not self.pool:
            await self.init()
        async with self.pool.acquire() as conn:
            yield conn


# Instancia global do banco de dados
db = Database()
