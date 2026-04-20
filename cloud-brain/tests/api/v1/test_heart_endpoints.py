"""Tests for the heart API — GET /api/v1/heart/all-data, /summary, /trend."""

from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "test-heart-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


@pytest.fixture
def client_with_auth():
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


def _make_scalar_result(value) -> MagicMock:
    r = MagicMock()
    r.scalar.return_value = value
    return r


def _make_scalars_result(items: list) -> MagicMock:
    r = MagicMock()
    r.scalars.return_value.first.return_value = items[0] if items else None
    r.scalars.return_value.all.return_value = items
    return r


def _make_fetchall_result(rows: list) -> MagicMock:
    r = MagicMock()
    r.fetchall.return_value = rows
    return r


class TestHeartAllData:

    def test_all_data_7d_full_metrics(self, client_with_auth):
        """Full-data day has all 8 heart metric rows populated."""
        client, _, mock_db = client_with_auth
        today = date(2026, 4, 20)
        _mock_db_with_rows(mock_db, [
            _make_summary_row(today, "resting_heart_rate", 62.0),
            _make_summary_row(today, "hrv_ms", 58.0),
            _make_summary_row(today, "heart_rate_avg", 78.0),
            _make_summary_row(today, "respiratory_rate", 14.0),
            _make_summary_row(today, "vo2_max", 48.0),
            _make_summary_row(today, "spo2", 97.0),
            _make_summary_row(today, "blood_pressure_systolic", 118.0),
            _make_summary_row(today, "blood_pressure_diastolic", 76.0),
        ])
        with patch("app.api.v1.heart_routes.get_user_local_date", new_callable=AsyncMock, return_value=today):
            resp = client.get("/api/v1/heart/all-data?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        days = resp.json()["days"]
        assert len(days) == 1
        assert days[0]["date"] == "2026-04-20"
        assert days[0]["is_today"] is True
        v = days[0]["values"]
        assert v["resting_hr"] == 62.0
        assert v["hrv"] == 58.0
        assert v["avg_hr"] == 78.0
        assert v["respiratory_rate"] == 14.0
        assert v["vo2_max"] == 48.0
        assert v["spo2"] == 97.0
        assert v["bp_systolic"] == 118.0
        assert v["bp_diastolic"] == 76.0

    @pytest.mark.parametrize("range_val", ["30d", "3m", "6m", "1y"])
    def test_all_data_extended_ranges_accepted(self, client_with_auth, range_val):
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [])
        with patch("app.api.v1.heart_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get(f"/api/v1/heart/all-data?range={range_val}", headers=AUTH_HEADER)
        assert resp.status_code == 200

    def test_all_data_invalid_range_rejected(self, client_with_auth):
        client, _, _ = client_with_auth
        resp = client.get("/api/v1/heart/all-data?range=2y", headers=AUTH_HEADER)
        assert resp.status_code == 422

    def test_all_data_partial_metrics_null_fill(self, client_with_auth):
        """Day with only resting_hr and hrv; all other values are null."""
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [
            _make_summary_row(date(2026, 4, 19), "resting_heart_rate", 60.0),
            _make_summary_row(date(2026, 4, 19), "hrv_ms", 55.0),
        ])
        with patch("app.api.v1.heart_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get("/api/v1/heart/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200
        v = resp.json()["days"][0]["values"]
        assert v["resting_hr"] == 60.0
        assert v["hrv"] == 55.0
        assert v["avg_hr"] is None
        assert v["respiratory_rate"] is None
        assert v["vo2_max"] is None
        assert v["spo2"] is None
        assert v["bp_systolic"] is None
        assert v["bp_diastolic"] is None

    def test_all_data_empty(self, client_with_auth):
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [])
        with patch("app.api.v1.heart_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get("/api/v1/heart/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200
        assert resp.json()["days"] == []

    def test_all_data_default_range_is_7d(self, client_with_auth):
        """Omitting range defaults to 7d and returns 200."""
        client, _, mock_db = client_with_auth
        _mock_db_with_rows(mock_db, [])
        with patch("app.api.v1.heart_routes.get_user_local_date", new_callable=AsyncMock, return_value=date(2026, 4, 20)):
            resp = client.get("/api/v1/heart/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200

    def test_all_data_multiple_days_sorted(self, client_with_auth):
        """Days are returned in chronological order."""
        client, _, mock_db = client_with_auth
        today = date(2026, 4, 20)
        _mock_db_with_rows(mock_db, [
            _make_summary_row(date(2026, 4, 18), "resting_heart_rate", 64.0),
            _make_summary_row(date(2026, 4, 19), "resting_heart_rate", 62.0),
            _make_summary_row(today, "resting_heart_rate", 60.0),
        ])
        with patch("app.api.v1.heart_routes.get_user_local_date", new_callable=AsyncMock, return_value=today):
            resp = client.get("/api/v1/heart/all-data?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        days = resp.json()["days"]
        assert len(days) == 3
        assert days[0]["date"] == "2026-04-18"
        assert days[2]["date"] == "2026-04-20"
        assert days[2]["is_today"] is True
        assert days[0]["is_today"] is False
