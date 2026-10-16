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
from app.services.classificacao import (  # noqa: E402
    CLASSES,
    CORES,
    NIVEIS,
    classe_do_codigo,
    codigo_do_indice,
    cor_do_codigo,
    nivel_do_codigo,
)
from app.services.prediction_service import prediction_service  # noqa: E402
from app.services.weather_service import WeatherService, WeatherServiceError  # noqa: E402
from ml.features import FEATURES, construir_features, padronizar_dias_sem_chuva  # noqa: E402

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


class TestFeatures:
    def test_ordem_canonica(self):
        assert FEATURES[0] == "temp_max"
        assert len(FEATURES) == len(set(FEATURES))

    def test_dias_sem_chuva_cresce_com_os_dias(self):
        base = {
            "temp_max": 32.0,
            "temp_min": 22.0,
            "umidade": 30.0,
            "precipitacao_mm": 0.0,
            "velocidade_vento": 20.0,
        }
        seco = construir_features({**base, "dias_sem_chuva": 40.0})
        umido = construir_features({**base, "dias_sem_chuva": 0.0})
        assert seco["dias_sem_chuva"] > umido["dias_sem_chuva"]
        assert umido["dias_sem_chuva"] == round(padronizar_dias_sem_chuva(0.0), 4)

    def test_campos_ausentes_viram_omissao(self):
        features = construir_features({})
        assert set(features) == set(FEATURES)
        assert all(isinstance(v, float) for v in features.values())

    def test_valores_fora_de_faixa_sao_recortados(self):
        features = construir_features(
            {
                "temp_max": 500.0,
                "temp_min": -500.0,
                "umidade": 250.0,
                "precipitacao_mm": -5.0,
                "velocidade_vento": 9999.0,
                "dias_sem_chuva": -10.0,
            }
        )
        assert features["temp_max"] == 60.0
        assert features["temp_min"] == -30.0
        assert features["umidade"] == 100.0
        assert features["precipitacao_mm"] == 0.0
        assert features["velocidade_vento"] == 200.0
        assert features["dias_sem_chuva"] == round(padronizar_dias_sem_chuva(0.0), 4)

    def test_nan_e_tratado(self):
        features = construir_features(
            {
                "temp_max": 25.0,
                "temp_min": 15.0,
                "umidade": 60.0,
                "precipitacao_mm": 0.0,
                "velocidade_vento": 10.0,
                "dias_sem_chuva": float("nan"),
            }
        )
        assert features["dias_sem_chuva"] == features["dias_sem_chuva"]


class TestClassesDeRisco:
    def test_tres_classes(self):
        assert CLASSES == ("Risco Baixo", "Risco Moderado", "Risco Crítico")
        assert NIVEIS == ("BAIXO", "MODERADO", "CRÍTICO")
        assert CORES == ("#22C55E", "#FACC15", "#DC2626")

    @pytest.mark.parametrize(
        ("indice", "codigo"),
        [
            (0.0, 0),
            (29.9, 0),
            (30.0, 1),
            (50.0, 1),
            (69.9, 1),
            (70.0, 2),
            (100.0, 2),
        ],
    )
    def test_codigo_do_indice(self, indice, codigo):
        assert codigo_do_indice(indice) == codigo

    def test_rotulos_por_codigo(self):
        assert nivel_do_codigo(0) == "BAIXO"
        assert nivel_do_codigo(1) == "MODERADO"
        assert nivel_do_codigo(2) == "CRÍTICO"
        assert classe_do_codigo(0) == "Risco Baixo"
        assert classe_do_codigo(1) == "Risco Moderado"
        assert classe_do_codigo(2) == "Risco Crítico"
        for codigo in range(3):
            assert cor_do_codigo(codigo) == CORES[codigo]
            assert cor_do_codigo(codigo) != "#FF0000"


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
        assert corpo["banco"] in {"ok", "desconectado", "erro"}
        assert corpo["classes"] == list(CLASSES)

    def test_docs_disponiveis(self, cliente):
        assert cliente.get("/docs").status_code == 200
        assert cliente.get("/openapi.json").status_code == 200

    def test_schema_do_endpoint_de_risco(self, cliente):
        esquema = cliente.get("/openapi.json").json()
        assert "/api/v1/prever-risco" in esquema["paths"]
        rota = esquema["paths"]["/api/v1/prever-risco"]["post"]
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
        assert cliente.post("/api/v1/prever-risco", json=corpo).status_code == 422

    def test_predicao_completa(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente: rode python ml/treinamento.py")

        resposta = cliente.post(
            "/api/v1/prever-risco",
            json={"latitude": -15.79, "longitude": -47.88},
        )
        assert resposta.status_code == 200, resposta.text
        corpo = resposta.json()

        assert corpo["status"] == "sucesso"
        assert "localizacao" in corpo
        assert corpo["localizacao"]["latitude"] == -15.79
        assert corpo["localizacao"]["longitude"] == -47.88
        assert "dados_climaticos" in corpo
        assert "predicao" in corpo

        pred = corpo["predicao"]
        assert 0.0 <= pred["probabilidade"] <= 1.0
        assert pred["porcentagem"].endswith("%")
        assert pred["nivel_risco"] in set(NIVEIS)
        assert pred["classe"] in set(CLASSES)
        assert pred["cor_alerta"] in set(CORES)
        assert pred["cor_alerta"] != "#FF0000"
        assert pred["recomendacao"]
        assert set(pred["probabilidades"]) == {
            "risco_baixo", "risco_moderado", "risco_critico",
        }

        dc = corpo["dados_climaticos"]
        assert -70.0 <= dc["temperatura"] <= 65.0
        assert 0.0 <= dc["umidade_ar"] <= 100.0
        assert dc["precipitacao_mm"] >= 0.0
        assert dc["vento_kmh"] >= 0.0

    def test_classe_coerente_com_probabilidades(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        corpo = cliente.post(
            "/api/v1/prever-risco", json={"latitude": -23.55, "longitude": -46.63}
        ).json()
        pred = corpo["predicao"]
        probs = pred["probabilidades"]
        lista = [probs["risco_baixo"], probs["risco_moderado"], probs["risco_critico"]]

        mais_provavel = lista.index(max(lista))
        assert pred["classe"] == CLASSES[mais_provavel]
        assert pred["nivel_risco"] == NIVEIS[mais_provavel]
        assert abs(sum(lista) - 1.0) < 0.01
        assert abs(pred["probabilidade"] - probs["risco_critico"]) < 0.001

    def test_percentual_consistente(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        corpo = cliente.post(
            "/api/v1/prever-risco", json={"latitude": -3.12, "longitude": -60.02}
        ).json()
        p = corpo["predicao"]["probabilidade"]
        porcent_str = corpo["predicao"]["porcentagem"]
        assert porcent_str.endswith("%")
        pct_val = float(porcent_str[:-1])
        assert abs(pct_val - round(p * 100.0, 1)) < 0.05

    def test_variacao_entre_regioes(self, cliente, modelo_disponivel):
        if not modelo_disponivel:
            pytest.skip("modelo.pkl ausente")

        resultados = {
            cidade: cliente.post(
                "/api/v1/prever-risco", json={"latitude": lat, "longitude": lon}
            ).json()["predicao"]["probabilidade"]
            for cidade, (lat, lon) in {
                "amazonia": (-3.12, -60.02),
                "sao_paulo": (-23.55, -46.63),
            }.items()
        }
        assert len(set(resultados.values())) > 1

    def test_get_risk_retorna_404(self, cliente):
        resposta = cliente.get("/api/v1/risk?latitude=-15.79&longitude=-47.88")
        assert resposta.status_code == 404
