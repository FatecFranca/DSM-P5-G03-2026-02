"""Contratos do dataset preprocessado e de sua API de consulta."""

from datetime import date

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.dataset_service import dataset_service
from scripts.importar_dataset import DatasetSchemaError, iterar_lotes

CABECALHO = (
    "linha_origem,data,municipio,estado,bioma,avg_numero_dias_sem_chuva,"
    "avg_precipitacao,avg_risco_fogo,avg_frp,bioma_ausente_original\n"
)


def test_importador_le_csv_em_lotes_sem_carregar_o_arquivo_inteiro(tmp_path):
    arquivo = tmp_path / "firewatch_preprocessado.csv"
    arquivo.write_text(
        CABECALHO
        + "2,2024-01-01,VALE DO ANARI,RONDÔNIA,Amazônia,0.0,1698.0,0.0,13.0,False\n"
        + "3,2024-01-02,FRANCA,SÃO PAULO,Cerrado,4.5,0.0,72.0,8.5,True\n",
        encoding="utf-8",
    )

    lotes = list(iterar_lotes(arquivo, tamanho_lote=1))

    assert len(lotes) == 2
    assert lotes[0][0] == (
        2,
        date(2024, 1, 1),
        "VALE DO ANARI",
        "RONDÔNIA",
        "Amazônia",
        0.0,
        1698.0,
        0.0,
        13.0,
        False,
    )
    assert lotes[1][0][-1] is True


def test_importador_rejeita_schema_diferente(tmp_path):
    arquivo = tmp_path / "invalido.csv"
    arquivo.write_text("data,municipio\n2024-01-01,Franca\n", encoding="utf-8")

    with pytest.raises(DatasetSchemaError, match="colunas"):
        list(iterar_lotes(arquivo))


def test_api_lista_dados_com_filtros_e_paginacao(monkeypatch):
    async def listar(**filtros):
        assert filtros == {
            "pagina": 2,
            "por_pagina": 1,
            "data_inicio": date(2024, 1, 1),
            "data_fim": date(2024, 1, 31),
            "estado": "SÃO PAULO",
            "municipio": None,
            "bioma": None,
        }
        return [
            {
                "linha_origem": 3,
                "data": date(2024, 1, 2),
                "municipio": "FRANCA",
                "estado": "SÃO PAULO",
                "bioma": "Cerrado",
                "avg_numero_dias_sem_chuva": 4.5,
                "avg_precipitacao": 0.0,
                "avg_risco_fogo": 72.0,
                "avg_frp": 8.5,
                "bioma_ausente_original": False,
            }
        ], 2

    monkeypatch.setattr(dataset_service, "listar", listar)
    cliente = TestClient(app)
    resposta = cliente.get(
        "/api/v1/dados",
        params={
            "pagina": 2,
            "por_pagina": 1,
            "data_inicio": "2024-01-01",
            "data_fim": "2024-01-31",
            "estado": "SÃO PAULO",
        },
    )

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["paginacao"] == {
        "pagina": 2,
        "por_pagina": 1,
        "total_registros": 2,
        "total_paginas": 2,
    }
    assert corpo["dados"][0]["avg_risco_fogo"] == 72.0


def test_api_rejeita_periodo_invertido():
    resposta = TestClient(app).get(
        "/api/v1/dados",
        params={"data_inicio": "2024-02-01", "data_fim": "2024-01-01"},
    )

    assert resposta.status_code == 422
    assert resposta.json()["detail"] == "data_inicio deve ser anterior a data_fim."


def test_api_rejeita_pagina_excessiva():
    resposta = TestClient(app).get("/api/v1/dados", params={"pagina": 10_001})

    assert resposta.status_code == 422


def test_api_estatisticas_sem_inventar_classificacao(monkeypatch):
    async def estatisticas(**_filtros):
        return {
            "total_registros": 157682,
            "data_inicial": date(2024, 1, 1),
            "data_final": date(2024, 9, 9),
            "media_dias_sem_chuva": 25.17,
            "media_precipitacao": 109.51,
            "media_risco_fogo": 59.94,
            "media_frp": 124.84,
        }

    monkeypatch.setattr(dataset_service, "estatisticas", estatisticas)
    resposta = TestClient(app).get("/api/v1/dados/estatisticas")

    assert resposta.status_code == 200
    corpo = resposta.json()
    assert corpo["total_registros"] == 157682
    assert "classes" not in corpo
