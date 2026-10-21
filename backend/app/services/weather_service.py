"""Integracao com a API Open-Meteo para obtencao de dados climaticos em tempo real.

Fonte: https://api.open-meteo.com/v1/forecast
Documentacao: https://open-meteo.com/en/docs
"""

from __future__ import annotations

import logging
import math
import time
from datetime import UTC, datetime, timedelta, timezone

import httpx

from app.config import settings
from app.models.schemas import WeatherData

logger = logging.getLogger(__name__)

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

#: Campos diarios: o ultimo elemento de cada serie corresponde ao dia de hoje.
DAILY_FIELDS = (
    "uv_index_max",
    "temperature_2m_max",
    "temperature_2m_min",
    "precipitation_sum",
    "wind_speed_10m_max",
)

#: Quantos dias passados sao pedidos a Open-Meteo (para contar dias sem chuva).
DIAS_PASSADOS = 60

#: Chuva minima (mm) para considerar que "choveu" no dia.
LIMIAR_CHUVA_MM = 1.0

#: Limites fisicos usados para sanity check antes de devolver ao modelo.
LIMITE_TEMPERATURA_C = (-70.0, 65.0)
LIMITE_UMIDADE = (0.0, 100.0)
LIMITE_PRECIPITACAO = (0.0, 400.0)
LIMITE_VENTO_KMH = (0.0, 250.0)


class WeatherServiceError(RuntimeError):
    """Falha ao obter dados climaticos da Open-Meteo."""

