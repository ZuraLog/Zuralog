"""
Zuralog Cloud Brain — Withings Webhook Handler Tests.

Tests for /api/v1/webhooks/withings endpoints.
"""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """TestClient for webhook endpoints (no auth required)."""
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


class TestWithingsWebhookPost:
    def test_returns_200_always(self, client):
        """POST /webhooks/withings always returns 200 OK."""
        response = client.post(
            "/api/v1/webhooks/withings",
            data={"userid": "12345", "appli": "1", "startdate": "1000", "enddate": "2000"},
        )
        assert response.status_code == 200

    def test_dispatches_sync_task(self, client):
        """POST /webhooks/withings dispatches a Celery sync task."""
        with patch("app.tasks.withings_sync.sync_withings_notification_task") as mock_task:
            mock_task.delay = lambda **kw: None
            response = client.post(
                "/api/v1/webhooks/withings",
                data={
                    "userid": "12345",
                    "appli": "44",
                    "startdate": "1700000000",
                    "enddate": "1700086400",
                    "date": "2023-11-15",
                },
            )
        assert response.status_code == 200

    def test_returns_200_for_empty_body(self, client):
        """POST /webhooks/withings with empty body returns 200."""
        response = client.post("/api/v1/webhooks/withings", data={})
        assert response.status_code == 200

    def test_returns_200_on_dispatch_failure(self, client):
        """POST /webhooks/withings returns 200 even if task dispatch fails."""
        with patch(
            "app.api.v1.withings_webhooks.sync_withings_notification_task",
            side_effect=Exception("Celery down"),
            create=True,
        ):
            response = client.post(
                "/api/v1/webhooks/withings",
                data={"userid": "12345", "appli": "1"},
            )
        assert response.status_code == 200

    def test_handles_all_appli_codes(self, client):
        """POST /webhooks/withings handles all known appli codes."""
        for appli_code in [1, 2, 4, 16, 44, 54, 62]:
            response = client.post(
                "/api/v1/webhooks/withings",
                data={"userid": "12345", "appli": str(appli_code)},
            )
            assert response.status_code == 200, f"Failed for appli={appli_code}"


class TestWithingsWebhookGet:
    def test_get_returns_200(self, client):
        """GET /webhooks/withings returns 200 for verification requests."""
        response = client.get("/api/v1/webhooks/withings")
        assert response.status_code == 200
