"""
Zuralog Cloud Brain — Fitbit Webhook Handler Tests.

Tests for the /api/v1/webhooks/fitbit endpoints.
"""

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

_TASK_PATH = "app.tasks.fitbit_sync.sync_fitbit_collection_task"


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


# ---------------------------------------------------------------------------
# GET /webhooks/fitbit — subscriber verification
# ---------------------------------------------------------------------------


class TestFitbitWebhookVerification:
    def test_correct_verify_code_returns_204(self, client):
        """Correct verify code → HTTP 204 (empty body)."""
        with patch("app.api.v1.fitbit_webhooks.settings") as mock_settings:
            mock_settings.fitbit_webhook_verify_code = "secret-verify-code"
            response = client.get(
                "/api/v1/webhooks/fitbit",
                params={"verify": "secret-verify-code"},
            )
        assert response.status_code == 204
        assert response.content == b""

    def test_wrong_verify_code_returns_404(self, client):
        """Wrong verify code → HTTP 404 (empty body)."""
        with patch("app.api.v1.fitbit_webhooks.settings") as mock_settings:
            mock_settings.fitbit_webhook_verify_code = "secret-verify-code"
            response = client.get(
                "/api/v1/webhooks/fitbit",
                params={"verify": "wrong-code"},
            )
        assert response.status_code == 404
        assert response.content == b""

    def test_missing_verify_param_returns_404(self, client):
        """Missing verify param → HTTP 404 (empty string mismatch)."""
        with patch("app.api.v1.fitbit_webhooks.settings") as mock_settings:
            mock_settings.fitbit_webhook_verify_code = "secret-verify-code"
            response = client.get("/api/v1/webhooks/fitbit")
        assert response.status_code == 404

    def test_empty_verify_code_matches_empty_config(self, client):
        """If configured code is empty string, empty verify param matches → 204."""
        with patch("app.api.v1.fitbit_webhooks.settings") as mock_settings:
            mock_settings.fitbit_webhook_verify_code = ""
            response = client.get(
                "/api/v1/webhooks/fitbit",
                params={"verify": ""},
            )
        assert response.status_code == 204


# ---------------------------------------------------------------------------
# POST /webhooks/fitbit — event notifications
# ---------------------------------------------------------------------------


class TestFitbitWebhookEvent:
    def _valid_notification(
        self,
        owner_id="FIT123",
        collection_type="activities",
        date="2026-02-28",
        subscription_id="1",
    ):
        return {
            "collectionType": collection_type,
            "date": date,
            "ownerId": owner_id,
            "ownerType": "user",
            "subscriptionId": subscription_id,
        }

    def test_valid_notification_returns_204_and_dispatches_task(self, client):
        """Valid notification array → 204 and Celery task dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=[self._valid_notification()],
            )

        assert response.status_code == 204
        assert response.content == b""
        mock_task.delay.assert_called_once_with("FIT123", "activities", "2026-02-28")

    def test_multiple_notifications_dispatch_multiple_tasks(self, client):
        """Multiple notifications → task dispatched for each one."""
        mock_task = MagicMock()
        notifications = [
            self._valid_notification(collection_type="activities", date="2026-02-28"),
            self._valid_notification(collection_type="sleep", date="2026-02-28"),
            self._valid_notification(collection_type="body", date="2026-02-27"),
        ]
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=notifications,
            )

        assert response.status_code == 204
        assert mock_task.delay.call_count == 3

    def test_sleep_collection_dispatches_task(self, client):
        """Sleep collection type is dispatched correctly."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=[self._valid_notification(collection_type="sleep", date="2026-02-27")],
            )

        assert response.status_code == 204
        mock_task.delay.assert_called_once_with("FIT123", "sleep", "2026-02-27")

    def test_body_collection_dispatches_task(self, client):
        """Body collection type is dispatched correctly."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=[self._valid_notification(collection_type="body", date="2026-02-26")],
            )

        assert response.status_code == 204
        mock_task.delay.assert_called_once_with("FIT123", "body", "2026-02-26")

    def test_invalid_json_returns_204(self, client):
        """Completely invalid (non-JSON) body → 204, never expose errors to Fitbit."""
        response = client.post(
            "/api/v1/webhooks/fitbit",
            content=b"not-valid-json-at-all!!!",
            headers={"Content-Type": "application/json"},
        )
        assert response.status_code == 204
        assert response.content == b""

    def test_non_array_body_returns_204(self, client):
        """JSON object (not array) body → 204, no tasks dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json={"collectionType": "activities"},  # object, not array
            )
        assert response.status_code == 204
        mock_task.delay.assert_not_called()

    def test_notification_missing_required_field_still_returns_204(self, client):
        """Malformed notification (missing field) → skip that item, still return 204."""
        mock_task = MagicMock()
        bad_notification = {"collectionType": "activities"}  # missing ownerId, date, etc.
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=[bad_notification],
            )
        assert response.status_code == 204
        mock_task.delay.assert_not_called()

    def test_mixed_valid_and_invalid_notifications(self, client):
        """Mix of valid and invalid → only valid ones dispatch tasks."""
        mock_task = MagicMock()
        notifications = [
            self._valid_notification(collection_type="activities"),  # valid
            {"collectionType": "sleep"},  # invalid — missing required fields
            self._valid_notification(collection_type="body", date="2026-02-25"),  # valid
        ]
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=notifications,
            )

        assert response.status_code == 204
        assert mock_task.delay.call_count == 2

    def test_empty_array_returns_204(self, client):
        """Empty notification array → 204, no tasks dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=[],
            )
        assert response.status_code == 204
        mock_task.delay.assert_not_called()

    def test_task_dispatch_failure_still_returns_204(self, client):
        """If Celery task dispatch raises, we still return 204."""
        mock_task = MagicMock()
        mock_task.delay.side_effect = Exception("Redis down")
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/fitbit",
                json=[self._valid_notification()],
            )
        assert response.status_code == 204
