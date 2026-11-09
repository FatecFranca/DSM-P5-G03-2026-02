"""Configuração enxuta do pool PostgreSQL."""

from app.db import get_pool_config


def test_pool_e_timeouts_sao_configuraveis(monkeypatch):
    monkeypatch.setenv("DB_POOL_MIN", "2")
    monkeypatch.setenv("DB_POOL_MAX", "4")
    monkeypatch.setenv("DB_CONNECT_TIMEOUT", "7")
    monkeypatch.setenv("DB_COMMAND_TIMEOUT", "15")

    config = get_pool_config()

    assert config["pool_min"] == 2
    assert config["pool_max"] == 4
    assert config["connect_timeout"] == 7.0
    assert config["command_timeout"] == 15.0
