"""
Life Logger Cloud Brain — RevenueCat Webhook Handler Tests.

Tests the /webhooks/revenuecat endpoint for authentication,
event parsing, and delegation to SubscriptionService.
"""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.v1.webhooks import router
from app.database import get_db


@pytest.fixture
def app():
    """Create a test FastAPI app with webhook router."""
    test_app = FastAPI()
    test_app.include_router(router, prefix="/api/v1")
    return test_app


@pytest.fixture
async def client(app):
    """Create an async test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


class TestWebhookAuth:
    """Tests for webhook authentication."""

    @pytest.mark.asyncio
    @patch("app.api.v1.webhooks.settings")
    async def test_rejects_missing_auth(self, mock_settings, client):
        """Request without Authorization header should be rejected with 403."""
        mock_settings.revenuecat_webhook_secret = "secret-123"
        response = await client.post("/api/v1/webhooks/revenuecat", json={})
        assert response.status_code == 403

    @pytest.mark.asyncio
    @patch("app.api.v1.webhooks.settings")
    async def test_rejects_wrong_secret(self, mock_settings, client):
        """Request with incorrect secret should be rejected with 403."""
        mock_settings.revenuecat_webhook_secret = "secret-123"
        response = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={},
            headers={"Authorization": "Bearer wrong-secret"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    @patch("app.api.v1.webhooks.SubscriptionService")
    @patch("app.api.v1.webhooks.settings")
    async def test_accepts_correct_secret(self, mock_settings, mock_service_cls, app, client):
        """Request with correct secret should return 200 with received=True."""
        mock_settings.revenuecat_webhook_secret = "secret-123"

        # Override the DB dependency with a mock
        mock_db = AsyncMock()

        async def fake_get_db():
            yield mock_db

        app.dependency_overrides[get_db] = fake_get_db

        # Mock the service
        mock_service = AsyncMock()
        mock_service_cls.return_value = mock_service

        try:
            response = await client.post(
                "/api/v1/webhooks/revenuecat",
                json={
                    "event": {
                        "type": "INITIAL_PURCHASE",
                        "app_user_id": "u-1",
                        "expiration_at_ms": 1740000000000,
                        "product_id": "pro_monthly",
                    }
                },
                headers={"Authorization": "Bearer secret-123"},
            )
            assert response.status_code == 200
            assert response.json() == {"received": True}
        finally:
            app.dependency_overrides.clear()

    @pytest.mark.asyncio
    @patch("app.api.v1.webhooks.settings")
    async def test_rejects_malformed_json(self, mock_settings, app, client):
        """Request with malformed JSON body should return 400."""
        mock_settings.revenuecat_webhook_secret = "secret-123"

        response = await client.post(
            "/api/v1/webhooks/revenuecat",
            content=b"not valid json{{{",
            headers={
                "Authorization": "Bearer secret-123",
                "Content-Type": "application/json",
            },
        )
        assert response.status_code == 400
