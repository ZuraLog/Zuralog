"""Tests for GET /api/v1/supplements/insights endpoint."""

from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app

client = TestClient(app)

_TEST_USER_ID = "test-insights-user"


def _auth_override():
    return _TEST_USER_ID


def _make_mock_db():
    """Return an AsyncMock that mimics an empty DB (no rows for any query)."""
    mock_db = AsyncMock()
    # scalar() returns 0 (stack_size), scalars().all() returns []
    scalar_result = MagicMock()
    scalar_result.scalar.return_value = 0
    scalars_result = MagicMock()
    scalars_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(side_effect=[scalar_result, scalars_result, scalars_result])
    return mock_db


# ── Test 1: no auth → 401 ─────────────────────────────────────────────────────


def test_insights_requires_auth():
    """Unauthenticated request must return 401."""
    # Ensure the auth override is NOT active
    app.dependency_overrides.pop(get_authenticated_user_id, None)
    try:
        response = client.get("/api/v1/supplements/insights")
        assert response.status_code == 401
    finally:
        # Restore for other tests
        app.dependency_overrides.pop(get_authenticated_user_id, None)


# ── Test 2: days below minimum → 422 ─────────────────────────────────────────


def test_insights_days_below_minimum_returns_422():
    """?days=5 is below the ge=14 constraint, so FastAPI must return 422."""
    app.dependency_overrides[get_authenticated_user_id] = _auth_override
    try:
        response = client.get("/api/v1/supplements/insights?days=5")
        assert response.status_code == 422
    finally:
        app.dependency_overrides.pop(get_authenticated_user_id, None)


# ── Test 3: authenticated, empty DB → 200 with empty results ─────────────────


def test_insights_no_data_returns_empty():
    """Authenticated request with no supplement data returns 200 with empty insights.

    The endpoint performs an early return when stack_size == 0,
    so it never reaches the LLM call (no 503 risk).
    """
    mock_db = _make_mock_db()

    app.dependency_overrides[get_authenticated_user_id] = _auth_override
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        response = client.get("/api/v1/supplements/insights")
        assert response.status_code == 200
        data = response.json()
        assert data["insights"] == []
        assert data["has_enough_data"] is False
        assert data["data_days"] == 0
    finally:
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        app.dependency_overrides.pop(get_db, None)
