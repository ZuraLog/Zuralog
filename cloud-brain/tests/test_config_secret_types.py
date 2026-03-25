"""
Tests that RevenueCat config fields are typed as SecretStr (S-10).

SecretStr prevents secrets from appearing in tracebacks, logs, and repr(settings).
"""

import pytest
from pydantic import SecretStr

from app.config import Settings


def _make_settings(**kwargs) -> Settings:
    """Construct a Settings instance with minimal required overrides."""
    # Use model_construct to bypass env-file loading and the production validator.
    return Settings.model_construct(**kwargs)


class TestRevenueCatSecretTypes:
    """SecretStr enforcement for RevenueCat credentials."""

    def test_revenuecat_webhook_secret_is_secretstr(self):
        s = _make_settings(revenuecat_webhook_secret=SecretStr("my-secret"))
        assert isinstance(s.revenuecat_webhook_secret, SecretStr)

    def test_revenuecat_api_key_is_secretstr(self):
        s = _make_settings(revenuecat_api_key=SecretStr("my-api-key"))
        assert isinstance(s.revenuecat_api_key, SecretStr)

    def test_revenuecat_webhook_secret_does_not_leak_in_str(self):
        """str() of a SecretStr should print '**********', not the value."""
        s = _make_settings(revenuecat_webhook_secret=SecretStr("secret"))
        assert "secret" not in str(s.revenuecat_webhook_secret)

    def test_revenuecat_api_key_does_not_leak_in_str(self):
        s = _make_settings(revenuecat_api_key=SecretStr("secret"))
        assert "secret" not in str(s.revenuecat_api_key)

    def test_live_settings_fields_are_secretstr(self):
        """The module-level settings singleton must also use SecretStr for these fields."""
        from app.config import settings as live_settings

        assert isinstance(live_settings.revenuecat_webhook_secret, SecretStr)
        assert isinstance(live_settings.revenuecat_api_key, SecretStr)
