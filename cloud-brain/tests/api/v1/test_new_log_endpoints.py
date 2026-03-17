"""Tests for the new typed quick-log endpoints (sleep, run, meal, supplement, symptom, water, wellness, weight, steps).

Uses the same mock-based TestClient pattern as the rest of the test suite.
There is no live database in CI — all DB calls are replaced by AsyncMock so
tests run fast and deterministically.
"""

from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "new-log-test-user-001"
OTHER_USER_ID = "other-user-id-not-authenticated"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


def _make_quick_log(metric_type, value=None, text_value=None, data=None, logged_at=None):
    """Build a minimal mock QuickLog object for testing."""
    log = MagicMock()
    log.metric_type = metric_type
    log.value = value
    log.text_value = text_value
    log.data = data or {}
    log.logged_at = logged_at
    return log


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _refresh_side_effect(obj):
    """Give the object a UUID if it doesn't have one yet (mimics DB refresh)."""
    if not getattr(obj, "id", None):
        obj.id = str(uuid.uuid4())
    if not getattr(obj, "logged_at", None):
        from datetime import datetime, timezone

        obj.logged_at = datetime.now(timezone.utc)


def _make_supplement(supplement_id: str, user_id: str = TEST_USER_ID):
    """Return a SimpleNamespace shaped like a UserSupplement row."""
    return SimpleNamespace(id=supplement_id, user_id=user_id)


# ---------------------------------------------------------------------------
# Shared fixture
# ---------------------------------------------------------------------------


@pytest.fixture
def client():
    """TestClient with no auth overrides — used to test unauthenticated requests."""
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c

    app.dependency_overrides.clear()


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database — no real DB required."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.add_all = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock(side_effect=_refresh_side_effect)

    # Default execute: return empty result (no supplements)
    mock_result = MagicMock()
    mock_result.all.return_value = []
    mock_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=mock_result)

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Sleep endpoint
# ---------------------------------------------------------------------------


