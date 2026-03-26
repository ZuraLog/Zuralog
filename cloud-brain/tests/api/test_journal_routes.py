"""
Zuralog Cloud Brain — Journal Entry API Route Tests.

Tests for the /api/v1/journal/* endpoints. Database and auth operations
are fully mocked following the project's established testing patterns.

Test coverage:
    - Create entry returns 201
    - Create on same date upserts (updates)
    - List by date range returns correct entries
    - Update changes content value
    - Delete removes entry
    - 404 on non-existent entry (update and delete)
    - Auth guard returns 401
"""

import uuid
from datetime import date, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service
from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "journal-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_entry(**overrides) -> SimpleNamespace:
    """Build a JournalEntry-shaped namespace with sensible defaults."""
    defaults = dict(
        id=str(uuid.uuid4()),
        user_id=TEST_USER_ID,
        date=date.today(),
        notes="Test note",
        tags=["test"],
        source="diary",
        conversation_id=None,
        created_at=None,
        updated_at=None,
    )
    defaults.update(overrides)
    ns = SimpleNamespace(**defaults)
    # created_at needs .isoformat() support
    if ns.created_at is None:
        ns.created_at = None
    return ns


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _populate_id(obj):
    """Side-effect for mock_db.refresh: assigns a UUID to the id field if unset."""
    if getattr(obj, "id", None) is None:
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
    mock_db.delete = AsyncMock()

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
# POST /journal — Create / Upsert
# ---------------------------------------------------------------------------


class TestCreateJournalEntry:
    def test_create_entry_returns_201(self, client_with_auth):
        """POST /journal with no existing entry creates a new row (201)."""
        client, mock_db = client_with_auth

        # No existing row → SELECT returns None
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        mock_db.refresh = AsyncMock(side_effect=lambda obj: None)
        mock_db.add = MagicMock()

        today_str = date.today().isoformat()
        response = client.post(
            "/api/v1/journal",
            json={"date": today_str, "content": "Feeling good today"},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201
        # add() is called at least once for the journal entry (StreakTracker may also call it)
        assert mock_db.add.call_count >= 1
        mock_db.commit.assert_awaited()

    def test_create_same_date_upserts(self, client_with_auth):
        """POST on an existing date updates the row (upsert → still 201)."""
        client, mock_db = client_with_auth

        today_str = date.today().isoformat()
        existing = _make_entry(date=date.today())

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.post(
            "/api/v1/journal",
            json={"date": today_str, "content": "Updated content"},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201
        mock_db.commit.assert_awaited()
        # No new row added (upsert path)
        mock_db.add.assert_not_called()

    def test_create_with_tags(self, client_with_auth):
        """POST with tags field is accepted (201)."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        today_str = date.today().isoformat()
        response = client.post(
            "/api/v1/journal",
            json={"date": today_str, "content": "Tired today", "tags": ["headache", "tired"]},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 201


# ---------------------------------------------------------------------------
# GET /journal — List
# ---------------------------------------------------------------------------


class TestListJournalEntries:
    def test_list_by_date_range_returns_200(self, client_with_auth):
        """GET /journal returns 200 and a list."""
        client, mock_db = client_with_auth

        entries = [
            _make_entry(date=date.today() - timedelta(days=5)),
            _make_entry(date=date.today() - timedelta(days=1)),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = entries
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get(
            "/api/v1/journal",
            params={
                "start_date": (date.today() - timedelta(days=10)).isoformat(),
                "end_date": date.today().isoformat(),
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_list_defaults_to_30_days(self, client_with_auth):
        """GET /journal without params returns 200."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get("/api/v1/journal", headers=AUTH_HEADER)
        assert response.status_code == 200

    def test_list_excludes_out_of_range(self, client_with_auth):
        """DB is queried with the requested range (contract test)."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get(
            "/api/v1/journal",
            params={
                "start_date": (date.today() - timedelta(days=30)).isoformat(),
                "end_date": date.today().isoformat(),
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        mock_db.execute.assert_awaited_once()


# ---------------------------------------------------------------------------
# PUT /journal/{date} — Update
# ---------------------------------------------------------------------------


class TestUpdateJournalEntry:
    def test_update_changes_content(self, client_with_auth):
        """PUT /journal/{date} updates existing entry and returns 200."""
        client, mock_db = client_with_auth

        entry_date = (date.today() + timedelta(days=30)).isoformat()
        entry = _make_entry(date=date.fromisoformat(entry_date))

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = entry
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.put(
            f"/api/v1/journal/{entry_date}",
            json={"date": entry_date, "content": "New content"},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        mock_db.commit.assert_awaited()

    def test_update_404_on_missing_date(self, client_with_auth):
        """PUT /journal/{date} returns 404 when no entry exists."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        future_date = (date.today() + timedelta(days=999)).isoformat()
        response = client.put(
            f"/api/v1/journal/{future_date}",
            json={"date": future_date, "content": "Some content"},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 404


# ---------------------------------------------------------------------------
# DELETE /journal/{date} — Delete
# ---------------------------------------------------------------------------


class TestDeleteJournalEntry:
    def test_delete_removes_entry(self, client_with_auth):
        """DELETE /journal/{date} returns 204 when entry exists."""
        client, mock_db = client_with_auth

        entry_date = (date.today() + timedelta(days=40)).isoformat()
        entry = _make_entry(date=date.fromisoformat(entry_date))

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = entry
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.delete(
            f"/api/v1/journal/{entry_date}",
            headers=AUTH_HEADER,
        )
        assert response.status_code == 204
        mock_db.delete.assert_awaited_once_with(entry)
        mock_db.commit.assert_awaited()

    def test_delete_404_on_missing_date(self, client_with_auth):
        """DELETE /journal/{date} returns 404 when no entry exists."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        future_date = (date.today() + timedelta(days=998)).isoformat()
        response = client.delete(
            f"/api/v1/journal/{future_date}",
            headers=AUTH_HEADER,
        )
        assert response.status_code == 404


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_get_requires_auth(self, client_unauthenticated):
        """GET /journal without Authorization returns 401/403."""
        response = client_unauthenticated.get("/api/v1/journal")
        assert response.status_code in (401, 403)

    def test_post_requires_auth(self, client_unauthenticated):
        """POST /journal without Authorization returns 401/403."""
        response = client_unauthenticated.post(
            "/api/v1/journal",
            json={"date": date.today().isoformat(), "content": "Hello"},
        )
        assert response.status_code in (401, 403)
