"""Comportamento regional com inferências controladas; nenhum acesso externo."""

import asyncio
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from shapely.geometry import Point, shape

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import app
from app.models.schemas import RiskResponse
from app.routes import risk
from app.services.prediction_service import ModelNotAvailableError
from app.services.regional_service import (
    MAX_PENDING,
    OutsideCoverageError,
    RegionalBusyError,
    RegionalService,
    Sample,
    brazil_boundary,
    regional_grid,
)
from app.services.weather_service import (
    WeatherService,
    WeatherServiceError,
    _dias_sem_chuva,
    _numero,
)


@pytest.mark.parametrize("value", [float("nan"), float("inf"), float("-inf"), "1e999"])
def test_numero_nao_finito_nao_vira_dado_climatico(value):
    assert _numero(value) is None
    with pytest.raises(WeatherServiceError):
        WeatherService()._parse({"current": {"temperature_2m": value}})


@pytest.mark.parametrize("serie", [[None, 0], [0, None], [-1, 0], [float("nan"), 0]])
def test_historico_incompleto_nao_vira_sequencia_seca(serie):
    assert _dias_sem_chuva(serie) is None


def test_lacuna_anterior_a_chuva_nao_invalida_sequencia_conhecida():
    assert _dias_sem_chuva([None, 2, 0, 0]) == 2


def test_proveniencia_meteorologica_converte_horario_local_para_utc():
    weather = WeatherService()._parse(
        {
            "latitude": -20.5,
            "longitude": -47.4,
            "utc_offset_seconds": -10800,
            "current": {
                "temperature_2m": 30,
                "relative_humidity_2m": 40,
                "precipitation": 0,
                "wind_speed_10m": 10,
                "time": "2026-10-21T13:00",
            },
        }
    )
    assert weather.latitude_fonte == -20.5
    assert weather.longitude_fonte == -47.4
    assert weather.horario == datetime(2026, 10, 21, 16, tzinfo=UTC)


def test_cache_meteorologico_nao_cresce_sem_limite():
    service = WeatherService()
    for index in range(270):
        service._cache_set((index, 0), None)
    assert len(service._cache) == 256
    assert (0, 0) not in service._cache


def test_clima_incompleto_nao_usa_defaults_do_modelo(monkeypatch):
    async def run():
        service = RegionalService(model_version=lambda: "v1")

        async def weather(lat, lon):
            return service._weather._parse(
                {
                    "current": {
                        "temperature_2m": 30,
                        "relative_humidity_2m": 40,
                        "precipitation": 0,
                        "wind_speed_10m": 10,
                    },
                }
            )

        monkeypatch.setattr(service._weather, "obter_clima", weather)
        with pytest.raises(WeatherServiceError):
            await service._infer_local(-20.5, -47.4)

    asyncio.run(run())


def sample(latitude, longitude):
    return Sample(
        RiskResponse(
            **{
                "localizacao": {"latitude": latitude, "longitude": longitude},
                "dados_climaticos": {
                    "temperatura": 30,
                    "umidade_ar": 40,
                    "precipitacao_mm": 0,
                    "vento_kmh": 10,
                },
                "predicao": {
                    "probabilidade": 0.1,
                    "porcentagem": "10%",
                    "nivel_risco": "MODERADO",
                    "classe": "Risco Moderado",
                    "cor_alerta": "#FACC15",
                    "recomendacao": "Atenção.",
                    "probabilidades": {
                        "risco_baixo": 0.3,
                        "risco_moderado": 0.6,
                        "risco_critico": 0.1,
                    },
                },
            }
        )
    )


def test_grade_estavel_limitada_e_recortada_na_fronteira():
    a, bbox = regional_grid(-20.5386, -47.4008)
    b, _ = regional_grid(-20.5390, -47.4010)
    assert len(a) == 9
    assert [cell[0] for cell in a] == [cell[0] for cell in b]
    assert bbox[2] - bbox[0] == pytest.approx(0.3)
    border, _ = regional_grid(-25.5163, -54.5854)
    assert 0 < len(border) <= 9
    for _, geometry, lat, lon in border:
        # Overlay de fronteiras pode deixar resíduos numéricos de área desprezível.
        assert geometry.difference(brazil_boundary()).area < 1e-12
        assert geometry.covers(Point(lon, lat))
    assert any(geometry.area < 0.009 for _, geometry, _, _ in border)


@pytest.mark.parametrize(("lat", "lon"), [(-17.78, -63.18), (-20, -38), (40, -74)])
def test_pais_e_oceano_rejeitados_mesmo_dentro_da_caixa(lat, lon):
    with pytest.raises(OutsideCoverageError):
        regional_grid(lat, lon)


