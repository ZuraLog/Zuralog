"""
Life Logger Cloud Brain — Full User Journey Integration Tests.

End-to-end tests simulating a complete user lifecycle:
register, login, token refresh, and logout. All external
dependencies (Supabase, PostgreSQL) are mocked via FastAPI
dependency_overrides using the shared ``integration_client``
fixture from conftest.
"""

from unittest.mock import AsyncMock, patch

import pytest


class TestFullUserJourney:
    """Integration tests for the complete auth lifecycle.

    Verifies health check, register -> login -> refresh flow,
    and logout authorization requirements.
    """

    @pytest.fixture(autouse=True)
    def _setup(self, integration_client):
        """Bind shared integration_client fixture to instance attrs.

        Args:
            integration_client: Shared fixture providing
                (TestClient, mock_auth_service, mock_db).
        """
        self.client, self.mock_auth, self.mock_db = integration_client

    def test_health_check_is_available(self):
        """GET /health returns 200 with healthy status."""
        response = self.client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "healthy"}

    def test_register_login_refresh_flow(self):
        """Full flow: register -> login -> refresh token.

        Simulates a new user signing up, logging in, and
        refreshing their session token — all in sequence.
        """
        auth_data = {
            "user_id": "flow-user-001",
            "access_token": "flow-at-abc",
            "refresh_token": "flow-rt-xyz",
            "expires_in": 3600,
        }

        # --- Step 1: Register ---
        self.mock_auth.sign_up.return_value = auth_data

        with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
            reg_resp = self.client.post(
                "/api/v1/auth/register",
                json={"email": "flow@example.com", "password": "FlowTest1!"},
            )

        assert reg_resp.status_code == 200
        reg_data = reg_resp.json()
        assert reg_data["user_id"] == "flow-user-001"
        assert reg_data["access_token"] == "flow-at-abc"

        # --- Step 2: Login ---
        self.mock_auth.sign_in.return_value = auth_data

        with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
            login_resp = self.client.post(
                "/api/v1/auth/login",
                json={"email": "flow@example.com", "password": "FlowTest1!"},
            )

        assert login_resp.status_code == 200
        login_data = login_resp.json()
        assert login_data["access_token"] == "flow-at-abc"

        # --- Step 3: Refresh ---
        refreshed_data = {
            "user_id": "flow-user-001",
            "access_token": "flow-at-new",
            "refresh_token": "flow-rt-new",
            "expires_in": 3600,
        }
        self.mock_auth.refresh_session.return_value = refreshed_data

        refresh_resp = self.client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "flow-rt-xyz"},
        )

        assert refresh_resp.status_code == 200
        refresh_data = refresh_resp.json()
        assert refresh_data["access_token"] == "flow-at-new"
        assert refresh_data["refresh_token"] == "flow-rt-new"

    def test_logout_requires_auth(self):
        """POST /api/v1/auth/logout without token returns 401 or 403.

        The HTTPBearer dependency auto-rejects missing Authorization
        headers before the endpoint handler runs.
        """
        response = self.client.post("/api/v1/auth/logout")
        assert response.status_code in (401, 403)

    def test_logout_with_token(self):
        """POST /api/v1/auth/logout with valid Bearer token returns 200.

        Verifies the mock sign_out is called with the correct token.
        """
        self.mock_auth.sign_out.return_value = None

        response = self.client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": "Bearer flow-access-token"},
        )

        assert response.status_code == 200
        assert response.json()["message"] == "Logged out successfully"
        self.mock_auth.sign_out.assert_called_once_with("flow-access-token")
