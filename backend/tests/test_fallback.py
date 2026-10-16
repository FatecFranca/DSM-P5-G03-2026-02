from __future__ import annotations

import sys
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app.main import app  # noqa: E402
from app.services import weather_service as ws_module  # noqa: E402


@pytest.fixture
def cliente() -> TestClient:
    with TestClient(app) as c:
        yield c


def _limpar_cache():
    ws_module.weather_service.limpar_cache()


def test_connect_error_retorna_503_sem_dados_climaticos(monkeypatch, cliente):
    _limpar_cache()

    async def raise_conn(*args, **kwargs):
        raise httpx.ConnectError("conn", request=httpx.Request("GET", "x"))

    monkeypatch.setattr(ws_module.httpx.AsyncClient, "get", raise_conn)
    res = cliente.post("/api/v1/prever-risco", json={"latitude": -10.0, "longitude": -40.0})
    assert res.status_code == 503
    assert "indispon" in res.json()["detail"].lower()
    assert "dados_climaticos" not in res.json()


def test_http_500_com_retry_sucesso(monkeypatch, cliente):
    _limpar_cache()
    calls = {"n": 0}

    class Resp500:
        status_code = 500
        def raise_for_status(self):
            raise httpx.HTTPStatusError("500", request=httpx.Request("GET", "x"), response=httpx.Response(500))

    class RespOk:
        status_code = 200
        def raise_for_status(self):
            pass
        def json(self):
            return {
                "current": {
                    "temperature_2m": 30.0,
                    "relative_humidity_2m": 40.0,
                    "precipitation": 0.0,
                    "wind_speed_10m": 10.0,
                }
            }

    async def get_side(*args, **kwargs):
        calls["n"] += 1
        if calls["n"] == 1:
            return Resp500()
        return RespOk()

    monkeypatch.setattr(ws_module.httpx.AsyncClient, "get", get_side)
    res = cliente.post("/api/v1/prever-risco", json={"latitude": -10.0, "longitude": -40.0})
    assert res.status_code == 200
    assert calls["n"] == 2


def test_http_4xx_nao_retry(monkeypatch, cliente):
    _limpar_cache()
    calls = {"n": 0}

    class Resp400:
        status_code = 400
        def raise_for_status(self):
            raise httpx.HTTPStatusError("400", request=httpx.Request("GET", "x"), response=httpx.Response(400))

    async def get_side(*args, **kwargs):
        calls["n"] += 1
        return Resp400()

    monkeypatch.setattr(ws_module.httpx.AsyncClient, "get", get_side)
    res = cliente.post("/api/v1/prever-risco", json={"latitude": -10.0, "longitude": -40.0})
    assert res.status_code == 503
    assert calls["n"] == 1


def test_http_500_sem_sucesso_apos_retry_retorna_503(monkeypatch, cliente):
    _limpar_cache()
    calls = {"n": 0}

    class Resp500:
        status_code = 500
        def raise_for_status(self):
            raise httpx.HTTPStatusError("500", request=httpx.Request("GET", "x"), response=httpx.Response(500))

    async def get_side(*args, **kwargs):
        calls["n"] += 1
        return Resp500()

    monkeypatch.setattr(ws_module.httpx.AsyncClient, "get", get_side)
    res = cliente.post("/api/v1/prever-risco", json={"latitude": -10.0, "longitude": -40.0})
    assert res.status_code == 503
    assert calls["n"] == 2


def test_cache_funciona_e_vai_pra_rede_apos_ttl(monkeypatch, cliente):
    _limpar_cache()
    calls = {"n": 0}

    class RespOk:
        status_code = 200
        def raise_for_status(self):
            pass
        def json(self):
            return {
                "current": {
                    "temperature_2m": 25.0,
                    "relative_humidity_2m": 50.0,
                    "precipitation": 0.0,
                    "wind_speed_10m": 5.0,
                }
            }

    async def get_side(*args, **kwargs):
        calls["n"] += 1
        return RespOk()

    monkeypatch.setattr(ws_module.httpx.AsyncClient, "get", get_side)
    res1 = cliente.post("/api/v1/prever-risco", json={"latitude": -12.0, "longitude": -44.0})
    assert res1.status_code == 200
    res2 = cliente.post("/api/v1/prever-risco", json={"latitude": -12.0, "longitude": -44.0})
    assert res2.status_code == 200
    assert calls["n"] == 1
    monkeypatch.setattr(ws_module.weather_service, "cache_ttl", 0)
    res3 = cliente.post("/api/v1/prever-risco", json={"latitude": -12.0, "longitude": -44.0})
    assert res3.status_code == 200
    assert calls["n"] == 2


def test_settings_override_por_env(monkeypatch):
    monkeypatch.setenv("OPEN_METEO_TIMEOUT", "5.5")
    monkeypatch.setenv("CACHE_TTL_SEGUNDOS", "120")
    monkeypatch.setenv("PERMITIR_FALLBACK_CLIMA", "true")
    monkeypatch.setenv("CORS_ORIGINS", "http://a.com,http://b.com")
    from app import config

    config.get_settings.cache_clear()
    s = config.Settings()
    assert s.OPEN_METEO_TIMEOUT == 5.5
    assert s.CACHE_TTL_SEGUNDOS == 120
    assert s.PERMITIR_FALLBACK_CLIMA is True
    assert s.CORS_ORIGINS == ["http://a.com", "http://b.com"]
    config.get_settings.cache_clear()


def test_fallback_ativo_nao_coloca_no_cache(monkeypatch, cliente):
    _limpar_cache()
    calls = {"n": 0}

    class Resp500:
        status_code = 500
        def raise_for_status(self):
            raise httpx.HTTPStatusError("500", request=httpx.Request("GET", "x"), response=httpx.Response(500))

    async def get_side(*args, **kwargs):
        calls["n"] += 1
        return Resp500()

    monkeypatch.setattr(ws_module.weather_service, "permitir_fallback", True)
    monkeypatch.setattr(ws_module.httpx.AsyncClient, "get", get_side)
    res = cliente.post("/api/v1/prever-risco", json={"latitude": -15.0, "longitude": -45.0})
    assert res.status_code == 200
    assert calls["n"] == 2
