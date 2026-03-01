"""
Zuralog Cloud Brain — Oura Ring Webhook Handler Tests.

Tests for the /api/v1/webhooks/oura endpoint.
"""

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

_TASK_PATH = "app.tasks.oura_sync.sync_oura_webhook_task"


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


# ---------------------------------------------------------------------------
# POST /webhooks/oura
# ---------------------------------------------------------------------------


class TestOuraWebhookEvent:
    def test_valid_payload_returns_200(self, client):
        """Valid Oura webhook payload → HTTP 200."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "create",
                    "data_type": "daily_sleep",
                    "object_id": "sleep-123",
                    "user_id": "OURA456",
                },
            )

        assert response.status_code == 200

    def test_valid_payload_dispatches_celery_task(self, client):
        """Valid payload dispatches sync_oura_webhook_task with correct args."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "create",
                    "data_type": "daily_sleep",
                    "object_id": "sleep-123",
                    "user_id": "OURA456",
                },
            )

        mock_task.delay.assert_called_once_with(
            data_type="daily_sleep",
            event_type="create",
            oura_user_id="OURA456",
        )

    def test_update_event_dispatches_task(self, client):
        """update event_type is dispatched correctly."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "update",
                    "data_type": "daily_activity",
                    "object_id": "act-789",
                    "user_id": "OURA999",
                },
            )

        assert response.status_code == 200
        mock_task.delay.assert_called_once_with(
            data_type="daily_activity",
            event_type="update",
            oura_user_id="OURA999",
        )

    def test_delete_event_dispatches_task(self, client):
        """delete event_type is dispatched correctly."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "delete",
                    "data_type": "sleep",
                    "object_id": "sleep-del-1",
                    "user_id": "OURA111",
                },
            )

        assert response.status_code == 200
        mock_task.delay.assert_called_once_with(
            data_type="sleep",
            event_type="delete",
            oura_user_id="OURA111",
        )

    def test_malformed_json_returns_200(self, client):
        """Malformed JSON body → 200 (never expose errors to Oura)."""
        response = client.post(
            "/api/v1/webhooks/oura",
            content=b"not-valid-json-{{{",
            headers={"Content-Type": "application/json"},
        )
        assert response.status_code == 200

    def test_empty_body_returns_200(self, client):
        """Empty JSON body → 200, no tasks dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={},
            )

        assert response.status_code == 200
        mock_task.delay.assert_not_called()

    def test_missing_data_type_does_not_dispatch(self, client):
        """Missing data_type → 200 but no Celery task dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "create",
                    "object_id": "obj-1",
                    "user_id": "OURA123",
                    # no data_type
                },
            )

        assert response.status_code == 200
        mock_task.delay.assert_not_called()

    def test_missing_event_type_does_not_dispatch(self, client):
        """Missing event_type → 200 but no Celery task dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "data_type": "daily_sleep",
                    "object_id": "obj-1",
                    "user_id": "OURA123",
                    # no event_type
                },
            )

        assert response.status_code == 200
        mock_task.delay.assert_not_called()

    def test_celery_task_failure_still_returns_200(self, client):
        """If Celery task dispatch raises, we still return 200."""
        mock_task = MagicMock()
        mock_task.delay.side_effect = Exception("Celery broker down")

        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "create",
                    "data_type": "daily_readiness",
                    "object_id": "ready-1",
                    "user_id": "OURA123",
                },
            )

        assert response.status_code == 200

    def test_missing_user_id_still_dispatches(self, client):
        """Missing user_id passes empty string; task still dispatched."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "create",
                    "data_type": "daily_sleep",
                    "object_id": "sleep-1",
                    # no user_id
                },
            )

        assert response.status_code == 200
        mock_task.delay.assert_called_once_with(
            data_type="daily_sleep",
            event_type="create",
            oura_user_id="",
        )

    def test_all_oura_data_types_dispatch_correctly(self, client):
        """All known Oura data types dispatch task without error."""
        data_types = [
            "daily_sleep",
            "sleep",
            "daily_activity",
            "daily_readiness",
            "heartrate",
            "daily_spo2",
            "daily_stress",
            "workout",
            "session",
            "daily_resilience",
        ]
        for data_type in data_types:
            mock_task = MagicMock()
            with patch(_TASK_PATH, mock_task):
                response = client.post(
                    "/api/v1/webhooks/oura",
                    json={
                        "event_type": "create",
                        "data_type": data_type,
                        "object_id": "obj-1",
                        "user_id": "OURA123",
                    },
                )
            assert response.status_code == 200, f"Failed for data_type={data_type}"
            mock_task.delay.assert_called_once()

    def test_response_body_is_empty(self, client):
        """200 response has no body content."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/oura",
                json={
                    "event_type": "create",
                    "data_type": "daily_sleep",
                    "user_id": "OUR123",
                },
            )
        assert response.status_code == 200
        assert response.content == b""
