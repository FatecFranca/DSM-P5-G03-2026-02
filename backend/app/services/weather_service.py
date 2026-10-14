"""Integracao com a API Open-Meteo para obtencao de dados climaticos em tempo real.

Fonte: https://api.open-meteo.com/v1/forecast
Documentacao: https://open-meteo.com/en/docs
"""

from __future__ import annotations

import logging
import math
import time
from datetime import datetime, timezone

import httpx

from app.models.schemas import WeatherData

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

CURRENT_FIELDS = (
    "temperature_2m",
    "relative_humidity_2m",
    "apparent_temperature",
    "dew_point_2m",
    "precipitation",
    "cloud_cover",
    "wind_speed_10m",
    "wind_gusts_10m",
)

#: Limites fisicos usados para sanity check antes de devolver ao modelo.
LIMITE_TEMPERATURA_C = (-70.0, 65.0)
LIMITE_UMIDADE = (-1.0, 101.0)
LIMITE_PRECIPITACAO = (-0.5, 400.0)
LIMITE_VENTO_KMH = (-1.0, 250.0)


class WeatherServiceError(RuntimeError):
    """Falha ao obter dados climaticos da Open-Meteo."""


class WeatherService:
    """Cliente da Open-Meteo com cache curto e modo degradado (fallback)."""

    def __init__(
        self,
        timeout: float = 10.0,
        cache_ttl: float = 300.0,
        permitir_fallback: bool = True,
    ) -> None:
        self.timeout = timeout
        self.cache_ttl = cache_ttl
        self.permitir_fallback = permitir_fallback
        self._cache: dict[tuple[float, float], tuple[float, WeatherData]] = {}

    # ------------------------------------------------------------------ cache

    def _cache_get(self, chave: tuple[float, float]) -> WeatherData | None:
        item = self._cache.get(chave)
        if item is None:
            return None
        gerado_em, dados = item
        if (time.monotonic() - gerado_em) > self.cache_ttl:
            self._cache.pop(chave, None)
            return None
        return dados

    def _cache_set(self, chave: tuple[float, float], dados: WeatherData) -> None:
        self._cache[chave] = (time.monotonic(), dados)

    def limpar_cache(self) -> None:
        self._cache.clear()

    # ------------------------------------------------------------- requisicao

    def _params(self, latitude: float, longitude: float) -> dict[str, str]:
        return {
            "latitude": f"{latitude:.5f}",
            "longitude": f"{longitude:.5f}",
            "current": ",".join(CURRENT_FIELDS),
            "daily": "uv_index_max",
            "wind_speed_unit": "kmh",
            "precipitation_unit": "mm",
            "timezone": "auto",
            "forecast_days": "1",
        }

    async def obter_clima(self, latitude: float, longitude: float) -> WeatherData:
        """Retorna os dados climaticos atuais para a coordenada informada.

        Usa o cache quando disponivel; em caso de falha de rede, cai para uma
        estimacao climatologica local para que o app continue funcional.
        """
        chave = (round(latitude, 3), round(longitude, 3))
        em_cache = self._cache_get(chave)
        if em_cache is not None:
            logger.info("Cache hit Open-Meteo para %s", chave)
            return em_cache

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as cliente:
                resposta = await cliente.get(
                    OPEN_METEO_URL, params=self._params(latitude, longitude)
                )
                resposta.raise_for_status()
                payload = resposta.json()
            dados = self._parse(payload)
        except Exception as exc:  # noqa: BLE001 - fallback degradado
            if not self.permitir_fallback:
                raise WeatherServiceError(f"Falha ao consultar Open-Meteo: {exc}") from exc
            logger.warning("Open-Meteo indisponivel (%s). Usando estimativa local.", exc)
            dados = self.estimar_clima(
                latitude, longitude, hora=datetime.now(timezone.utc)
            )

        self._cache_set(chave, dados)
        return dados

    # ------------------------------------------------------------- parse/util

    def _parse(self, payload: dict) -> WeatherData:
        current = payload.get("current") or {}
        if not current:
            raise WeatherServiceError("Resposta da Open-Meteo sem bloco 'current'.")

        diario = payload.get("daily") or {}
        uv_max = None
        serie_uv = diario.get("uv_index_max") or []
        if serie_uv:
            uv_max = _primeiro_numero(serie_uv[0])

        dados = WeatherData(
            temperatura_c=_obrigatorio(current, "temperature_2m"),
            umidade_relativa=_obrigatorio(current, "relative_humidity_2m"),
            precipitacao_mm=_obrigatorio(current, "precipitation"),
            velocidade_vento_kmh=_obrigatorio(current, "wind_speed_10m"),
            rajada_vento_kmh=_numero(current.get("wind_gusts_10m")),
            sensacao_termica_c=_numero(current.get("apparent_temperature")),
            ponto_de_orvalho_c=_numero(current.get("dew_point_2m")),
            indice_uv=uv_max,
            cobertura_nuvens=_numero(current.get("cloud_cover")),
            horario=_parse_hora(current.get("time")),
        )
        self._validar(dados)
        return dados

    def _validar(self, dados: WeatherData) -> None:
        problemas = []
        if not LIMITE_TEMPERATURA_C[0] <= dados.temperatura_c <= LIMITE_TEMPERATURA_C[1]:
            problemas.append(f"temperatura={dados.temperatura_c}")
        if not LIMITE_UMIDADE[0] <= dados.umidade_relativa <= LIMITE_UMIDADE[1]:
            problemas.append(f"umidade={dados.umidade_relativa}")
        if not LIMITE_PRECIPITACAO[0] <= dados.precipitacao_mm <= LIMITE_PRECIPITACAO[1]:
            problemas.append(f"precipitacao={dados.precipitacao_mm}")
        if not LIMITE_VENTO_KMH[0] <= dados.velocidade_vento_kmh <= LIMITE_VENTO_KMH[1]:
            problemas.append(f"vento={dados.velocidade_vento_kmh}")
        if problemas:
            raise WeatherServiceError(
                "Dados climaticos fora dos limites esperados: " + ", ".join(problemas)
            )

    # -------------------------------------------------------------- fallback

    def estimar_clima(
        self,
        latitude: float,
        longitude: float,
        hora: datetime | None = None,
    ) -> WeatherData:
        """Estimativa climatologica simples quando a Open-Meteo nao responde.

        Usa apenas latitude (tendencia termica) e sazonalidade mensal. Serve para
        manter o app operacional em modo offline, nao para uso operacional real.
        """
        hora = hora or datetime.now(timezone.utc)
        mes = hora.month

        # Media anual aproximada: ~27 C no equador caindo para ~0 C nas altas latitudes.
        base = 27.0 * math.cos(math.radians(latitude))
        # Amplitude sazonal maior nas latitudes medias/temperadas.
        amplitude = 6.0 + 8.0 * min(abs(latitude) / 60.0, 1.0)
        fase = math.cos(2.0 * math.pi * (mes - 1) / 12.0)
        hemisferio_sul = latitude < 0
        temperatura = base + amplitude * fase * (-1.0 if hemisferio_sul else 1.0)

        umidade = max(30.0, min(95.0, 92.0 - 2.0 * abs(temperatura - 18.0)))
        vento = max(3.0, 18.0 - 2.2 * abs(latitude) / 10.0)

        return WeatherData(
            temperatura_c=round(temperatura, 1),
            umidade_relativa=round(umidade, 1),
            precipitacao_mm=0.0,
            velocidade_vento_kmh=round(vento, 1),
            rajada_vento_kmh=round(vento * 1.8, 1),
            sensacao_termica_c=round(temperatura - 1.0, 1),
            ponto_de_orvalho_c=round(temperatura - (100.0 - umidade) / 5.0, 1),
            indice_uv=None,
            cobertura_nuvens=None,
            horario=hora,
        )


# --------------------------------------------------------------- utilitarios


def _obrigatorio(bloco: dict, chave: str) -> float:
    valor = _numero(bloco.get(chave))
    if valor is None:
        raise WeatherServiceError(f"Campo obrigatorio ausente na Open-Meteo: {chave}")
    return valor


def _numero(valor: object) -> float | None:
    if valor is None:
        return None
    try:
        return float(valor)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


def _primeiro_numero(valor: object) -> float | None:
    if isinstance(valor, (list, tuple)):
        return _numero(valor[0]) if valor else None
    return _numero(valor)


def _parse_hora(valor: object) -> datetime | None:
    if not isinstance(valor, str):
        return None
    try:
        return datetime.fromisoformat(valor)
    except ValueError:
        return None


weather_service = WeatherService()