def test_cache_deduplica_limita_concorrencia_e_preserva_a_classe():
    async def run():
        calls = active = peak = 0

        async def infer(lat, lon):
            nonlocal calls, active, peak
            calls += 1
            active += 1
            peak = max(peak, active)
            await asyncio.sleep(0.005)
            active -= 1
            return sample(lat, lon)

        service = RegionalService(infer, lambda: "modelo-v1")
        first, second = await asyncio.gather(
            service.analyze(-20.5386, -47.4008), service.analyze(-20.5386, -47.4008)
        )
        cached = await service.analyze(-20.5386, -47.4008)
        assert calls == 9
        assert peak == 2
        assert first.features == second.features
        assert cached.estado == "completo"
        for feature in first.features:
            assert feature.properties.resultado.predicao.nivel_risco == "MODERADO"
            assert feature.properties.resultado.predicao.probabilidade == 0.1
            assert shape(feature.geometry).covers(
                Point(feature.properties.amostra.longitude, feature.properties.amostra.latitude)
            )

    asyncio.run(run())


def test_expiracao_e_versao_do_modelo_invalidam_cache():
    async def run():
        clock = [datetime(2026, 10, 21, tzinfo=UTC)]
        version = ["v1"]
        calls = 0

        async def infer(lat, lon):
            nonlocal calls
            calls += 1
            return sample(lat, lon)

        service = RegionalService(infer, lambda: version[0], lambda: clock[0])
        await service.analyze(-20.5386, -47.4008)
        clock[0] += timedelta(minutes=5)
        await service.analyze(-20.5386, -47.4008)
        assert calls == 18
        version[0] = "v2"
        assert (await service.analyze(-20.5386, -47.4008)).versao_modelo == "v2"
        assert calls == 27

    asyncio.run(run())


def test_falha_parcial_nao_vira_baixo_e_tenta_novamente_so_a_falha():
    async def run():
        calls = 0

        async def infer(lat, lon):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise TimeoutError("fonte sem resposta")
            return sample(lat, lon)

        service = RegionalService(infer, lambda: "v1")
        region = await service.analyze(-20.5386, -47.4008)
        assert region.estado == "parcial"
        missing = [f for f in region.features if f.properties.estado == "sem_dados"]
        assert len(missing) == 1
        assert missing[0].properties.resultado is None
        assert missing[0].properties.expira_em is None
        assert (await service.analyze(-20.5386, -47.4008)).estado == "completo"
        assert calls == 10

    asyncio.run(run())


def test_falha_total_e_resposta_de_outro_local_nao_sao_pintadas():
    async def run():
        async def infer(lat, lon):
            return sample(0, 0)

        region = await RegionalService(infer, lambda: "v1").analyze(-20.5386, -47.4008)
        assert region.estado == "sem_dados"
        assert all(f.properties.resultado is None for f in region.features)

    asyncio.run(run())


def test_fila_e_cache_tem_limites(monkeypatch):
    async def run():
        async def infer(lat, lon):
            return sample(lat, lon)

        service = RegionalService(infer, lambda: "v1")
        monkeypatch.setattr("app.services.regional_service.MAX_CACHE", 2)
        await service.analyze(-20.5386, -47.4008)
        assert len(service._cache) == 2
        service._pending = {(str(i), "v1"): None for i in range(MAX_PENDING)}
        with pytest.raises(RegionalBusyError):
            await service.analyze(-23.55, -46.63)

    asyncio.run(run())


def test_contrato_http_e_modelo_indisponivel(monkeypatch):
    client = TestClient(app)
    assert (
        client.post(
            "/api/v1/risco-regional", json={"latitude": -17.78, "longitude": -63.18}
        ).status_code
        == 422
    )
    assert (
        client.post("/api/v1/risco-regional", json={"latitude": 91, "longitude": 0}).status_code
        == 422
    )
    assert (
        client.post(
            "/api/v1/risco-regional",
            json={"latitude": -20.5, "longitude": -47.4, "resolucao": 0.00001},
        ).status_code
        == 422
    )

    def missing():
        raise ModelNotAvailableError("arquivo ausente")

    monkeypatch.setattr(risk, "regional_service", RegionalService(model_version=missing))
    response = client.post("/api/v1/risco-regional", json={"latitude": -20.5, "longitude": -47.4})
    assert response.status_code == 503
    assert response.json()["detail"] == "Modelo de previsão indisponível."
