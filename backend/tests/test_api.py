"""Testes do fluxo completo da API FireWatch.

Executar: python -m pytest -q (na pasta backend/)
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app.main import app  # noqa: E402
from app.models.schemas import RiskLevel  # noqa: E402
from app.services.prediction_service import prediction_service  # noqa: E402
from app.services.weather_service import WeatherService, WeatherServiceError  # noqa: E402
from ml.features import FEATURES, construir_features  # noqa: E402

pytestmark = pytest.mark.filterwarnings("ignore::UserWarning")


@pytest.fixture(scope="module")
def cliente() -> TestClient:
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="module")
def modelo_disponivel() -> bool:
    try:
        prediction_service.carregar()
        return True
    except Exception:  # noqa: BLE001
        return False


# --------------------------------------------------------------- features


class TestFeatures:
    def test_ordem_canonica(self):
        assert FEATURES[0] == "temperature_2m"
        assert len(FEATURES) == len(set(FEATURES))

    def test_vpd_cresce_com_umidade(self):
        base = {
            "temperature_2m": 32.0,
            "relative_humidity_2m": 20.0,
            "precipitation": 0.0,
            "wind_speed_10m": 10.0,
        }
        seco = construir_features(base)
        umido = construir_features({**base, "relative_humidity_2m": 80.0})
        assert seco["vpd_kpa"] > umido["vpd_kpa"]
        assert umido["vpd_kpa"] >= 0.0

    def test_indice_aridez_cai_com_chuva(self):
        base = {
            "temperature_2m": 33.0,
            "relative_humidity_2m": 30.0,
            "wind_speed_10m": 30.0,
        }
        sem_chuva = construir_features({**base, "precipitation": 0.0})
        com_chuva = construir_features({**base, "precipitation": 15.0})
        assert com_chuva["aridity_index"] < sem_chuva["aridity_index"]

    def test_campos_opcionais_ausentes_viram_mediana(self):
        # A Open-Meteo nem sempre devolve UV/nuvem/sensacao termica.
        features = construir_features(
            {
                "temperature_2m": 28.0,
                "relative_humidity_2m": 55.0,
                "precipitation": 0.0,
                "wind_speed_10m": 12.0,
            }
        )
        assert features["uv_index_max"] > 0
        assert features["cloud_cover"] > 0
        assert all(isinstance(v, float) for v in features.values())

    def test_valores_fora_de_faixa_sao_recortados(self):
        features = construir_features(
            {
                "temperature_2m": 500.0,
                "relative_humidity_2m": 250.0,
                "precipitation": -5.0,
                "wind_speed_10m": 9999.0,
            }
        )
        assert features["temperature_2m"] == 60.0
        assert features["relative_humidity_2m"] == 100.0
        assert features["precipitation"] == 0.0
        assert features["wind_speed_10m"] == 200.0

    def test_nan_e_tratado(self):
        features = construir_features(
            {
                "temperature_2m": 25.0,
                "relative_humidity_2m": 60.0,
                "precipitation": 0.0,
                "wind_speed_10m": 10.0,
                "uv_index_max": float("nan"),
            }
        )
        assert features["uv_index_max"] == features["uv_index_max"]  # nao e NaN


# ------------------------------------------------------------- niveis de risco


class TestNiveisDeRisco:
    @pytest.mark.parametrize(
        ("probabilidade", "esperado"),
        [
            (0.00, RiskLevel.BAIXO),
            (0.24, RiskLevel.BAIXO),
            (0.25, RiskLevel.MODERADO),
            (0.49, RiskLevel.MODERADO),
            (0.50, RiskLevel.ALTO),
            (0.74, RiskLevel.ALTO),
            (0.75, RiskLevel.CRITICO),
            (1.00, RiskLevel.CRITICO),
        ],
    )
    def test_faixas(self, probabilidade, esperado):
        assert RiskLevel.from_probability(probabilidade) is esperado

    def test_rotulo_amigavel(self):
        assert RiskLevel.CRITICO.label == "Critico"


# -------------------------------------------------------- servico de clima


class TestWeatherService:
    def test_estimativa_offline_respeita_faixas(self):
        servico = WeatherService(permitir_fallback=True)
        for latitude in (-33.0, -15.0, 0.0, 25.0, 60.0):
            dados = servico.estimar_clima(latitude, 0.0)
            assert -70.0 <= dados.temperatura_c <= 65.0
            assert 0.0 <= dados.umidade_relativa <= 100.0
            assert dados.precipitacao_mm >= 0.0
            assert dados.velocidade_vento_kmh >= 0.0

    def test_ausencia_de_current_levanta_erro(self):
        servico = WeatherService(permitir_fallback=False)
        with pytest.raises(WeatherServiceError):
            servico._parse({"current": {}})

    def test_cache_evita_segunda_chamada(self):
        servico = WeatherService(cache_ttl=300.0)

        class Fixo:
            temperatura_c = 30.0
            umidade_relativa = 40.0
            precipitacao_mm = 0.0
            velocidade_vento_kmh = 15.0
            rajada_vento_kmh = None
            sensacao_termica_c = None
            ponto_de_orvalho_c = None
            indice_uv = None
            cobertura_nuvens = None
            horario = None

        servico._cache_set((1.0, 2.0), Fixo())
        assert servico._cache_get((1.0, 2.0)) is not None
        assert servico._cache_get((9.0, 9.0)) is None
        servico.limpar_cache()
        assert servico._cache_get((1.0, 2.0)) is None


# ------------------------------------------------------------------- API


class TestApi:
    def test_raiz(self, cliente):
        resposta = cliente.get("/")
        assert resposta.status_code == 200
        assert resposta.json()["projeto"] == "FireWatch"

    def test_health(self, cliente):
        resposta = cliente.get("/health")
        assert resposta.status_code == 200
        corpo = resposta.json()
        assert corpo["status"] in {"ok", "degradado"}
        assert corpo["versao"]

    def test_docs_disponiveis(self, cliente):
        assert cliente.get("/docs").status_code == 200
        assert cliente.get("/openapi.json").status_code == 200

    def test_schema_do_endpoint_de_risco(self, cliente):
        esquema = cliente.get("/openapi.json").json()
        rota = esquema["paths"]["/api/v1/risk"]["post"]
        assert "application/json" in rota["requestBody"]["content"]

    @pytest.mark.parametrize(
        "corpo",
        [
            {"latitude": 999.0, "longitude": -46.6},
            {"latitude": -23.5, "longitude": 999.0},
            {"latitude": "abc", "longitude": -46.6},
            {"longitude": -46.6},
            {},
        ],
    )
    def test_coordenadas_invalidas_retornam_422(self, cliente, corpo):
        assert cliente.post("/api/v1/risk", json=corpo).status_code == 422

    def test_predicao_completa(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente: rode python ml/treinamento.py")

        resposta = cliente.post(
            "/api/v1/risk",
            json={"latitude": -15.79, "longitude": -47.88, "nome_local": "Brasilia"},
        )
        assert resposta.status_code == 200, resposta.text
        corpo = resposta.json()

        assert 0.0 <= corpo["probabilidade"] <= 1.0
        assert 0.0 <= corpo["probabilidade_percentual"] <= 100.0
        assert corpo["nivel_risco"] in {"baixo", "moderado", "alto", "critico"}
        assert corpo["descricao"]
        assert corpo["recomendacao"]
        assert corpo["local"] == "Brasilia"

        clima = corpo["clima"]
        assert -70.0 <= clima["temperatura_c"] <= 65.0
        assert 0.0 <= clima["umidade_relativa"] <= 100.0
        assert clima["precipitacao_mm"] >= 0.0
        assert clima["velocidade_vento_kmh"] >= 0.0

        assert corpo["modelo"]["algoritmo"] == "RandomForestClassifier"
        assert corpo["modelo"]["metricas"]["roc_auc"] > 0.8

    def test_nivel_coerente_com_probabilidade(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        resposta = cliente.post(
            "/api/v1/risk", json={"latitude": -23.55, "longitude": -46.63}
        )
        corpo = resposta.json()
        esperado = RiskLevel.from_probability(corpo["probabilidade"]).value
        assert corpo["nivel_risco"] == esperado

    def test_percentual_consistente(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        corpo = cliente.post(
            "/api/v1/risk", json={"latitude": -3.12, "longitude": -60.02}
        ).json()
        assert corpo["probabilidade_percentual"] == pytest.approx(
            round(corpo["probabilidade"] * 100.0, 1), abs=0.05
        )

    def test_variacao_entre_regioes(self, cliente, modelo_disponivel):
        """Cidades com climas distintos nao devem receber risco identico."""
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        resultados = {
            cidade: cliente.post(
                "/api/v1/risk", json={"latitude": lat, "longitude": lon}
            ).json()["probabilidade"]
            for cidade, (lat, lon) in {
                "amazonia": (-3.12, -60.02),
                "sao_paulo": (-23.55, -46.63),
            }.items()
        }
        assert len(set(resultados.values())) > 1

    def test_metodo_get_aceita_query(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        resposta = cliente.get("/api/v1/risk?latitude=-15.79&longitude=-47.88")
        assert resposta.status_code == 200
        assert resposta.json()["latitude"] == -15.79

    def test_nome_local_opcional(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        corpo = cliente.post(
            "/api/v1/risk", json={"latitude": -15.79, "longitude": -47.88}
        ).json()
        assert corpo["local"] is None