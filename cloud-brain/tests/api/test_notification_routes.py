"""
Tests for notification routes:
  GET  /api/v1/notifications        — paginated flat list
  PATCH /api/v1/notifications/{id}  — mark as read

The API returns:
  GET  → {"notifications": [...], "total": N, "page": N, "page_size": N}
  PATCH → NotificationResponse dict

Note: An unread-count endpoint was planned but not yet implemented.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.models.notification_log import NOTIFICATION_TYPES, NotificationLog

# Use first valid type string as default
_INSIGHT_TYPE = NOTIFICATION_TYPES[0]  # "insight"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

USER_ID = "user-notif-001"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


def _make_notification(
    idx: int = 0,
    read: bool = False,
    days_ago: int = 0,
    notif_type: str = _INSIGHT_TYPE,
) -> NotificationLog:
    """Build a NotificationLog instance without hitting the DB."""
    now = datetime.now(timezone.utc) - timedelta(days=days_ago, minutes=idx)
    n = NotificationLog(
        id=f"notif-{idx:04d}",
        user_id=USER_ID,
        title=f"Notification {idx}",
        body=f"Body {idx}",
        type=notif_type,
        deep_link=f"zuralog://insight/{idx}" if idx % 2 == 0 else None,
        sent_at=now,
        read_at=now + timedelta(minutes=5) if read else None,
    )
    return n


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_db():
    return AsyncMock()


@pytest.fixture
def client_with_overrides(mock_db):
    """TestClient with auth and DB mocked out."""
    app.dependency_overrides[get_authenticated_user_id] = lambda: USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


def _count_result(n: int) -> MagicMock:
    """Return a mock result whose scalar_one() returns n."""
    result = MagicMock()
    result.scalar_one.return_value = n
    return result


def _rows_result(rows: list) -> MagicMock:
    """Return a mock result whose scalars().all() returns rows."""
    result = MagicMock()
    result.scalars.return_value.all.return_value = rows
    return result


# ---------------------------------------------------------------------------
# GET /notifications
# ---------------------------------------------------------------------------


class TestListNotifications:
    def test_returns_200_with_correct_shape(self, client_with_overrides):
        """GET /notifications returns the expected response envelope."""
        client, mock_db = client_with_overrides

        newer = _make_notification(idx=2, days_ago=0)

        mock_db.execute = AsyncMock(
            side_effect=[
                _count_result(1),
                _rows_result([newer]),
            ]
        )

        resp = client.get("/api/v1/notifications", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()
        assert "notifications" in data
        assert "total" in data
        assert "page" in data
        assert "page_size" in data

    def test_returns_notifications_ordered_newest_first(self, client_with_overrides):
        """Notifications are returned in the order given by the DB query."""
        client, mock_db = client_with_overrides

        older = _make_notification(idx=1, days_ago=1)
        newer = _make_notification(idx=2, days_ago=0)

        mock_db.execute = AsyncMock(
            side_effect=[
                _count_result(2),
                _rows_result([newer, older]),
            ]
        )

        resp = client.get("/api/v1/notifications", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()

        ids = [n["id"] for n in data["notifications"]]
        assert ids[0] == newer.id, "Newer notification should come first"

    def test_returns_empty_when_no_notifications(self, client_with_overrides):
        """Empty DB → empty notifications list, total=0."""
        client, mock_db = client_with_overrides

        mock_db.execute = AsyncMock(
            side_effect=[
                _count_result(0),
                _rows_result([]),
            ]
        )

        resp = client.get("/api/v1/notifications", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()
        assert data["notifications"] == []
        assert data["total"] == 0

    def test_pagination_metadata_present(self, client_with_overrides):
        """Response includes total, page, and page_size."""
        client, mock_db = client_with_overrides

        mock_db.execute = AsyncMock(
            side_effect=[
                _count_result(5),
                _rows_result([_make_notification(i) for i in range(2)]),
            ]
        )

        resp = client.get("/api/v1/notifications?page=1&page_size=2", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 5
        assert data["page"] == 1
        assert data["page_size"] == 2


# ---------------------------------------------------------------------------
# PATCH /notifications/{id} — mark as read
# ---------------------------------------------------------------------------


class TestMarkNotificationRead:
    def test_marks_unread_notification_as_read(self, client_with_overrides):
        client, mock_db = client_with_overrides

        notif = _make_notification(idx=1, read=False)

        result = MagicMock()
        result.scalar_one_or_none.return_value = notif
        mock_db.execute = AsyncMock(return_value=result)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.patch(f"/api/v1/notifications/{notif.id}", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        mock_db.commit.assert_awaited_once()

    def test_returns_404_for_unknown_notification(self, client_with_overrides):
        client, mock_db = client_with_overrides

        result = MagicMock()
        result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=result)

        resp = client.patch("/api/v1/notifications/nonexistent-id", headers=AUTH_HEADERS)
        assert resp.status_code == 404

    def test_already_read_notification_not_committed_again(self, client_with_overrides):
        client, mock_db = client_with_overrides

        notif = _make_notification(idx=1, read=True)

        result = MagicMock()
        result.scalar_one_or_none.return_value = notif
        mock_db.execute = AsyncMock(return_value=result)
        mock_db.commit = AsyncMock()

        resp = client.patch(f"/api/v1/notifications/{notif.id}", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        # Already read — no commit needed.
        mock_db.commit.assert_not_awaited()


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_unauthenticated_list_returns_401(self):
        """No auth header → 401 Unauthorized."""
        app.dependency_overrides.clear()
        with TestClient(app, raise_server_exceptions=False) as c:
            resp = c.get("/api/v1/notifications")
        assert resp.status_code == 401

    def test_unauthenticated_mark_read_returns_401(self):
        app.dependency_overrides.clear()
        with TestClient(app, raise_server_exceptions=False) as c:
            resp = c.patch("/api/v1/notifications/some-id")
        assert resp.status_code == 401
