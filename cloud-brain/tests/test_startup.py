"""Tests for application startup safety guards."""

import pytest


def test_cors_origins_raises_in_production_without_env_var(monkeypatch):
    """_resolve_cors_origins raises RuntimeError in production when ALLOWED_ORIGINS is unset."""
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)

    from app.main import _resolve_cors_origins

    with pytest.raises(RuntimeError, match="ALLOWED_ORIGINS"):
        _resolve_cors_origins()


def test_cors_origins_returns_wildcard_in_development(monkeypatch):
    """_resolve_cors_origins returns ['*'] in development when ALLOWED_ORIGINS is unset."""
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)

    from app.main import _resolve_cors_origins

    result = _resolve_cors_origins()
    assert result == ["*"]


def test_cors_origins_parses_comma_separated_list(monkeypatch):
    """_resolve_cors_origins correctly splits a comma-separated ALLOWED_ORIGINS value."""
    monkeypatch.setenv("ALLOWED_ORIGINS", "https://app.zuralog.com, https://zuralog.com")

    from app.main import _resolve_cors_origins

    result = _resolve_cors_origins()
    assert result == ["https://app.zuralog.com", "https://zuralog.com"]


def test_cors_origins_rejects_comma_only_in_production(monkeypatch):
    """_resolve_cors_origins raises RuntimeError when ALLOWED_ORIGINS is only commas."""
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("ALLOWED_ORIGINS", ",,")

    from app.main import _resolve_cors_origins

    with pytest.raises(RuntimeError, match="no valid origins"):
        _resolve_cors_origins()
