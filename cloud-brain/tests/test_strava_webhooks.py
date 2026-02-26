"""Tests for Strava webhook endpoint."""

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

_TASK_PATH = "app.services.sync_scheduler.sync_strava_activity_task"


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


class TestWebhookValidation:
    def test_responds_with_challenge(self, client):
        """Strava subscription validation echoes hub.challenge."""
        with patch("app.api.v1.strava_webhooks.settings") as mock_settings:
            mock_settings.strava_webhook_verify_token = "test-token"
            response = client.get(
                "/api/v1/webhooks/strava",
                params={
                    "hub.mode": "subscribe",
                    "hub.verify_token": "test-token",
                    "hub.challenge": "challenge-abc",
                },
            )
        assert response.status_code == 200
        assert response.json() == {"hub.challenge": "challenge-abc"}

    def test_rejects_wrong_verify_token(self, client):
        """Rejects validation with wrong verify token."""
        with patch("app.api.v1.strava_webhooks.settings") as mock_settings:
            mock_settings.strava_webhook_verify_token = "test-token"
            response = client.get(
                "/api/v1/webhooks/strava",
                params={
                    "hub.mode": "subscribe",
                    "hub.verify_token": "wrong-token",
                    "hub.challenge": "challenge-abc",
                },
            )
        assert response.status_code == 403

    def test_rejects_unconfigured_verify_token(self, client):
        """Returns 503 when STRAVA_WEBHOOK_VERIFY_TOKEN is not configured."""
        with patch("app.api.v1.strava_webhooks.settings") as mock_settings:
            mock_settings.strava_webhook_verify_token = ""
            response = client.get(
                "/api/v1/webhooks/strava",
                params={
                    "hub.mode": "subscribe",
                    "hub.verify_token": "",
                    "hub.challenge": "challenge-abc",
                },
            )
        assert response.status_code == 503

    def test_rejects_invalid_hub_mode(self, client):
        """Returns 400 when hub.mode is not 'subscribe'."""
        with patch("app.api.v1.strava_webhooks.settings") as mock_settings:
            mock_settings.strava_webhook_verify_token = "test-token"
            response = client.get(
                "/api/v1/webhooks/strava",
                params={
                    "hub.mode": "unsubscribe",
                    "hub.verify_token": "test-token",
                    "hub.challenge": "challenge-abc",
                },
            )
        assert response.status_code == 400


class TestWebhookEvent:
    def test_accepts_activity_create(self, client):
        """Accepts and acknowledges activity create event; dispatches task."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/strava",
                json={
                    "object_type": "activity",
                    "aspect_type": "create",
                    "object_id": 12345,
                    "owner_id": 67890,
                    "subscription_id": 1,
                    "event_time": 1740000000,
                },
            )
        assert response.status_code == 200
        assert response.json() == {"received": True}
        mock_task.delay.assert_called_once_with(
            owner_id=67890,
            activity_id=12345,
            aspect_type="create",
        )

    def test_accepts_activity_update(self, client):
        """Accepts activity update event; dispatches task."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/strava",
                json={
                    "object_type": "activity",
                    "aspect_type": "update",
                    "object_id": 12345,
                    "owner_id": 67890,
                    "subscription_id": 1,
                    "event_time": 1740000001,
                },
            )
        assert response.status_code == 200
        assert response.json() == {"received": True}
        mock_task.delay.assert_called_once_with(
            owner_id=67890,
            activity_id=12345,
            aspect_type="update",
        )

    def test_accepts_activity_delete(self, client):
        """Accepts activity delete event; dispatches task."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/strava",
                json={
                    "object_type": "activity",
                    "aspect_type": "delete",
                    "object_id": 99999,
                    "owner_id": 67890,
                    "subscription_id": 1,
                    "event_time": 1740000002,
                },
            )
        assert response.status_code == 200
        assert response.json() == {"received": True}
        mock_task.delay.assert_called_once_with(
            owner_id=67890,
            activity_id=99999,
            aspect_type="delete",
        )

    def test_athlete_event_does_not_dispatch_task(self, client):
        """Athlete deauthorisation events are acknowledged but no task is fired."""
        mock_task = MagicMock()
        with patch(_TASK_PATH, mock_task):
            response = client.post(
                "/api/v1/webhooks/strava",
                json={
                    "object_type": "athlete",
                    "aspect_type": "update",
                    "object_id": 67890,
                    "owner_id": 67890,
                    "subscription_id": 1,
                    "event_time": 1740000003,
                },
            )
        assert response.status_code == 200
        assert response.json() == {"received": True}
        mock_task.delay.assert_not_called()
