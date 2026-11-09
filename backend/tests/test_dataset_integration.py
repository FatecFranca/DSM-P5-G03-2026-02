"""Integração real com PostgreSQL; habilite com FIREWATCH_TEST_DATABASE=1."""

from __future__ import annotations

import asyncio
import os
from datetime import date

import pytest
from fastapi.testclient import TestClient

from app.db import db
from app.main import app
from app.services.dataset_service import dataset_service

pytestmark = pytest.mark.skipif(
    os.getenv("FIREWATCH_TEST_DATABASE") != "1",
    reason="requer PostgreSQL local migrado e dataset importado",
)


def test_dataset_importado_sem_perda_e_health_disponivel():
    with TestClient(app) as cliente:
        health = cliente.get("/health").json()
        assert health["banco"] == "ok"
        assert health["dataset"] == "ok"
        assert health["dataset_registros"] == 157682

        resposta = cliente.get(
            "/api/v1/dados",
            params={"estado": "SÃO PAULO", "pagina": 1, "por_pagina": 3},
        )
        assert resposta.status_code == 200
        corpo = resposta.json()
        assert len(corpo["dados"]) == 3
        assert corpo["paginacao"]["total_registros"] > 3
        assert all(registro["estado"] == "SÃO PAULO" for registro in corpo["dados"])


def test_datas_estatisticas_e_amostra_preservadas():
    with TestClient(app) as cliente:
        estatisticas = cliente.get("/api/v1/dados/estatisticas").json()
        assert estatisticas["total_registros"] == 157682
        assert estatisticas["data_inicial"] == "2024-01-01"
        assert estatisticas["data_final"] == "2024-09-09"
        assert estatisticas["media_risco_fogo"] == pytest.approx(59.9394745754)

        amostra = cliente.get(
            "/api/v1/dados",
            params={
                "data_inicio": "2024-01-01",
                "data_fim": "2024-01-01",
                "municipio": "VALE DO ANARI",
            },
        ).json()["dados"]
        assert amostra == [
            {
                "linha_origem": 2,
                "data": "2024-01-01",
                "municipio": "VALE DO ANARI",
                "estado": "RONDÔNIA",
                "bioma": "Amazônia",
                "avg_numero_dias_sem_chuva": 0.0,
                "avg_precipitacao": 1698.0,
                "avg_risco_fogo": 0.0,
                "avg_frp": 13.0,
                "bioma_ausente_original": False,
            }
        ]


def test_pool_atende_consultas_simultaneas():
    async def consultar():
        await db.close()
        resultados = await asyncio.gather(
            *(
                dataset_service.estatisticas(
                    data_inicio=date(2024, 1, 1),
                    data_fim=date(2024, 1, 31),
                    estado=None,
                    municipio=None,
                    bioma=None,
                )
                for _ in range(10)
            )
        )
        await db.close()
        return resultados

    resultados = asyncio.run(consultar())
    assert len(resultados) == 10
    assert all(resultado["total_registros"] > 0 for resultado in resultados)
