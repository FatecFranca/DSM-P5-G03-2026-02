"""Grade regional limitada, recortada no Brasil, com inferência e cache compartilhados."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import math
from collections import OrderedDict
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from functools import lru_cache
from pathlib import Path

from shapely.geometry import Point, box, mapping, shape
from shapely.ops import unary_union

from app.models.regional import CellProperties, RegionalFeature, RegionalResponse
from app.models.schemas import LocalizacaoResponse, RiskResponse
from app.services.prediction_service import prediction_service
from app.services.weather_service import WeatherService, WeatherServiceError

logger = logging.getLogger(__name__)
STEP = 0.1
TTL = timedelta(minutes=5)
MAX_CACHE = 256
MAX_PENDING = 32


class OutsideCoverageError(ValueError):
    """A coordenada não pertence à cobertura territorial."""


class RegionalBusyError(RuntimeError):
    """A fila limitada do processo está ocupada."""


@lru_cache(maxsize=1)
def brazil_boundary():
    payload = json.loads((Path(__file__).parents[1] / "data" / "brasil.geojson").read_text())
    return unary_union([shape(feature["geometry"]) for feature in payload["features"]])


def regional_grid(latitude: float, longitude: float):
    boundary = brazil_boundary()
    if not boundary.covers(Point(longitude, latitude)):
        raise OutsideCoverageError("As zonas de risco estão disponíveis apenas no Brasil.")
    row, column = math.floor(latitude / STEP), math.floor(longitude / STEP)
    cells = []
    for y in range(row - 1, row + 2):
        for x in range(column - 1, column + 2):
            west, south = round(x * STEP, 6), round(y * STEP, 6)
            geometry = box(west, south, round(west + STEP, 6), round(south + STEP, 6))
            geometry = geometry.intersection(boundary)
            if geometry.is_empty or geometry.area == 0:
                continue
            if geometry.geom_type == "GeometryCollection":
                geometry = unary_union(
                    [
                        part
                        for part in geometry.geoms
                        if part.geom_type in {"Polygon", "MultiPolygon"}
                    ]
                )
            if geometry.is_empty:
                continue
            center = Point(round(west + STEP / 2, 6), round(south + STEP / 2, 6))
            if not geometry.covers(center):
                center = geometry.representative_point()
            cells.append((f"{y}:{x}", geometry, center.y, center.x))
    bbox = [
        round((column - 1) * STEP, 6),
        round((row - 1) * STEP, 6),
        round((column + 2) * STEP, 6),
        round((row + 2) * STEP, 6),
    ]
    return cells, bbox


@dataclass(frozen=True)
class Sample:
    result: RiskResponse
    weather_time: datetime | None = None
    weather_cell: LocalizacaoResponse | None = None


class RegionalService:
    def __init__(
        self,
        infer: Callable[[float, float], Awaitable[Sample]] | None = None,
        model_version: Callable[[], str] | None = None,
        now: Callable[[], datetime] | None = None,
    ):
        self._weather = WeatherService(permitir_fallback=False, permitir_ajustes=False)
        self._infer = infer or self._infer_local
        self._model_version = model_version or self._local_model_version
        self._version: str | None = None
        self._now = now or (lambda: datetime.now(UTC))
        self._slots = asyncio.Semaphore(2)
        self._cache: OrderedDict[tuple[str, str], CellProperties] = OrderedDict()
        self._pending: dict[tuple[str, str], asyncio.Task] = {}

    def _local_model_version(self) -> str:
        prediction_service.carregar()
        if self._version is None:
            self._version = hashlib.sha256(prediction_service.caminho.read_bytes()).hexdigest()
        return self._version

    async def _infer_local(self, latitude: float, longitude: float) -> Sample:
        weather = await self._weather.obter_clima(latitude, longitude)
        required = (
            weather.temperatura_max_c,
            weather.temperatura_min_c,
            weather.precipitacao_diaria_mm,
            weather.vento_max_kmh,
            weather.dias_sem_chuva,
        )
        if any(value is None or not math.isfinite(value) for value in required):
            raise WeatherServiceError("Amostra sem todos os atributos meteorológicos necessários.")
        result = await asyncio.to_thread(prediction_service.prever, weather, latitude, longitude)
        weather_cell = None
        if weather.latitude_fonte is not None and weather.longitude_fonte is not None:
            weather_cell = LocalizacaoResponse(
                latitude=weather.latitude_fonte,
                longitude=weather.longitude_fonte,
            )
        return Sample(RiskResponse(**result), weather.horario, weather_cell)

    async def _calculate(self, key: tuple[str, str], latitude: float, longitude: float):
        try:
            async with self._slots:
                async with asyncio.timeout(12):
                    sample = await self._infer(latitude, longitude)
                location = sample.result.localizacao
                if (
                    abs(location.latitude - latitude) > 0.0001
                    or abs(location.longitude - longitude) > 0.0001
                ):
                    raise ValueError("A inferência não corresponde à amostra.")
                now = self._now()
                properties = CellProperties(
                    amostra=location,
                    estado="ok",
                    resultado=sample.result,
                    consultado_em=now,
                    expira_em=now + TTL,
                    horario_meteorologico=sample.weather_time,
                    celula_meteorologica=sample.weather_cell,
                )
                self._cache[key] = properties
                self._cache.move_to_end(key)
                while len(self._cache) > MAX_CACHE:
                    self._cache.popitem(last=False)
                return properties
        except Exception:
            logger.exception("Falha na amostra regional %s", key[0])
            return CellProperties(
                amostra=LocalizacaoResponse(latitude=latitude, longitude=longitude),
                estado="sem_dados",
            )
        finally:
            self._pending.pop(key, None)

    async def analyze(self, latitude: float, longitude: float) -> RegionalResponse:
        cells, bbox = regional_grid(latitude, longitude)
        version = await asyncio.to_thread(self._model_version)
        now = self._now()
        for key in list(self._cache):
            if self._cache[key].expira_em <= now or key[1] != version:
                del self._cache[key]
        missing = [
            cell
            for cell in cells
            if (cell[0], version) not in self._cache and (cell[0], version) not in self._pending
        ]
        # O limite é por processo; múltiplos workers exigem coordenação externa.
        if len(self._pending) + len(missing) > MAX_PENDING:
            raise RegionalBusyError("Muitas regiões em análise. Aguarde e tente novamente.")
        for cell_id, _, lat, lon in missing:
            key = (cell_id, version)
            self._pending[key] = asyncio.create_task(self._calculate(key, lat, lon))
        work = {
            cell[0]: self._cache.get((cell[0], version)) or self._pending[(cell[0], version)]
            for cell in cells
        }

        async def feature(cell):
            cell_id, geometry, _, _ = cell
            properties = work[cell_id]
            if isinstance(properties, asyncio.Task):
                # A desconexão de um cliente não cancela uma amostra compartilhada.
                properties = await asyncio.shield(properties)
            return RegionalFeature(id=cell_id, geometry=mapping(geometry), properties=properties)

        features = await asyncio.gather(*(feature(cell) for cell in cells))
        valid = sum(feature.properties.estado == "ok" for feature in features)
        state = "sem_dados" if valid == 0 else "completo" if valid == len(features) else "parcial"
        return RegionalResponse(
            estado=state,
            centro=LocalizacaoResponse(latitude=latitude, longitude=longitude),
            bbox=bbox,
            resolucao_graus=STEP,
            versao_modelo=version,
            gerado_em=self._now(),
            features=features,
        )


regional_service = RegionalService()
