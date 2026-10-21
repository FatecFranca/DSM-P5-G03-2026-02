"""Validação de entradas não finitas no endpoint de risco.

NaN e Infinity não fazem parte do JSON (RFC 8259), mas clientes podem
enviá-los. O contrato do endpoint deve rejeitá-los com 422 e nunca
deixar o handler de erros falhar com 500.
"""

from __future__ import annotations

import sys
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app.main import app  # noqa: E402

ENTRADAS_NAO_FINITAS = [
    ("NaN na latitude", b'{"latitude": NaN, "longitude": -47.4}'),
    ("NaN na longitude", b'{"latitude": -20.5, "longitude": NaN}'),
    ("Infinity na latitude", b'{"latitude": Infinity, "longitude": -47.4}'),
    ("-Infinity na longitude", b'{"latitude": -20.5, "longitude": -Infinity}'),
    ("1e999 na latitude", b'{"latitude": 1e999, "longitude": -47.4}'),
]


@pytest.fixture(scope="module")
def cliente() -> Iterator[TestClient]:
    # Sem levantar a exceção do servidor para observar o status devolvido.
    yield TestClient(app, raise_server_exceptions=False)


@pytest.mark.parametrize(("nome", "corpo"), ENTRADAS_NAO_FINITAS)
@pytest.mark.parametrize("rota", ["prever-risco", "risco-regional"])
def test_entrada_nao_finita_retorna_422(cliente: TestClient, nome: str, corpo: bytes, rota: str):
    resposta = cliente.post(
        f"/api/v1/{rota}",
        content=corpo,
        headers={"Content-Type": "application/json"},
    )
    assert resposta.status_code == 422, (
        f"{nome}: esperado 422, obtido {resposta.status_code}: {resposta.text}"
    )
