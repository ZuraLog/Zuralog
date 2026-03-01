"""
Zuralog Cloud Brain — Polar Webhook Handler Tests.

Tests for /api/v1/webhooks/polar endpoint.
"""

import hashlib
import hmac as _hmac
import json
import sys
import types
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

_SETTINGS_PATH = "app.api.v1.polar_webhooks.settings"


def _make_signature(body: bytes, secret: str) -> str:
    """Compute a valid HMAC-SHA256 signature for testing."""
    return _hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


@pytest.fixture(scope="module", autouse=True)
def _mock_polar_sync_module():
    """Inject a mock polar_sync module so lazy import in the handler works."""
    mock_task = MagicMock()
    mock_module = types.ModuleType("app.tasks.polar_sync")
    mock_module.sync_polar_webhook_task = mock_task

    # Ensure parent package exists in sys.modules
    if "app.tasks" not in sys.modules:
        sys.modules["app.tasks"] = types.ModuleType("app.tasks")

    sys.modules["app.tasks.polar_sync"] = mock_module
    yield mock_task
    sys.modules.pop("app.tasks.polar_sync", None)


@pytest.fixture(scope="module")
def client():
    """Module-scoped TestClient — avoids repeated lifespan startup/teardown."""
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


def _post_event(client, payload: dict, *, secret: str = "", event_type: str = "EXERCISE"):
    """Helper: POST a JSON webhook event with optional HMAC signature."""
    body = json.dumps(payload).encode()
    headers = {"Content-Type": "application/json", "Polar-Webhook-Event": event_type}
    if secret:
        headers["Polar-Webhook-Signature"] = _make_signature(body, secret)
    return client.post("/api/v1/webhooks/polar", content=body, headers=headers)


# ---------------------------------------------------------------------------
# Signature verification
# ---------------------------------------------------------------------------


class TestSignatureVerification:
    def test_valid_signature_passes(self, client, _mock_polar_sync_module):
        """Valid HMAC-SHA256 signature → 200 and task dispatched."""
        secret = "mysecretkey"
        payload = {"event": "EXERCISE", "user_id": 123, "entity_id": "abc"}
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = secret
            response = _post_event(client, payload, secret=secret, event_type="EXERCISE")

        assert response.status_code == 200
        _mock_polar_sync_module.delay.assert_called_once()

    def test_invalid_signature_rejected_but_returns_200(self, client, _mock_polar_sync_module):
        """Invalid HMAC signature → 200 (never fail with non-200) and no task."""
        secret = "correctsecret"
        payload = {"event": "EXERCISE", "user_id": 123, "entity_id": "abc"}
        body = json.dumps(payload).encode()
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = secret
            response = client.post(
                "/api/v1/webhooks/polar",
                content=body,
                headers={
                    "Content-Type": "application/json",
                    "Polar-Webhook-Event": "EXERCISE",
                    "Polar-Webhook-Signature": "invalidsignature",
                },
            )

        assert response.status_code == 200
        _mock_polar_sync_module.delay.assert_not_called()

    def test_missing_signature_key_skips_verification(self, client, _mock_polar_sync_module):
        """No signature key configured → skip verification, dispatch task normally."""
        payload = {"event": "EXERCISE", "user_id": 123, "entity_id": "abc"}
        body = json.dumps(payload).encode()
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""  # not configured
            response = client.post(
                "/api/v1/webhooks/polar",
                content=body,
                headers={"Content-Type": "application/json", "Polar-Webhook-Event": "EXERCISE"},
            )

        assert response.status_code == 200
        _mock_polar_sync_module.delay.assert_called_once()


# ---------------------------------------------------------------------------
# PING event
# ---------------------------------------------------------------------------


class TestPingEvent:
    def test_ping_event_returns_200(self, client, _mock_polar_sync_module):
        """PING event → 200 OK (webhook URL is live confirmation)."""
        payload = {"event": "PING"}
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            response = _post_event(client, payload, event_type="PING")

        assert response.status_code == 200

    def test_ping_event_does_not_dispatch_task(self, client, _mock_polar_sync_module):
        """PING event → no Celery task dispatched."""
        payload = {"event": "PING"}
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            _post_event(client, payload, event_type="PING")

        _mock_polar_sync_module.delay.assert_not_called()

    def test_ping_in_header_only_returns_200_no_task(self, client, _mock_polar_sync_module):
        """PING detected via header (event body may differ) → 200, no task."""
        payload = {"user_id": 999}  # no "event" key
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            response = _post_event(client, payload, event_type="PING")

        assert response.status_code == 200
        _mock_polar_sync_module.delay.assert_not_called()


