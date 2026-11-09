"""Importa o CSV oficial em lotes, sem manter o dataset inteiro na memória."""

from __future__ import annotations

import argparse
import asyncio
import csv
import logging
import math
from collections.abc import Iterator
from datetime import date
from pathlib import Path

import asyncpg

from app.db import get_db_config

COLUNAS = (
    "linha_origem",
    "data",
    "municipio",
    "estado",
    "bioma",
    "avg_numero_dias_sem_chuva",
    "avg_precipitacao",
    "avg_risco_fogo",
    "avg_frp",
    "bioma_ausente_original",
)
logger = logging.getLogger(__name__)


class DatasetSchemaError(ValueError):
    """O arquivo não corresponde ao schema oficial esperado."""


def _texto(valor: str | None, coluna: str) -> str:
    texto = (valor or "").strip()
    if not texto:
        raise DatasetSchemaError(f"{coluna} vazio")
    return texto


def _numero(valor: str | None, coluna: str, minimo: float, maximo: float | None = None) -> float:
    try:
        numero = float(valor or "")
    except ValueError as exc:
        raise DatasetSchemaError(f"{coluna} não é numérico") from exc
    if not math.isfinite(numero) or numero < minimo or (maximo is not None and numero > maximo):
        raise DatasetSchemaError(f"{coluna} fora da faixa esperada")
    return numero


def _registro(linha: dict[str, str | None]) -> tuple:
    try:
        origem = int(linha["linha_origem"] or "")
        data_registro = date.fromisoformat(linha["data"] or "")
    except (TypeError, ValueError) as exc:
        raise DatasetSchemaError("linha_origem ou data inválida") from exc
    if origem <= 0:
        raise DatasetSchemaError("linha_origem deve ser positiva")
    booleano = linha["bioma_ausente_original"]
    if booleano not in {"True", "False"}:
        raise DatasetSchemaError("bioma_ausente_original deve ser True ou False")
    return (
        origem,
        data_registro,
        _texto(linha["municipio"], "municipio"),
        _texto(linha["estado"], "estado"),
        _texto(linha["bioma"], "bioma"),
        _numero(linha["avg_numero_dias_sem_chuva"], "avg_numero_dias_sem_chuva", 0),
        _numero(linha["avg_precipitacao"], "avg_precipitacao", 0),
        _numero(linha["avg_risco_fogo"], "avg_risco_fogo", 0, 100),
        _numero(linha["avg_frp"], "avg_frp", 0),
        booleano == "True",
    )


def iterar_lotes(arquivo: Path, tamanho_lote: int = 10_000) -> Iterator[list[tuple]]:
    if tamanho_lote < 1:
        raise ValueError("tamanho_lote deve ser positivo")
    with arquivo.open(encoding="utf-8-sig", newline="") as origem:
        leitor = csv.DictReader(origem)
        if tuple(leitor.fieldnames or ()) != COLUNAS:
            raise DatasetSchemaError(
                f"colunas inválidas: esperado {list(COLUNAS)}, recebido {leitor.fieldnames}"
            )
        lote: list[tuple] = []
        for numero_linha, linha in enumerate(leitor, start=2):
            try:
                lote.append(_registro(linha))
            except DatasetSchemaError as exc:
                raise DatasetSchemaError(f"linha {numero_linha}: {exc}") from exc
            if len(lote) == tamanho_lote:
                yield lote
                lote = []
        if lote:
            yield lote


async def importar(arquivo: Path, tamanho_lote: int = 10_000) -> tuple[int, int]:
    if not arquivo.is_file():
        raise FileNotFoundError(f"Dataset não encontrado: {arquivo}")
    conn = await asyncpg.connect(**get_db_config(), timeout=15)
    try:
        async with conn.transaction():
            await conn.execute(
                "CREATE TEMP TABLE firewatch_importacao "
                "(LIKE public.firewatch_preprocessado INCLUDING DEFAULTS) ON COMMIT DROP"
            )
            total = 0
            for lote in iterar_lotes(arquivo, tamanho_lote):
                await conn.copy_records_to_table(
                    "firewatch_importacao", records=lote, columns=COLUNAS
                )
                total += len(lote)
                logger.info("Validados e enviados %s registros", total)

            duplicados = await conn.fetchval(
                """
                SELECT count(*) FROM (
                    SELECT 1 FROM firewatch_importacao
                    GROUP BY linha_origem HAVING count(*) > 1
                ) AS repetidos
                """
            )
            chaves_duplicadas = await conn.fetchval(
                """
                SELECT count(*) FROM (
                    SELECT 1 FROM firewatch_importacao
                    GROUP BY data, municipio, estado, bioma HAVING count(*) > 1
                ) AS repetidos
                """
            )
            if duplicados or chaves_duplicadas:
                raise DatasetSchemaError("o dataset contém chaves duplicadas")

            colunas_sql = ", ".join(COLUNAS)
            status = await conn.execute(
                f"""
                INSERT INTO public.firewatch_preprocessado ({colunas_sql})
                SELECT {colunas_sql} FROM firewatch_importacao
                ON CONFLICT DO NOTHING
                """  # noqa: S608 - nomes fixos definidos acima
            )
            inseridos = int(status.rsplit(" ", 1)[-1])
            iguais = await conn.fetchval(
                """
                SELECT count(*)
                FROM firewatch_importacao AS origem
                JOIN public.firewatch_preprocessado AS destino
                  ON destino.linha_origem = origem.linha_origem
                 AND destino.data = origem.data
                 AND destino.municipio = origem.municipio
                 AND destino.estado = origem.estado
                 AND destino.bioma = origem.bioma
                 AND destino.avg_numero_dias_sem_chuva = origem.avg_numero_dias_sem_chuva
                 AND destino.avg_precipitacao = origem.avg_precipitacao
                 AND destino.avg_risco_fogo = origem.avg_risco_fogo
                 AND destino.avg_frp = origem.avg_frp
                 AND destino.bioma_ausente_original = origem.bioma_ausente_original
                """
            )
            if iguais != total:
                raise DatasetSchemaError(
                    f"validação final falhou: {iguais} de {total} registros conferidos"
                )
        return total, inseridos
    finally:
        await conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arquivo", required=True, type=Path)
    parser.add_argument("--tamanho-lote", type=int, default=10_000)
    args = parser.parse_args()
    total, inseridos = asyncio.run(importar(args.arquivo, args.tamanho_lote))
    logger.info("Importação validada: %s registros; %s novos", total, inseridos)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
    main()
