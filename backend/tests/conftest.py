"""Isolamento dos limites HTTP entre cenários de teste."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import app
from app.rate_limit import RiskRateLimitMiddleware


@pytest.fixture(autouse=True)
def limpar_limites_http():
    middleware = app.middleware_stack
    while middleware is not None:
        if isinstance(middleware, RiskRateLimitMiddleware):
            middleware.buckets.clear()
        middleware = getattr(middleware, "app", None)
