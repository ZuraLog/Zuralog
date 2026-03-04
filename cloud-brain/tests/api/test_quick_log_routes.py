"""
Zuralog Cloud Brain — Quick Log API Route Tests.

Tests for the /api/v1/quick-log/* endpoints. Database and auth operations
are fully mocked following the project's established testing patterns.

Test coverage:
    - Single log creates entry (201)
    - Batch log creates multiple entries atomically
    - History query filters by metric_type
    - History query filters by date range
    - Auth guard returns 401/403
"""

import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "quick-log-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_log(**overrides) -> SimpleNamespace:
    """Build a QuickLog-shaped namespace with sensible defaults."""
    defaults = dict(
        id=str(uuid.uuid4()),
        user_id=TEST_USER_ID,
        metric_type="mood",
        value=7.0,
        text_value=None,
        tags=None,
        logged_at=datetime.now(tz=timezone.utc),
        created_at=datetime.now(tz=timezone.utc),
    )
    defaults.update(overrides)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _populate_id(obj):
    """Side-effect for mock_db.refresh: assigns a UUID to the id field."""
    if obj.id is None:
        obj.id = str(uuid.uuid4())


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database dependencies."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock(side_effect=_populate_id)

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


@pytest.fixture
def client_unauthenticated():
    """TestClient with no auth override."""
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


# ---------------------------------------------------------------------------
# POST /quick-log — Single Entry
# ---------------------------------------------------------------------------


class TestSingleQuickLog:
    def test_single_log_creates_entry(self, client_with_auth):
        """POST /quick-log creates one entry and returns 201."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log",
            json={"metric_type": "mood", "value": 7.0},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited()

    def test_single_log_with_text_value(self, client_with_auth):
        """POST /quick-log with text_value is accepted (201)."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log",
            json={"metric_type": "notes", "text_value": "Feeling rested"},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201

    def test_single_log_with_tags(self, client_with_auth):
        """POST /quick-log with tags is accepted (201)."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log",
            json={"metric_type": "symptoms", "tags": ["headache", "fatigue"]},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201

    def test_single_log_invalid_metric_type(self, client_with_auth):
        """POST /quick-log with unknown metric_type returns 422."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log",
            json={"metric_type": "invalid_type", "value": 5},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 422


# ---------------------------------------------------------------------------
# POST /quick-log/batch — Batch Entry
# ---------------------------------------------------------------------------


class TestBatchQuickLog:
    def test_batch_creates_multiple_entries(self, client_with_auth):
        """POST /quick-log/batch returns 201 and calls db.add for each entry."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log/batch",
            json={
                "entries": [
                    {"metric_type": "water", "value": 250.0},
                    {"metric_type": "energy", "value": 8.0},
                    {"metric_type": "stress", "value": 4.0},
                ]
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201
        assert mock_db.add.call_count == 3
        mock_db.commit.assert_awaited()

    def test_batch_all_share_user_id(self, client_with_auth):
        """Batch entries all receive the authenticated user's ID (checked via add calls)."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log/batch",
            json={
                "entries": [
                    {"metric_type": "mood", "value": 5.0},
                    {"metric_type": "pain", "value": 2.0},
                ]
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201
        # Verify each added object has the correct user_id
        for call in mock_db.add.call_args_list:
            added_obj = call.args[0]
            assert added_obj.user_id == TEST_USER_ID

    def test_batch_empty_list_rejected(self, client_with_auth):
        """POST /quick-log/batch with empty entries returns 422."""
        client, mock_db = client_with_auth

        response = client.post(
            "/api/v1/quick-log/batch",
            json={"entries": []},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 422


# ---------------------------------------------------------------------------
# GET /quick-log — History
# ---------------------------------------------------------------------------


class TestQuickLogHistory:
    def test_history_returns_200(self, client_with_auth):
        """GET /quick-log returns 200."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [
            _make_log(metric_type="mood"),
            _make_log(metric_type="energy"),
        ]
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/quick-log", headers=AUTH_HEADER)
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_history_filters_by_metric_type(self, client_with_auth):
        """GET /quick-log?metric_type=water calls db.execute with type filter."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [
            _make_log(metric_type="water", value=500.0),
        ]
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get(
            "/api/v1/quick-log",
            params={"metric_type": "water"},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        mock_db.execute.assert_awaited_once()

    def test_history_filters_by_date_range(self, client_with_auth):
        """GET /quick-log with start/end params calls db.execute once."""
        client, mock_db = client_with_auth

        now = datetime.now(tz=timezone.utc)
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get(
            "/api/v1/quick-log",
            params={
                "start": (now - timedelta(days=30)).isoformat(),
                "end": now.isoformat(),
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        mock_db.execute.assert_awaited_once()


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_get_requires_auth(self, client_unauthenticated):
        """GET /quick-log without Authorization returns 401/403."""
        response = client_unauthenticated.get("/api/v1/quick-log")
        assert response.status_code in (401, 403)

    def test_post_requires_auth(self, client_unauthenticated):
        """POST /quick-log without Authorization returns 401/403."""
        response = client_unauthenticated.post(
            "/api/v1/quick-log",
            json={"metric_type": "mood", "value": 5},
        )
        assert response.status_code in (401, 403)

    def test_batch_requires_auth(self, client_unauthenticated):
        """POST /quick-log/batch without Authorization returns 401/403."""
        response = client_unauthenticated.post(
            "/api/v1/quick-log/batch",
            json={"entries": [{"metric_type": "mood", "value": 5}]},
        )
        assert response.status_code in (401, 403)
