"""Tests for Strava webhook endpoint."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app


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


class TestWebhookEvent:
    def test_accepts_activity_create(self, client):
        """Accepts and acknowledges activity create event."""
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

    def test_accepts_activity_update(self, client):
        """Accepts activity update event."""
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

    def test_accepts_activity_delete(self, client):
        """Accepts activity delete event."""
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