class TestSleepLog:
    def test_sleep_log_valid(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/sleep",
            json={
                "bedtime": "2026-03-16T22:30:00Z",
                "wake_time": "2026-03-17T06:30:00Z",
                "duration_minutes": 480,
                "source": "manual",
                "logged_at": "2026-03-17T06:30:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["type"] == "sleep"
        assert "id" in body
        assert "logged_at" in body

    def test_sleep_log_wake_before_bedtime_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/sleep",
            json={
                "bedtime": "2026-03-17T06:30:00Z",
                "wake_time": "2026-03-16T22:30:00Z",
                "duration_minutes": 480,
                "source": "manual",
                "logged_at": "2026-03-17T06:30:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_sleep_log_invalid_quality_rating_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/sleep",
            json={
                "bedtime": "2026-03-16T22:30:00Z",
                "wake_time": "2026-03-17T06:30:00Z",
                "duration_minutes": 480,
                "quality_rating": 6,
                "source": "manual",
                "logged_at": "2026-03-17T06:30:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Run endpoint
# ---------------------------------------------------------------------------


class TestRunLog:
    def test_run_log_valid(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/run",
            json={
                "activity_type": "run",
                "distance_km": 5.2,
                "duration_seconds": 1560,
                "source": "manual",
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        assert resp.json()["type"] == "run"

    def test_run_log_invalid_distance_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/run",
            json={
                "activity_type": "run",
                "distance_km": 0.0,
                "duration_seconds": 1560,
                "source": "manual",
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_user_id_from_body_is_ignored(self, client_with_auth):
        """Passing user_id in the body must never override the JWT user."""
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/run",
            json={
                "activity_type": "run",
                "distance_km": 5.0,
                "duration_seconds": 1500,
                "user_id": "some-other-user",
                "source": "manual",
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        assert resp.json().get("user_id") != "some-other-user"


# ---------------------------------------------------------------------------
# Meal endpoint
# ---------------------------------------------------------------------------


class TestMealLog:
    def test_meal_log_full_mode_requires_description(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/meal",
            json={
                "meal_type": "lunch",
                "quick_mode": False,
                "logged_at": "2026-03-17T12:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_meal_log_quick_mode_without_description_succeeds(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/meal",
            json={
                "meal_type": "lunch",
                "quick_mode": True,
                "calories_kcal": 600,
                "logged_at": "2026-03-17T12:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Supplement endpoint
# ---------------------------------------------------------------------------


class TestSupplementLog:
    def test_supplement_empty_taken_ids_rejected(self, client_with_auth):
        """An empty taken_supplement_ids list must be rejected with 422."""
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/supplements",
            json={
                "taken_supplement_ids": [],
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422
        assert "taken_supplement_ids" in resp.json().get("detail", "").lower()

    def test_supplement_log_rejects_foreign_supplement_ids(self, client_with_auth):
        """Supplement IDs that don't belong to this user are rejected."""
        client, mock_db = client_with_auth

        # DB returns empty set — no valid IDs found for this user
        mock_result = MagicMock()
        mock_result.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        foreign_id = str(uuid.uuid4())
        resp = client.post(
            "/api/v1/quick-log/supplements",
            json={
                "taken_supplement_ids": [foreign_id],
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Symptom endpoint
# ---------------------------------------------------------------------------


class TestSymptomLog:
    def test_symptom_log_invalid_severity_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/symptom",
            json={
                "body_areas": ["head"],
                "severity": "extreme",
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_symptom_log_empty_body_areas_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/symptom",
            json={
                "body_areas": [],
                "severity": "mild",
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_symptom_log_valid(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/symptom",
            json={
                "body_areas": ["head"],
                "severity": "mild",
                "logged_at": "2026-03-17T08:00:00Z",
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        assert resp.json()["type"] == "symptom"


# ---------------------------------------------------------------------------
# Supplement list management endpoints
# ---------------------------------------------------------------------------


class TestSupplementList:
    def test_get_supplements_list_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/user/supplements-list", headers=AUTH_HEADER)
        assert resp.status_code == 200
        assert "supplements" in resp.json()

    def test_update_supplements_list_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.post(
            "/api/v1/quick-log/user/supplements-list",
            json={
                "supplements": [
                    {"name": "Vitamin D", "dose": "2000IU", "timing": "morning"},
                    {"name": "Magnesium"},
                ]
            },
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["supplements"]) == 2

    def test_update_supplements_list_rejects_over_50(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/user/supplements-list",
            json={"supplements": [{"name": f"Supp {i}"} for i in range(51)]},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_update_supplements_list_rejects_empty_name(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/user/supplements-list",
            json={"supplements": [{"name": ""}]},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Water endpoint
# ---------------------------------------------------------------------------


class TestLogWater:
    def test_valid_water_log_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/water",
            json={"amount_ml": 250.0},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["type"] == "water"
        assert "id" in body
        assert "logged_at" in body

    def test_amount_ml_too_low_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/water",
            json={"amount_ml": 0.5},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_amount_ml_too_high_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/water",
            json={"amount_ml": 5001.0},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_user_id_from_jwt_not_body(self, client_with_auth):
        """Passing user_id in body must be silently ignored."""
        client, mock_db = client_with_auth
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/water",
            json={"amount_ml": 250.0, "user_id": "evil-other-user"},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200

    def test_vessel_key_too_long_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/water",
            json={"amount_ml": 250.0, "vessel_key": "x" * 101},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Wellness endpoint
# ---------------------------------------------------------------------------


class TestLogWellness:
    def test_mood_only_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_db.add_all = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/wellness",
            json={"mood": 7.5},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["type"] == "wellness"
        assert isinstance(body["ids"], list)
        assert len(body["ids"]) == 1

    def test_all_none_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/wellness",
            json={},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422
        assert "at least one" in resp.json()["detail"].lower()

    def test_mood_out_of_range_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/wellness",
            json={"mood": 11.0},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_notes_too_long_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/wellness",
            json={"mood": 7.0, "notes": "x" * 501},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_mood_and_energy_returns_two_ids(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_db.add_all = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/wellness",
            json={"mood": 7.5, "energy": 6.0},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["ids"]) == 2


# ---------------------------------------------------------------------------
# Weight endpoint
# ---------------------------------------------------------------------------


class TestLogWeight:
    def test_valid_weight_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/weight",
            json={"value_kg": 75.5},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        assert resp.json()["type"] == "weight"

    def test_too_light_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/weight",
            json={"value_kg": 19.9},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_too_heavy_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/weight",
            json={"value_kg": 500.1},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Steps endpoint
# ---------------------------------------------------------------------------


class TestLogSteps:
    def test_valid_steps_add_mode_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/steps",
            json={"steps": 5000, "mode": "add"},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200
        assert resp.json()["type"] == "steps"

    def test_valid_steps_override_mode_returns_200(self, client_with_auth):
        client, mock_db = client_with_auth
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        resp = client.post(
            "/api/v1/quick-log/steps",
            json={"steps": 10000, "mode": "override"},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200

    def test_steps_too_high_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/steps",
            json={"steps": 100_001},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_negative_steps_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/steps",
            json={"steps": -1},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_invalid_mode_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/steps",
            json={"steps": 5000, "mode": "replace"},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_invalid_source_returns_422(self, client_with_auth):
        client, _ = client_with_auth
        resp = client.post(
            "/api/v1/quick-log/steps",
            json={"steps": 5000, "source": "fitbit"},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# GET /quick-log/my-metric-types
# ---------------------------------------------------------------------------


class TestGetMyMetricTypes:
    def test_returns_distinct_types_for_user(self, client_with_auth):
        """Returns only the types this user has logged, not another user's."""
        client, mock_db = client_with_auth
        mock_result = MagicMock()
        # Simulate DB returning two distinct rows: ("water",), ("mood",)
        mock_result.all.return_value = [("water",), ("mood",)]
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/my-metric-types", headers=AUTH_HEADER)
        assert resp.status_code == 200
        body = resp.json()
        assert "metric_types" in body
        assert set(body["metric_types"]) == {"water", "mood"}

    def test_returns_empty_list_for_new_user(self, client_with_auth):
        """New user with no logs gets an empty list, not an error."""
        client, mock_db = client_with_auth
        mock_result = MagicMock()
        mock_result.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/my-metric-types", headers=AUTH_HEADER)
        assert resp.status_code == 200
        assert resp.json()["metric_types"] == []

    def test_requires_auth(self, client):
        """Unauthenticated request returns 401 or 403."""
        resp = client.get("/api/v1/quick-log/my-metric-types")
        assert resp.status_code in (401, 403)


# ---------------------------------------------------------------------------
# GET /quick-log/summary/today
# ---------------------------------------------------------------------------


class TestGetSummaryToday:
    def test_empty_summary_for_new_user(self, client_with_auth):
        """User with no logs today gets empty logged_types and latest_values."""
        client, mock_db = client_with_auth
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        assert resp.status_code == 200
        body = resp.json()
        assert body["logged_types"] == []
        assert body["latest_values"] == {}

    def test_water_is_summed(self, client_with_auth):
        """Multiple water entries are summed into a single total."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("water", value=250.0, logged_at=now),
            _make_quick_log("water", value=500.0, logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        assert "water" in body["logged_types"]
        assert body["latest_values"]["water"] == 750.0

    def test_mood_returns_latest_not_sum(self, client_with_auth):
        """Mood returns the most recently logged value, not a sum."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone, timedelta

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("mood", value=5.0, logged_at=now - timedelta(hours=2)),
            _make_quick_log("mood", value=8.0, logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        assert body["latest_values"]["mood"] == 8.0

    def test_steps_add_mode_sums_all(self, client_with_auth):
        """Steps in 'add' mode sums all entries."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("steps", value=3000.0, data={"mode": "add"}, logged_at=now),
            _make_quick_log("steps", value=7000.0, data={"mode": "add"}, logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        assert body["latest_values"]["steps"] == 10000.0

    def test_steps_override_acts_as_reset_point(self, client_with_auth):
        """Override entry resets the count; add entries after it are summed on top."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone, timedelta

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("steps", value=3000.0, data={"mode": "add"}, logged_at=now - timedelta(hours=4)),
            _make_quick_log("steps", value=10000.0, data={"mode": "override"}, logged_at=now - timedelta(hours=2)),
            _make_quick_log("steps", value=2000.0, data={"mode": "add"}, logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        # override(10000) + add(2000) after override = 12000; early add(3000) ignored
        assert body["latest_values"]["steps"] == 12000.0

    def test_meal_calories_summed(self, client_with_auth):
        """Meal calories are summed across all meal entries today."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("meal", value=400.0, logged_at=now),
            _make_quick_log("meal", value=600.0, logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        assert body["latest_values"]["meal"] == 1000.0

    def test_symptom_returns_severity_string(self, client_with_auth):
        """Symptom returns the latest severity string under 'symptom_severity' key."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("symptom", text_value="moderate", logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        assert body["latest_values"]["symptom_severity"] == "moderate"

    def test_invalid_tz_offset_returns_422(self, client_with_auth):
        """tz_offset outside valid range returns 422."""
        client, _ = client_with_auth
        resp = client.get(
            "/api/v1/quick-log/summary/today",
            params={"tz_offset": 900},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 422

    def test_run_logged_at_included_in_latest_values(self, client_with_auth):
        """Run entries include 'run_logged_at' in latest_values as ISO string."""
        client, mock_db = client_with_auth
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
        logs = [
            _make_quick_log("run", value=5.2, logged_at=now),
        ]
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = logs
        mock_db.execute = AsyncMock(return_value=mock_result)

        resp = client.get("/api/v1/quick-log/summary/today", headers=AUTH_HEADER)
        body = resp.json()
        assert "run" in body["logged_types"]
        assert "run_logged_at" in body["latest_values"]
        assert isinstance(body["latest_values"]["run_logged_at"], str)
        assert len(body["latest_values"]["run_logged_at"]) > 0
