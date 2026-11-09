"""Consultas leves e paginadas ao dataset oficial."""

from __future__ import annotations

import logging
from datetime import date
from typing import Any

from app.db import db

logger = logging.getLogger(__name__)


class DatasetUnavailableError(RuntimeError):
    """O dataset não pôde ser consultado no PostgreSQL."""


def _filtros(
    data_inicio: date | None,
    data_fim: date | None,
    estado: str | None,
    municipio: str | None,
    bioma: str | None,
) -> tuple[str, list[Any]]:
    condicoes: list[str] = []
    valores: list[Any] = []
    for coluna, operador, valor in (
        ("data", ">=", data_inicio),
        ("data", "<=", data_fim),
        ("estado", "=", estado),
        ("municipio", "=", municipio),
        ("bioma", "=", bioma),
    ):
        if valor is not None:
            valores.append(valor)
            condicoes.append(f"{coluna} {operador} ${len(valores)}")
    return (" WHERE " + " AND ".join(condicoes) if condicoes else ""), valores


class DatasetService:
    async def listar(
        self,
        *,
        pagina: int,
        por_pagina: int,
        data_inicio: date | None,
        data_fim: date | None,
        estado: str | None,
        municipio: str | None,
        bioma: str | None,
    ) -> tuple[list[dict[str, Any]], int]:
        where, valores = _filtros(data_inicio, data_fim, estado, municipio, bioma)
        limite = len(valores) + 1
        deslocamento = len(valores) + 2
        try:
            async with db.get_connection() as conn:
                total = await conn.fetchval(
                    f"SELECT count(*) FROM public.firewatch_preprocessado{where}",
                    *valores,
                )
                registros = await conn.fetch(
                    f"""
                    SELECT linha_origem, data, municipio, estado, bioma,
                           avg_numero_dias_sem_chuva, avg_precipitacao,
                           avg_risco_fogo, avg_frp, bioma_ausente_original
                    FROM public.firewatch_preprocessado{where}
                    ORDER BY data DESC, estado, municipio, linha_origem
                    LIMIT ${limite} OFFSET ${deslocamento}
                    """,
                    *valores,
                    por_pagina,
                    (pagina - 1) * por_pagina,
                )
        except Exception as exc:  # noqa: BLE001
            logger.error("Falha ao consultar dataset: %s", exc)
            raise DatasetUnavailableError("Dataset indisponível no momento.") from exc
        return [dict(registro) for registro in registros], int(total)

    async def estatisticas(
        self,
        *,
        data_inicio: date | None,
        data_fim: date | None,
        estado: str | None,
        municipio: str | None,
        bioma: str | None,
    ) -> dict[str, Any]:
        where, valores = _filtros(data_inicio, data_fim, estado, municipio, bioma)
        try:
            async with db.get_connection() as conn:
                registro = await conn.fetchrow(
                    f"""
                    SELECT count(*) AS total_registros,
                           min(data) AS data_inicial,
                           max(data) AS data_final,
                           avg(avg_numero_dias_sem_chuva) AS media_dias_sem_chuva,
                           avg(avg_precipitacao) AS media_precipitacao,
                           avg(avg_risco_fogo) AS media_risco_fogo,
                           avg(avg_frp) AS media_frp
                    FROM public.firewatch_preprocessado{where}
                    """,
                    *valores,
                )
        except Exception as exc:  # noqa: BLE001
            logger.error("Falha ao agregar dataset: %s", exc)
            raise DatasetUnavailableError("Dataset indisponível no momento.") from exc
        return dict(registro)


dataset_service = DatasetService()
