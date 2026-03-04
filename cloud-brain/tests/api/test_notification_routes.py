"""
Tests for notification routes:
  GET  /api/v1/notifications
  GET  /api/v1/notifications/unread-count
  PATCH /api/v1/notifications/{id}
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.models.notification_log import NotificationLog, NotificationType

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

USER_ID = "user-notif-001"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


def _make_notification(
    idx: int = 0,
    read: bool = False,
    days_ago: int = 0,
    notif_type: str = NotificationType.INSIGHT.value,
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
        created_at=now,
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


# ---------------------------------------------------------------------------
# GET /notifications — ordering and grouping
# ---------------------------------------------------------------------------


class TestListNotifications:
    def test_returns_notifications_ordered_newest_first(self, client_with_overrides):
        client, mock_db = client_with_overrides

        older = _make_notification(idx=1, days_ago=1)
        newer = _make_notification(idx=2, days_ago=0)

        # Mock count query then row query
        count_result = MagicMock()
        count_result.scalar_one_or_none.return_value = 2

        rows_result = MagicMock()
        rows_result.scalars.return_value.all.return_value = [newer, older]

        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = client.get("/api/v1/notifications", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()

        # Flatten groups to get ordered notification IDs.
        ids = [n["id"] for g in data["groups"] for n in g["notifications"]]
        assert ids[0] == newer.id, "Newer notification should come first"

    def test_groups_notifications_by_day(self, client_with_overrides):
        client, mock_db = client_with_overrides

        today_notif = _make_notification(idx=1, days_ago=0)
        yesterday_notif = _make_notification(idx=2, days_ago=1)

        count_result = MagicMock()
        count_result.scalar_one_or_none.return_value = 2

        rows_result = MagicMock()
        rows_result.scalars.return_value.all.return_value = [today_notif, yesterday_notif]

        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = client.get("/api/v1/notifications", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()

        dates = [g["date"] for g in data["groups"]]
        assert len(dates) == 2, "Should have two day groups"
        # Groups should be ordered newest date first.
        assert dates[0] > dates[1]

    def test_returns_empty_when_no_notifications(self, client_with_overrides):
        client, mock_db = client_with_overrides

        count_result = MagicMock()
        count_result.scalar_one_or_none.return_value = 0

        rows_result = MagicMock()
        rows_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = client.get("/api/v1/notifications", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()
        assert data["groups"] == []
        assert data["total"] == 0

    def test_pagination_metadata_present(self, client_with_overrides):
        client, mock_db = client_with_overrides

        count_result = MagicMock()
        count_result.scalar_one_or_none.return_value = 5

        rows_result = MagicMock()
        rows_result.scalars.return_value.all.return_value = [_make_notification(i) for i in range(2)]

        mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])

        resp = client.get("/api/v1/notifications?limit=2&offset=0", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 5
        assert data["limit"] == 2
        assert data["offset"] == 0


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
# GET /notifications/unread-count
# ---------------------------------------------------------------------------


class TestUnreadCount:
    def test_returns_correct_unread_count(self, client_with_overrides):
        client, mock_db = client_with_overrides

        result = MagicMock()
        result.scalar_one_or_none.return_value = 3
        mock_db.execute = AsyncMock(return_value=result)

        resp = client.get("/api/v1/notifications/unread-count", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        data = resp.json()
        assert data["unread_count"] == 3

    def test_returns_zero_when_all_read(self, client_with_overrides):
        client, mock_db = client_with_overrides

        result = MagicMock()
        result.scalar_one_or_none.return_value = 0
        mock_db.execute = AsyncMock(return_value=result)

        resp = client.get("/api/v1/notifications/unread-count", headers=AUTH_HEADERS)
        assert resp.status_code == 200
        assert resp.json()["unread_count"] == 0


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_unauthenticated_list_returns_401(self):
        """No auth header → 401 Unauthorized."""
        # Remove overrides so real auth dep fires.
        app.dependency_overrides.clear()
        with TestClient(app, raise_server_exceptions=False) as c:
            resp = c.get("/api/v1/notifications")
        assert resp.status_code == 401

    def test_unauthenticated_unread_count_returns_401(self):
        app.dependency_overrides.clear()
        with TestClient(app, raise_server_exceptions=False) as c:
            resp = c.get("/api/v1/notifications/unread-count")
        assert resp.status_code == 401

    def test_unauthenticated_mark_read_returns_401(self):
        app.dependency_overrides.clear()
        with TestClient(app, raise_server_exceptions=False) as c:
            resp = c.patch("/api/v1/notifications/some-id")
        assert resp.status_code == 401
