"""Aplica migrations SQL pendentes sem alterar migrations já registradas."""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path

import asyncpg

from app.db import get_db_config

MIGRATIONS = Path(__file__).resolve().parents[1] / "migrations"
logger = logging.getLogger(__name__)


async def aplicar() -> None:
    conn = await asyncpg.connect(**get_db_config(), timeout=15)
    try:
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS public.schema_migrations (
                versao text PRIMARY KEY,
                aplicada_em timestamptz NOT NULL DEFAULT now()
            )
            """
        )
        aplicadas = set(
            await conn.fetchval("SELECT array_agg(versao) FROM public.schema_migrations") or []
        )
        for caminho in sorted(MIGRATIONS.glob("*.sql")):
            if caminho.name in aplicadas:
                logger.info("Migration já aplicada: %s", caminho.name)
                continue
            async with conn.transaction():
                await conn.execute(caminho.read_text(encoding="utf-8"))
                await conn.execute(
                    "INSERT INTO public.schema_migrations (versao) VALUES ($1)", caminho.name
                )
            logger.info("Migration aplicada: %s", caminho.name)
    finally:
        await conn.close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
    asyncio.run(aplicar())