class WeatherService:
    """Cliente da Open-Meteo com cache curto e modo degradado (fallback)."""

    def __init__(
        self,
        timeout: float | None = None,
        cache_ttl: float | None = None,
        permitir_fallback: bool | None = None,
        permitir_ajustes: bool = True,
    ) -> None:
        self.timeout = timeout if timeout is not None else settings.OPEN_METEO_TIMEOUT
        self.cache_ttl = cache_ttl if cache_ttl is not None else settings.CACHE_TTL_SEGUNDOS
        self.permitir_fallback = (
            permitir_fallback if permitir_fallback is not None else settings.PERMITIR_FALLBACK_CLIMA
        )
        self._cache: dict[tuple[float, float], tuple[float, WeatherData]] = {}
        self.permitir_ajustes = permitir_ajustes

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
        # Consultas regionais podem visitar muitas células diferentes.
        while len(self._cache) > 256:
            self._cache.pop(next(iter(self._cache)))

    def limpar_cache(self) -> None:
        self._cache.clear()

    # ------------------------------------------------------------- requisicao

    def _params(self, latitude: float, longitude: float) -> dict[str, str]:
        return {
            "latitude": f"{latitude:.5f}",
            "longitude": f"{longitude:.5f}",
            "current": ",".join(CURRENT_FIELDS),
            "daily": ",".join(DAILY_FIELDS),
            "wind_speed_unit": "kmh",
            "precipitation_unit": "mm",
            "timezone": "auto",
            "forecast_days": "1",
            "past_days": str(DIAS_PASSADOS),
        }

    async def obter_clima(self, latitude: float, longitude: float) -> WeatherData:
        """Retorna os dados climaticos atuais para a coordenada informada."""
        chave = (round(latitude, 3), round(longitude, 3))
        em_cache = self._cache_get(chave)
        if em_cache is not None:
            logger.info("Cache hit Open-Meteo para %s", chave)
            return em_cache

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as cliente:
                resposta = await self._fetch_with_retry(cliente, latitude, longitude)
                payload = resposta.json()
            dados = self._parse(payload)
        except Exception as exc:  # noqa: BLE001
            if not self.permitir_fallback:
                raise WeatherServiceError(f"Falha ao consultar Open-Meteo: {exc}") from exc
            logger.warning("Open-Meteo indisponivel (%s). Usando estimativa local.", exc)
            return self.estimar_clima(latitude, longitude, hora=datetime.now(UTC))

        self._cache_set(chave, dados)
        return dados

    async def _fetch_with_retry(
        self, cliente: httpx.AsyncClient, latitude: float, longitude: float
    ) -> httpx.Response:
        tentativa = 0
        last_exc: Exception | None = None
        while tentativa <= 1:
            try:
                resposta = await cliente.get(
                    settings.OPEN_METEO_URL, params=self._params(latitude, longitude)
                )
                if tentativa == 0 and resposta.status_code >= 500:
                    tentativa += 1
                    await self._sleep(0.5)
                    continue
                resposta.raise_for_status()
                return resposta
            except httpx.RequestError as exc:
                last_exc = exc
                if tentativa == 0:
                    tentativa += 1
                    await self._sleep(0.5)
                    continue
                break
            except httpx.HTTPStatusError:
                # HTTP 4xx nao tem retry
                raise
        if last_exc is not None:
            raise last_exc
        raise WeatherServiceError("Falha ao consultar Open-Meteo")

    async def _sleep(self, seg: float) -> None:
        import asyncio

        await asyncio.sleep(seg)

    # ------------------------------------------------------------- parse/util

    def _parse(self, payload: dict) -> WeatherData:
        current = payload.get("current") or {}
        if not current:
            raise WeatherServiceError("Resposta da Open-Meteo sem bloco 'current'.")

        diario = payload.get("daily") or {}
        uv_max = _ultimo_numero(diario.get("uv_index_max"))
        temp_max = _ultimo_numero(diario.get("temperature_2m_max"))
        temp_min = _ultimo_numero(diario.get("temperature_2m_min"))
        precip_diaria = _ultimo_numero(diario.get("precipitation_sum"))
        vento_max = _ultimo_numero(diario.get("wind_speed_10m_max"))
        dias_sem_chuva = _dias_sem_chuva(diario.get("precipitation_sum"))

        valores = {
            "latitude_fonte": _numero(payload.get("latitude")),
            "longitude_fonte": _numero(payload.get("longitude")),
            "temperatura_c": _obrigatorio(current, "temperature_2m"),
            "umidade_relativa": _obrigatorio(current, "relative_humidity_2m"),
            "precipitacao_mm": _obrigatorio(current, "precipitation"),
            "velocidade_vento_kmh": _obrigatorio(current, "wind_speed_10m"),
            "rajada_vento_kmh": _numero(current.get("wind_gusts_10m")),
            "sensacao_termica_c": _numero(current.get("apparent_temperature")),
            "ponto_de_orvalho_c": _numero(current.get("dew_point_2m")),
            "indice_uv": uv_max,
            "cobertura_nuvens": _numero(current.get("cloud_cover")),
            "temperatura_max_c": temp_max,
            "temperatura_min_c": temp_min,
            "precipitacao_diaria_mm": precip_diaria,
            "vento_max_kmh": vento_max,
            "dias_sem_chuva": dias_sem_chuva,
            "horario": _parse_hora(current.get("time"), payload.get("utc_offset_seconds")),
        }
        self._sanitizar(valores)
        return WeatherData(**valores)

    def _sanitizar(self, valores: dict) -> None:
        faixas = {
            "temperatura_c": LIMITE_TEMPERATURA_C,
            "umidade_relativa": LIMITE_UMIDADE,
            "precipitacao_mm": LIMITE_PRECIPITACAO,
            "velocidade_vento_kmh": LIMITE_VENTO_KMH,
            "rajada_vento_kmh": LIMITE_VENTO_KMH,
            "sensacao_termica_c": LIMITE_TEMPERATURA_C,
            "ponto_de_orvalho_c": LIMITE_TEMPERATURA_C,
            "cobertura_nuvens": LIMITE_UMIDADE,
            "temperatura_max_c": LIMITE_TEMPERATURA_C,
            "temperatura_min_c": LIMITE_TEMPERATURA_C,
            "precipitacao_diaria_mm": LIMITE_PRECIPITACAO,
            "vento_max_kmh": LIMITE_VENTO_KMH,
            "dias_sem_chuva": (0.0, 365.0),
            "indice_uv": (0.0, float("inf")),
        }
        for campo, (inferior, superior) in faixas.items():
            valor = valores[campo]
            if valor is None:
                continue
            ajustado = max(inferior, min(superior, valor))
            if ajustado != valor:
                if not self.permitir_ajustes:
                    raise WeatherServiceError(f"Campo fora da faixa física: {campo}")
                logger.warning("Campo climático recortado à faixa física: %s", campo)
            valores[campo] = ajustado

    def estimar_clima(
        self,
        latitude: float,
        longitude: float,  # noqa: ARG002
        hora: datetime | None = None,
    ) -> WeatherData:
        if hora is None:
            hora = datetime.now(UTC)
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
            temperatura_max_c=round(temperatura + 2.0, 1),
            temperatura_min_c=round(temperatura - 4.0, 1),
            precipitacao_diaria_mm=0.0,
            vento_max_kmh=round(vento * 1.6, 1),
            dias_sem_chuva=0.0,
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
        numero = float(valor)  # type: ignore[arg-type]
        return numero if math.isfinite(numero) else None
    except (TypeError, ValueError):
        return None


def _primeiro_numero(valor: object) -> float | None:
    if isinstance(valor, (list, tuple)):
        return _numero(valor[0]) if valor else None
    return _numero(valor)


def _ultimo_numero(valor: object) -> float | None:
    """Ultimo valor de uma serie diaria (o dia de hoje)."""
    if isinstance(valor, (list, tuple)):
        return _numero(valor[-1]) if valor else None
    return _numero(valor)


def _dias_sem_chuva(serie: object) -> float | None:
    """Conta os dias consecutivos sem chuva terminando no ultimo dia da serie."""
    if not isinstance(serie, (list, tuple)) or not serie:
        return None
    dias = 0
    for valor in reversed(serie):
        numero = _numero(valor)
        if numero is None or numero < 0:
            return None
        if numero >= LIMIAR_CHUVA_MM:
            break
        dias += 1
    return float(dias)


def _parse_hora(valor: object, offset_segundos: object = None) -> datetime | None:
    if not isinstance(valor, str):
        return None
    try:
        hora = datetime.fromisoformat(valor)
        if hora.tzinfo is None:
            if not isinstance(offset_segundos, (int, float)) or not math.isfinite(offset_segundos):
                return None
            hora = hora.replace(tzinfo=timezone(timedelta(seconds=offset_segundos)))
        return hora.astimezone(UTC)
    except ValueError:
        return None


weather_service = WeatherService()
