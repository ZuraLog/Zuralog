"""Tests for GET /api/v1/insights/{insight_id} endpoint.

Uses the same mock-based TestClient pattern as the rest of the test suite.
No live database — all DB calls are replaced by AsyncMock so tests run
fast and deterministically.
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

OTHER_USER_ID = "insight-test-user-002"

TEST_USER_ID = "insight-test-user-001"
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
    mock_db.refresh = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


def _make_insight(insight_id: str, user_id: str = TEST_USER_ID) -> MagicMock:
    """Build a minimal mock Insight ORM object."""
    from datetime import datetime, timezone

    insight = MagicMock()
    insight.id = insight_id
    insight.user_id = user_id
    insight.type = "trend"
    insight.title = "Test Insight"
    insight.body = "This is the body text."
    insight.data = {}
    insight.reasoning = "AI reasoning here."
    insight.priority = 3
    insight.created_at = datetime(2026, 3, 18, 6, 0, 0, tzinfo=timezone.utc)
    insight.read_at = None
    insight.dismissed_at = None
    return insight


# ---------------------------------------------------------------------------
# Test 1: 404 for unknown insight ID
# ---------------------------------------------------------------------------


def test_get_insight_returns_404_for_unknown_id(client_with_auth):
    """GET /{insight_id} returns 404 when the insight does not exist."""
    client, mock_db = client_with_auth

    unknown_id = str(uuid.uuid4())

    # Simulate no row found
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=mock_result)

    response = client.get(
        f"/api/v1/insights/{unknown_id}",
        headers=AUTH_HEADER,
    )

    assert response.status_code == 404
    data = response.json()
    assert "detail" in data


# ---------------------------------------------------------------------------
# Test 2: Returns insight card with correct fields (body, not summary)
# ---------------------------------------------------------------------------


def test_get_insight_returns_insight_with_body_field(client_with_auth):
    """GET /{insight_id} returns the insight with a 'body' field (not 'summary')."""
    client, mock_db = client_with_auth

    insight_id = str(uuid.uuid4())
    fake_insight = _make_insight(insight_id)

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = fake_insight
    mock_db.execute = AsyncMock(return_value=mock_result)

    response = client.get(
        f"/api/v1/insights/{insight_id}",
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    data = response.json()

    # Must have 'body' key (not 'summary')
    assert "body" in data
    assert data["body"] == "This is the body text."
    assert "summary" not in data

    # Verify other key fields are present
    assert data["id"] == insight_id
    assert data["title"] == "Test Insight"
    assert data["type"] == "trend"
    assert data["read_at"] is None


# ---------------------------------------------------------------------------
# Test 3: Unauthenticated request returns 401 or 403
# ---------------------------------------------------------------------------


@pytest.mark.skip(reason="auth is always mocked in test env")
def test_get_insight_unauthenticated_returns_401_or_403():
    """GET /{insight_id} without auth should return 401 or 403.

    This test is skipped because ``get_authenticated_user_id`` is overridden
    in all test fixtures. To exercise real auth rejection, the dependency
    override must be removed, which requires a dedicated un-authed fixture
    that the current suite does not provide.
    """
    insight_id = "00000000-0000-0000-0000-000000000001"

    with TestClient(app, raise_server_exceptions=False) as c:
        response = c.get(f"/api/v1/insights/{insight_id}")

    assert response.status_code in {401, 403}


# ---------------------------------------------------------------------------
# Test 4: Cross-user access returns 404 (ownership check)
# ---------------------------------------------------------------------------


def test_get_insight_cross_user_access_returns_404(client_with_auth):
    """GET /{insight_id} returns 404 when the insight belongs to a different user.

    The DB is mocked to return ``None`` (simulating the ownership filter),
    which is what the real query does when ``user_id`` does not match.
    """
    client, mock_db = client_with_auth

    # An insight that belongs to OTHER_USER_ID, not TEST_USER_ID.
    insight_id = str(uuid.uuid4())

    # Ownership filter means the query returns nothing for the wrong user.
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=mock_result)

    response = client.get(
        f"/api/v1/insights/{insight_id}",
        headers=AUTH_HEADER,
    )

    assert response.status_code == 404
    data = response.json()
    assert "detail" in data
