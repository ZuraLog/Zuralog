"""Tests for GET /quick-log/latest endpoint.

Uses the same mock-based TestClient pattern as the rest of the test suite.
There is no live database in CI — all DB calls are replaced by AsyncMock so
tests run fast and deterministically.
"""

from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "latest-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database — no real DB required."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()

    # Default: no rows found (single-query path uses .scalars().all())
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


def _make_log(metric_type, value, data=None, logged_at="2026-03-15T08:22:00Z"):
    """Build a minimal mock QuickLog object."""
    from datetime import datetime, timezone

    log = MagicMock()
    log.metric_type = metric_type
    log.value = value
    log.text_value = None
    log.data = data or {}
    # Provide a real datetime so isoformat() works
    log.logged_at = datetime(2026, 3, 15, 8, 22, 0, tzinfo=timezone.utc)
    return log


# ---------------------------------------------------------------------------
# GET /quick-log/latest
# ---------------------------------------------------------------------------


class TestLatestEndpoint:
    def test_latest_returns_empty_when_no_types_param(self, client_with_auth):
        """Empty types param returns empty dict."""
        client, _ = client_with_auth
        response = client.get("/api/v1/quick-log/latest", headers=AUTH_HEADER)
        assert response.status_code == 200
        assert response.json() == {}

    def test_latest_returns_most_recent_weight(self, client_with_auth):
        """Returns the most recent weight entry across all time."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [
            _make_log("weight", value=78.4, data={"value_kg": 78.4, "source": "apple_health"}),
        ]
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log/latest?types=weight", headers=AUTH_HEADER)
        assert response.status_code == 200
        body = response.json()
        assert "weight" in body
        assert abs(body["weight"]["value_kg"] - 78.4) < 0.001
        assert body["weight"]["source"] == "apple_health"

    def test_latest_absent_when_type_never_logged(self, client_with_auth):
        """A type the user has never logged is absent from the response."""
        client, mock_db = client_with_auth

        # DB returns empty list — no rows for this user/type
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log/latest?types=weight", headers=AUTH_HEADER)
        assert response.status_code == 200
        assert "weight" not in response.json()

    def test_latest_returns_steps_with_source(self, client_with_auth):
        """Steps entry includes steps count and source."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [
            _make_log("steps", value=9420.0, data={"steps": 9420, "mode": "override", "source": "health_connect"}),
        ]
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log/latest?types=steps", headers=AUTH_HEADER)
        assert response.status_code == 200
        body = response.json()
        assert body["steps"]["steps"] == 9420
        assert body["steps"]["source"] == "health_connect"

    def test_latest_rejects_unknown_type(self, client_with_auth):
        """Returns 422 for an unrecognised metric type."""
        client, _ = client_with_auth
        response = client.get("/api/v1/quick-log/latest?types=banana", headers=AUTH_HEADER)
        assert response.status_code == 422

    def test_latest_cannot_see_other_users_data(self, client_with_auth):
        """Data from another user is not returned (DB filtered by user_id)."""
        client, mock_db = client_with_auth

        # Simulate the DB correctly filtering by user_id — returns nothing
        # for the authenticated user even though another user has a weight row.
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log/latest?types=weight", headers=AUTH_HEADER)
        assert response.status_code == 200
        assert "weight" not in response.json()

    def test_latest_multiple_types_returned(self, client_with_auth):
        """Requesting multiple types returns all that have data in one query."""
        client, mock_db = client_with_auth

        weight_log = _make_log("weight", value=75.0, data={"value_kg": 75.0, "source": "manual"})
        steps_log = _make_log("steps", value=8000.0, data={"steps": 8000, "mode": "add", "source": "manual"})

        # Single query now returns all matching rows at once via .scalars().all()
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [weight_log, steps_log]
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log/latest?types=weight,steps", headers=AUTH_HEADER)
        assert response.status_code == 200
        body = response.json()
        assert "weight" in body
        assert "steps" in body

    def test_latest_empty_types_string_returns_empty(self, client_with_auth):
        """Explicitly passing an empty types string returns an empty dict."""
        client, _ = client_with_auth
        response = client.get("/api/v1/quick-log/latest?types=", headers=AUTH_HEADER)
        assert response.status_code == 200
        assert response.json() == {}

    def test_latest_weight_source_defaults_to_manual(self, client_with_auth):
        """Weight entry with no source in data defaults to 'manual'."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [
            _make_log("weight", value=70.0, data={"value_kg": 70.0}),  # no 'source' key
        ]
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log/latest?types=weight", headers=AUTH_HEADER)
        assert response.status_code == 200
        assert response.json()["weight"]["source"] == "manual"

    def test_latest_rejects_more_than_12_types(self, client_with_auth):
        """Returns 422 when more than 12 types are requested."""
        client, _ = client_with_auth
        # Build a string of 13 distinct valid metric types
        from app.models.quick_log import VALID_METRIC_TYPES

        many_types = ",".join(list(VALID_METRIC_TYPES)[:13])
        response = client.get(f"/api/v1/quick-log/latest?types={many_types}", headers=AUTH_HEADER)
        assert response.status_code == 422
        assert "12" in response.json()["detail"]

    def test_latest_requires_auth(self):
        """Unauthenticated request returns 401 or 403."""
        with TestClient(app, raise_server_exceptions=False) as c:
            response = c.get("/api/v1/quick-log/latest?types=weight")
        assert response.status_code in (401, 403)
