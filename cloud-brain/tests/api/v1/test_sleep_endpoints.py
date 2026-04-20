"""Tests for the sleep API — GET /api/v1/sleep/all-data.

The sleep route has inline query logic (no service layer), so we control
the DB via mock_db.execute and patch get_user_local_date at the module level.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "test-sleep-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Shared fixture
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
        yield c, mock_auth, mock_db

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def _make_summary_row(metric_date: date, metric_type: str, value: float) -> MagicMock:
    row = MagicMock()
    row.date = metric_date
    row.metric_type = metric_type
    row.value = value
    return row


def _mock_db_with_rows(mock_db: AsyncMock, rows: list) -> None:
    result_mock = MagicMock()
    result_mock.scalars.return_value.all.return_value = rows
    mock_db.execute = AsyncMock(return_value=result_mock)


# ---------------------------------------------------------------------------
# Class: TestSleepAllData
# ---------------------------------------------------------------------------


class TestSleepAllData:

    def test_all_data_7d_full_metrics(self, client_with_auth):
        """Full-data day has all 6 DB metrics populated and heart_rate null."""
        client, _, mock_db = client_with_auth
        today = date(2026, 4, 20)
        _mock_db_with_rows(mock_db, [
            _make_summary_row(today, "sleep_duration", 420.0),
            _make_summary_row(today, "sleep_quality", 4.0),
            _make_summary_row(today, "deep_sleep_minutes", 84.0),
            _make_summary_row(today, "rem_sleep_minutes", 92.0),
            _make_summary_row(today, "light_sleep_minutes", 244.0),
            _make_summary_row(today, "sleep_efficiency", 89.0),
        ])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=today):
            resp = client.get("/api/v1/sleep/all-data?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        days = resp.json()["days"]
        assert len(days) == 1
        assert days[0]["date"] == "2026-04-20"
        assert days[0]["is_today"] is True
        v = days[0]["values"]
        assert v["duration"] == 420.0
        assert v["quality"] == 4.0
        assert v["deep_sleep"] == 84.0
        assert v["rem"] == 92.0
        assert v["light_sleep"] == 244.0
        assert v["heart_rate"] is None
        assert v["efficiency"] == 89.0

    @pytest.mark.parametrize("range_val", ["30d", "3m", "6m", "1y"])
    def test_all_data_extended_ranges_accepted(self, client_with_auth, range_val):
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get(f"/api/v1/sleep/all-data?range={range_val}", headers=AUTH_HEADER)
        assert resp.status_code == 200

    def test_all_data_invalid_range_rejected(self, client_with_auth):
        client, _, _ = client_with_auth
        resp = client.get("/api/v1/sleep/all-data?range=2y", headers=AUTH_HEADER)
        assert resp.status_code == 422

    def test_all_data_partial_metrics_null_fill(self, client_with_auth):
        """Days with only duration + quality have wearable metrics as null."""
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [
            _make_summary_row(date(2026, 4, 19), "sleep_duration", 400.0),
            _make_summary_row(date(2026, 4, 19), "sleep_quality", 3.0),
        ])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get("/api/v1/sleep/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200
        v = resp.json()["days"][0]["values"]
        assert v["duration"] == 400.0
        assert v["quality"] == 3.0
        assert v["deep_sleep"] is None
        assert v["rem"] is None
        assert v["light_sleep"] is None
        assert v["heart_rate"] is None
        assert v["efficiency"] is None

    def test_all_data_empty(self, client_with_auth):
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get("/api/v1/sleep/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200
        assert resp.json()["days"] == []

    def test_all_data_default_range_is_7d(self, client_with_auth):
        """Omitting range defaults to 7d and returns 200."""
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get("/api/v1/sleep/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200

    def test_all_data_multiple_days_sorted(self, client_with_auth):
        """Days are returned in chronological order."""
        client, _, mock_db = client_with_auth
        today = date(2026, 4, 20)
        _mock_db_with_rows(mock_db, [
            _make_summary_row(date(2026, 4, 18), "sleep_duration", 380.0),
            _make_summary_row(date(2026, 4, 19), "sleep_duration", 420.0),
            _make_summary_row(today, "sleep_duration", 444.0),
        ])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=today):
            resp = client.get("/api/v1/sleep/all-data?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        days = resp.json()["days"]
        assert len(days) == 3
        assert days[0]["date"] == "2026-04-18"
        assert days[2]["date"] == "2026-04-20"
        assert days[2]["is_today"] is True
        assert days[0]["is_today"] is False

    def test_all_data_heart_rate_always_null(self, client_with_auth):
        """heart_rate is always null even with a full data day."""
        client, _, mock_db = client_with_auth
        today = date(2026, 4, 20)
        _mock_db_with_rows(mock_db, [
            _make_summary_row(today, "sleep_duration", 420.0),
            _make_summary_row(today, "sleep_quality", 4.0),
            _make_summary_row(today, "deep_sleep_minutes", 84.0),
            _make_summary_row(today, "rem_sleep_minutes", 92.0),
            _make_summary_row(today, "light_sleep_minutes", 244.0),
            _make_summary_row(today, "sleep_efficiency", 89.0),
        ])
        with patch("app.api.v1.sleep_routes.get_user_local_date", new_callable=AsyncMock, return_value=today):
            resp = client.get("/api/v1/sleep/all-data?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        assert resp.json()["days"][0]["values"]["heart_rate"] is None