# ---------------------------------------------------------------------------
# EXERCISE event
# ---------------------------------------------------------------------------


class TestExerciseEvent:
    def test_exercise_event_dispatches_sync_task(self, client, _mock_polar_sync_module):
        """EXERCISE event → sync_polar_webhook_task.delay called with correct args."""
        payload = {
            "event": "EXERCISE",
            "user_id": 475,
            "entity_id": "aQlC83",
            "timestamp": "2018-05-15T14:22:24Z",
            "url": "https://www.polaraccesslink.com/v3/exercises/aQlC83",
        }
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            _post_event(client, payload, event_type="EXERCISE")

        _mock_polar_sync_module.delay.assert_called_once_with(
            polar_user_id=475,
            event_type="EXERCISE",
            entity_id="aQlC83",
            url="https://www.polaraccesslink.com/v3/exercises/aQlC83",
            date=None,
        )

    def test_exercise_event_returns_200(self, client, _mock_polar_sync_module):
        """EXERCISE event → always returns 200 OK."""
        payload = {"event": "EXERCISE", "user_id": 475, "entity_id": "aQlC83"}
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            response = _post_event(client, payload, event_type="EXERCISE")

        assert response.status_code == 200


# ---------------------------------------------------------------------------
# Other events
# ---------------------------------------------------------------------------


class TestOtherEvents:
    def test_sleep_event_dispatches_task(self, client, _mock_polar_sync_module):
        """SLEEP event → task dispatched."""
        payload = {"event": "SLEEP", "user_id": 100, "entity_id": "sleep42"}
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            _post_event(client, payload, event_type="SLEEP")

        _mock_polar_sync_module.delay.assert_called_once_with(
            polar_user_id=100,
            event_type="SLEEP",
            entity_id="sleep42",
            url=None,
            date=None,
        )

    def test_activity_event_dispatches_task(self, client, _mock_polar_sync_module):
        """ACTIVITY_SUMMARY event → task dispatched."""
        payload = {
            "event": "ACTIVITY_SUMMARY",
            "user_id": 200,
            "entity_id": "act99",
            "date": "2026-03-01",
        }
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            _post_event(client, payload, event_type="ACTIVITY_SUMMARY")

        _mock_polar_sync_module.delay.assert_called_once_with(
            polar_user_id=200,
            event_type="ACTIVITY_SUMMARY",
            entity_id="act99",
            url=None,
            date="2026-03-01",
        )


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------


class TestEdgeCases:
    def test_missing_user_id_returns_200_no_task(self, client, _mock_polar_sync_module):
        """Payload without user_id → 200, no task dispatched."""
        payload = {"event": "EXERCISE", "entity_id": "abc"}  # no user_id
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            response = _post_event(client, payload, event_type="EXERCISE")

        assert response.status_code == 200
        _mock_polar_sync_module.delay.assert_not_called()

    def test_malformed_json_returns_200(self, client, _mock_polar_sync_module):
        """Non-JSON body → 200 (never expose errors to Polar)."""
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            response = client.post(
                "/api/v1/webhooks/polar",
                content=b"not-valid-json!!!",
                headers={
                    "Content-Type": "application/json",
                    "Polar-Webhook-Event": "EXERCISE",
                },
            )

        assert response.status_code == 200

    def test_unknown_event_dispatches_task(self, client, _mock_polar_sync_module):
        """Unknown event types are still dispatched (forward-compatible)."""
        payload = {"event": "FUTURE_EVENT", "user_id": 777, "entity_id": "xyz"}
        _mock_polar_sync_module.reset_mock()
        with patch(_SETTINGS_PATH) as mock_settings:
            mock_settings.polar_webhook_signature_key = ""
            response = _post_event(client, payload, event_type="FUTURE_EVENT")

        assert response.status_code == 200
        _mock_polar_sync_module.delay.assert_called_once()
