"""
Tests that Settings raises ValueError for missing critical fields in production (S-11).

A deploy with empty DATABASE_URL, SUPABASE_URL, or SUPABASE_ANON_KEY must fail
immediately at startup rather than silently on the first DB/auth query.
"""

import pytest
from pydantic import SecretStr, ValidationError


def _prod_base() -> dict:
    """Minimum field set that satisfies the existing production validators."""
    return {
        "app_env": "production",
        "database_url": "postgresql+asyncpg://x:y@host/db",
        "supabase_url": "https://example.supabase.co",
        "supabase_anon_key": SecretStr("anon-key"),
        "supabase_service_key": SecretStr("service-key"),
        "openrouter_api_key": SecretStr("or-key"),
    }


class TestProductionValidation:
    """Critical fields must be non-empty in production."""

    def test_missing_database_url_raises(self):
        from app.config import Settings

        data = _prod_base()
        data["database_url"] = ""
        with pytest.raises((ValueError, ValidationError), match="DATABASE_URL"):
            Settings.model_validate(data)

    def test_missing_supabase_url_raises(self):
        from app.config import Settings

        data = _prod_base()
        data["supabase_url"] = ""
        with pytest.raises((ValueError, ValidationError), match="SUPABASE_URL"):
            Settings.model_validate(data)

    def test_missing_supabase_anon_key_raises(self):
        from app.config import Settings

        data = _prod_base()
        data["supabase_anon_key"] = SecretStr("")
        with pytest.raises((ValueError, ValidationError), match="SUPABASE_ANON_KEY"):
            Settings.model_validate(data)

    def test_valid_production_config_does_not_raise(self):
        from app.config import Settings

        data = _prod_base()
        s = Settings.model_validate(data)
        assert s.app_env == "production"
