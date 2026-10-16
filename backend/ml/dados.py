"""Leitura do dataset de treino a partir do PostgreSQL.

A fonte oficial de treino e a tabela ``firewatch_dados`` do banco configurado
em ``.env`` (``DB_HOST``/``DB_PORT``/``DB_NAME``/``DB_USER``/``DB_PASSWORD``).

No banco, as colunas climaticas estao padronizadas (z-score) e com prefixo
``avg_``. Este modulo as converte de volta para unidades fisicas usando as
constantes de ``ml.features.DESPADRONIZACAO`` e monta o DataFrame com as
colunas exatamente na ordem de ``ml.features.FEATURES`` mais o alvo
``risco_fogo``.
"""

from __future__ import annotations

import asyncio
import logging
import sys
from pathlib import Path
from typing import Any

import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from ml.alvo import codigo_do_indice  # noqa: E402
from ml.features import DESPADRONIZACAO, FEATURES  # noqa: E402

logger = logging.getLogger(__name__)

#: Tabela de origem no banco.
TABELA_PADRAO = "firewatch_dados"

#: Mapeamento coluna-do-banco -> nome canonico da feature.
_MAPA_COLUNAS: dict[str, str] = {
    "avg_temp_max": "temp_max",
    "avg_temp_min": "temp_min",
    "avg_humidity": "umidade",
    "avg_precipitation": "precipitacao_mm",
    "avg_wind_speed": "velocidade_vento",
    "avg_numero_dias_sem_chuva": "dias_sem_chuva",
}

_COLUNAS_BANCO = (*_MAPA_COLUNAS, "avg_risco_fogo", "data", "municipio", "estado", "bioma")


class FonteDeDadosError(RuntimeError):
    """O banco de dados nao esta acessivel ou a tabela esperada nao existe."""


async def _ler_banco(tabela: str = TABELA_PADRAO) -> list[dict[str, Any]]:
    """Le a tabela de treino e devolve as linhas como dicionarios."""
    try:
        import asyncpg
    except ImportError as exc:  # pragma: no cover - dependencia obrigatoria
        raise FonteDeDadosError("asyncpg nao esta instalado.") from exc

    from app.db import get_db_config

    config = get_db_config()
    colunas_sql = ", ".join(f'"{c}"' for c in _COLUNAS_BANCO)
    try:
        conn = await asyncpg.connect(**config, timeout=15)
    except Exception as exc:  # noqa: BLE001
        raise FonteDeDadosError(
            f"Nao foi possivel conectar ao banco {config['user']}@"
            f"{config['host']}:{config['port']}/{config['database']}: {exc}"
        ) from exc

    try:
        registros = await conn.fetch(
            f'SELECT {colunas_sql} FROM public."{tabela}"'  # noqa: S608 - nome fixo
        )
    except Exception as exc:  # noqa: BLE001
        raise FonteDeDadosError(
            f"Falha ao ler a tabela '{tabela}': {exc}"
        ) from exc
    finally:
        await conn.close()

    if not registros:
        raise FonteDeDadosError(f"A tabela '{tabela}' esta vazia.")

    return [dict(r) for r in registros]


def carregar_dataframe(tabela: str = TABELA_PADRAO) -> pd.DataFrame:
    """Carrega o dataset de treino do banco em um DataFrame pronto para o ML.

    Colunas resultantes: ``temp_max``, ``temp_min``, ``umidade``,
    ``precipitacao_mm``, ``velocidade_vento`` (unidades fisicas),
    ``dias_sem_chuva`` (z-score), o alvo ``classe`` (0=Baixo, 1=Moderado,
    2=Critico) e as colunas auxiliares ``risco_fogo``/``indice_risco``
    (escala 0-100) e ``data``/``municipio``/``estado``/``bioma``.

    A classe e derivada do indice 0-100, que por sua vez e o percentil do
    ``risco_fogo`` observado (ver :mod:`ml.alvo`).
    """
    linhas = asyncio.run(_ler_banco(tabela))
    df = pd.DataFrame(linhas)
    logger.info("Dataset carregado do banco: %s linhas", len(df))

    faltando = [c for c in _COLUNAS_BANCO if c not in df.columns]
    if faltando:
        raise FonteDeDadosError(f"Colunas ausentes na tabela '{tabela}': {faltando}")

    convertidas: dict[str, Any] = {}
    for coluna_banco, nome in _MAPA_COLUNAS.items():
        serie = pd.to_numeric(df[coluna_banco], errors="coerce").astype(float)
        if nome in DESPADRONIZACAO:
            media, desvio = DESPADRONIZACAO[nome]
            convertidas[nome] = serie * desvio + media
        else:
            # dias_sem_chuva: mantido na escala z-score do modelo.
            convertidas[nome] = serie

    risco = pd.to_numeric(df["avg_risco_fogo"], errors="coerce").astype(float)
    convertidas["risco_fogo"] = risco
    # Indice 0-100 = percentil do risco_fogo observado (empates -> posto medio).
    convertidas["indice_risco"] = risco.rank(pct=True, method="average") * 100.0
    convertidas["classe"] = convertidas["indice_risco"].map(codigo_do_indice)

    resultado = pd.DataFrame(convertidas)
    for descritiva in ("data", "municipio", "estado", "bioma"):
        resultado[descritiva] = df[descritiva].astype(str)

    resultado = resultado.dropna(
        subset=[*FEATURES, "risco_fogo", "classe"]
    ).reset_index(drop=True)
    resultado["classe"] = resultado["classe"].astype(int)
    return resultado


if __name__ == "__main__":  # pragma: no cover - utilitario de inspecao
    logging.basicConfig(level=logging.INFO)
    dados = carregar_dataframe()
    print(dados[list(FEATURES)].describe().round(3).to_string())
    print("\nrisco_fogo:", dados["risco_fogo"].describe().round(4).to_dict())
    print("\nindice_risco:", dados["indice_risco"].describe().round(2).to_dict())
    print("\nclasse:")
    print(dados["classe"].value_counts().sort_index().to_string())
