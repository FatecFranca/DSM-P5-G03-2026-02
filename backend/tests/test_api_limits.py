"""Proteções da API sem depender de banco, modelo ou serviços externos."""

import asyncio

import pytest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
from pydantic import ValidationError
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.config import Settings
from app.main import app
from app.rate_limit import RiskRateLimitMiddleware


def test_endpoint_publico_de_diagnostico_do_banco_removido():
    client = TestClient(app)
    assert client.get("/api/v1/db-test").status_code == 404
    assert "/api/v1/db-test" not in app.openapi()["paths"]


def test_cors_exige_origens_explicitas():
    assert Settings(_env_file=None).CORS_ORIGINS == []
    assert Settings(_env_file=None, CORS_ORIGINS="https://app.example").CORS_ORIGINS == [
        "https://app.example"
    ]
    with pytest.raises(ValidationError):
        Settings(_env_file=None, CORS_ORIGINS="*")


def test_limite_por_ip_rota_e_janela_preserva_cors_e_preflight():
    clock = [0.0]
    mini = FastAPI()

    @mini.post("/api/v1/prever-risco")
    @mini.post("/api/v1/risco-regional")
    async def risk():
        return {"status": "ok"}

    mini.add_middleware(
        RiskRateLimitMiddleware,
        limits={"/api/v1/prever-risco": 2, "/api/v1/risco-regional": 1},
        clock=lambda: clock[0],
    )
    mini.add_middleware(CORSMiddleware, allow_origins=["https://app.example"],
                        allow_methods=["POST"], allow_headers=["Content-Type"])
    client = TestClient(mini)
    headers = {"Origin": "https://app.example"}
    assert client.post("/api/v1/prever-risco", headers=headers).status_code == 200
    assert client.post("/api/v1/prever-risco", headers=headers).status_code == 200
    response = client.post("/api/v1/prever-risco", headers=headers)
    assert response.status_code == 429
    assert response.headers["Retry-After"] == "60"
    assert response.headers["Access-Control-Allow-Origin"] == "https://app.example"
    assert client.post("/api/v1/risco-regional", headers=headers).status_code == 200
    assert client.post("/api/v1/risco-regional", headers=headers).status_code == 429
    assert client.options("/api/v1/risco-regional", headers={
        **headers, "Access-Control-Request-Method": "POST"
    }).status_code == 200
    other = TestClient(mini, client=("another-client", 12345))
    assert other.post("/api/v1/prever-risco").status_code == 200
    clock[0] = 60
    assert client.post("/api/v1/prever-risco").status_code == 200
    blocked = client.options("/api/v1/prever-risco", headers={
        "Origin": "https://untrusted.example", "Access-Control-Request-Method": "POST"
    })
    assert blocked.status_code == 400
    assert "Access-Control-Allow-Origin" not in blocked.headers


def test_limite_de_memoria_nao_expulsa_cotas_ativas():
    async def run():
        clock = [0.0]
        path = "/api/v1/prever-risco"
        middleware = RiskRateLimitMiddleware(FastAPI(), limits={path: 2}, clock=lambda: clock[0])
        middleware.buckets = {(f"client-{i}", path): (0.0, 1) for i in range(4096)}
        request = Request({
            "type": "http", "method": "POST", "path": path, "headers": [],
            "scheme": "http", "server": ("test", 80), "query_string": b"",
            "client": ("new-client", 12345),
        })

        async def next_response(_request):
            return JSONResponse({"ok": True})

        assert (await middleware.dispatch(request, next_response)).status_code == 429
        assert len(middleware.buckets) == 4096
        clock[0] = 61
        assert (await middleware.dispatch(request, next_response)).status_code == 200
        assert len(middleware.buckets) == 1

    asyncio.run(run())
