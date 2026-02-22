"""
Life Logger Cloud Brain — API Smoke Tests.

Quick validation that all critical API surfaces are responsive
and enforce input validation correctly. These tests do NOT verify
business logic — they confirm the API contract (routes exist,
schemas are enforced, auth is required where expected).
"""

from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService


class TestAPISmokeTests:
    """Smoke tests for all major API endpoints.

    Validates route reachability, input validation (422 for bad
    payloads), authentication enforcement, and OpenAPI availability.
    """

    @pytest.fixture(autouse=True)
    def _setup_client(self):
        """Set up TestClient with mocked dependencies for each test.

        Installs dependency overrides before each test and tears
        them down afterward. Exposes ``self.client`` on the instance.
        """
        mock_auth = AsyncMock(spec=AuthService)
        mock_db = AsyncMock()

        app.dependency_overrides[_get_auth_service] = lambda: mock_auth
        app.dependency_overrides[get_db] = lambda: mock_db

        with TestClient(app, raise_server_exceptions=False) as c:
            self.client = c
            yield

        app.dependency_overrides.clear()

    # ------------------------------------------------------------------
    # Health
    # ------------------------------------------------------------------

    def test_health_endpoint(self):
        """GET /health returns 200 with healthy status."""
        response = self.client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"

    # ------------------------------------------------------------------
    # Auth — input validation
    # ------------------------------------------------------------------

    def test_auth_register_rejects_empty(self):
        """POST /api/v1/auth/register with {} returns 422.

        Pydantic requires email and password fields; an empty
        body must be rejected by the schema validator.
        """
        response = self.client.post("/api/v1/auth/register", json={})
        assert response.status_code == 422

    def test_auth_login_rejects_empty(self):
        """POST /api/v1/auth/login with {} returns 422.

        Pydantic requires email and password fields.
        """
        response = self.client.post("/api/v1/auth/login", json={})
        assert response.status_code == 422

    def test_auth_refresh_rejects_empty(self):
        """POST /api/v1/auth/refresh with {} returns 422.

        Pydantic requires the refresh_token field.
        """
        response = self.client.post("/api/v1/auth/refresh", json={})
        assert response.status_code == 422

    # ------------------------------------------------------------------
    # Analytics — required query params
    # ------------------------------------------------------------------

    def test_analytics_daily_summary_requires_user_id(self):
        """GET /api/v1/analytics/daily-summary without user_id returns 422.

        The ``user_id`` query parameter is declared as required via
        ``Query(...)``.
        """
        response = self.client.get("/api/v1/analytics/daily-summary")
        assert response.status_code == 422

    def test_analytics_weekly_trends_requires_user_id(self):
        """GET /api/v1/analytics/weekly-trends without user_id returns 422.

        The ``user_id`` query parameter is declared as required.
        """
        response = self.client.get("/api/v1/analytics/weekly-trends")
        assert response.status_code == 422

    # ------------------------------------------------------------------
    # Webhooks — auth enforcement
    # ------------------------------------------------------------------

    def test_webhook_rejects_no_auth(self):
        """POST /api/v1/webhooks/revenuecat without auth header rejects.

        The endpoint validates the Authorization header against a
        shared secret. Missing or invalid auth returns 403.
        """
        response = self.client.post(
            "/api/v1/webhooks/revenuecat",
            json={"event": {"type": "TEST"}},
        )
        assert response.status_code == 403

    # ------------------------------------------------------------------
    # OpenAPI / Docs
    # ------------------------------------------------------------------

    def test_openapi_schema_accessible(self):
        """GET /openapi.json returns 200 with correct title and paths.

        Validates that the generated OpenAPI schema is accessible
        and contains the expected application metadata.
        """
        response = self.client.get("/openapi.json")
        assert response.status_code == 200
        schema = response.json()
        assert schema["info"]["title"] == "Life Logger Cloud Brain"
        assert "/health" in schema["paths"]
        assert "/api/v1/auth/register" in schema["paths"]

    def test_swagger_docs_accessible(self):
        """GET /docs returns 200 (Swagger UI HTML page)."""
        response = self.client.get("/docs")
        assert response.status_code == 200
