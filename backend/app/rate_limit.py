"""Limites por IP e rota para proteger as inferências de um processo da API."""

import math
import time
from collections.abc import Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse


class RiskRateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, limits: dict[str, int], clock: Callable = time.monotonic):
        super().__init__(app)
        self.limits = limits
        self.clock = clock
        self.buckets: dict[tuple[str, str], tuple[float, int]] = {}

    async def dispatch(self, request: Request, call_next):
        path = request.url.path.rstrip("/")
        limit = self.limits.get(path)
        if request.method != "POST" or limit is None:
            return await call_next(request)
        now = self.clock()
        key = (request.client.host if request.client else "unknown", path)
        started, count = self.buckets.get(key, (now, 0))
        if now - started >= 60:
            started, count = now, 0
        if count >= limit:
            return self._busy(max(1, math.ceil(60 - (now - started))))
        if key not in self.buckets and len(self.buckets) >= 4096:
            self.buckets = {k: v for k, v in self.buckets.items() if now - v[0] < 60}
            if len(self.buckets) >= 4096:
                return self._busy(60)
        self.buckets[key] = (started, count + 1)
        return await call_next(request)

    @staticmethod
    def _busy(retry_after: int):
        return JSONResponse(
            status_code=429,
            content={"detail": "Limite de consultas atingido. Aguarde e tente novamente."},
            headers={"Retry-After": str(retry_after)},
        )
