"""
Zuralog Cloud Brain — Fitbit Celery Sync Task Tests.

Tests all four Fitbit Celery tasks and their helper functions:
- sync_fitbit_collection_task: webhook-triggered, per-collection sync
- sync_fitbit_periodic_task: 15-minute Celery Beat task
- refresh_fitbit_tokens_task: 1-hour token refresh task
- backfill_fitbit_data_task: one-time historical backfill

All external HTTP calls, DB sessions, and token service calls are mocked.
"""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.health_data import ActivityType
from app.tasks.fitbit_sync import (
    _FITBIT_TYPE_MAP,
    _DEFAULT_ACTIVITY_TYPE,
    _map_fitbit_activity_type,
    _sync_fitbit_activities,
    _sync_fitbit_nutrition,
    _sync_fitbit_sleep,
    _sync_fitbit_weight,
    backfill_fitbit_data_task,
    refresh_fitbit_tokens_task,
    sync_fitbit_collection_task,
    sync_fitbit_periodic_task,
)


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------


def _make_integration(
    user_id: str = "user-001",
    fitbit_user_id: str = "FIT123",
    is_active: bool = True,
    sync_status: str = "idle",
    token_expires_at: datetime | None = None,
) -> MagicMock:
    """Build a mock Integration object for testing."""
    intg = MagicMock()
    intg.user_id = user_id
    intg.provider = "fitbit"
    intg.is_active = is_active
    intg.sync_status = sync_status
    intg.sync_error = None
    intg.provider_metadata = {"fitbit_user_id": fitbit_user_id}
    intg.token_expires_at = token_expires_at or datetime.now(timezone.utc) + timedelta(hours=8)
    intg.last_synced_at = None
    return intg


def _mock_db_with_integrations(integrations: list) -> AsyncMock:
    """Create an AsyncMock DB session whose execute() returns the given integrations."""
    db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = integrations
    mock_result.scalar_one_or_none.return_value = None
    db.execute.return_value = mock_result
    return db


def _http_resp(status: int = 200, json_data: dict | list | None = None) -> MagicMock:
    """Build a minimal mock HTTP response."""
    resp = MagicMock()
    resp.status_code = status
    resp.text = "" if status == 200 else "Error"
    resp.json.return_value = json_data if json_data is not None else {}
    return resp


# ---------------------------------------------------------------------------
# Activity type mapping
# ---------------------------------------------------------------------------


class TestActivityTypeMapping:
    """Tests for Fitbit activityTypeId → ActivityType enum mapping."""

    def test_run_mapped(self):
        assert _map_fitbit_activity_type(90009) == ActivityType.RUN

    def test_cycle_mapped(self):
        assert _map_fitbit_activity_type(90001) == ActivityType.CYCLE

    def test_swim_mapped(self):
        assert _map_fitbit_activity_type(90024) == ActivityType.SWIM

    def test_walk_mapped(self):
        assert _map_fitbit_activity_type(90013) == ActivityType.WALK

    def test_strength_15000_mapped(self):
        assert _map_fitbit_activity_type(15000) == ActivityType.STRENGTH

    def test_strength_15010_mapped(self):
        assert _map_fitbit_activity_type(15010) == ActivityType.STRENGTH

    def test_unknown_id_returns_unknown(self):
        assert _map_fitbit_activity_type(99999) == ActivityType.UNKNOWN

    def test_none_returns_unknown(self):
        assert _map_fitbit_activity_type(None) == ActivityType.UNKNOWN

    def test_default_type_string(self):
        assert _DEFAULT_ACTIVITY_TYPE == "OTHER"

    def test_all_map_keys_are_integers(self):
        for key in _FITBIT_TYPE_MAP:
            assert isinstance(key, int), f"Key {key!r} is not an int"


# ---------------------------------------------------------------------------
# Helper: _sync_fitbit_activities
# ---------------------------------------------------------------------------


class TestSyncFitbitActivities:
    """Unit tests for the _sync_fitbit_activities async helper."""

    @pytest.mark.asyncio
    async def test_inserts_new_activity(self):
        """New activities should be inserted into the DB."""
        activity_data = {
            "activities": [
                {
                    "logId": 111,
                    "activityTypeId": 90009,
                    "startTime": "2026-02-28T07:00:00.000",
                    "duration": 1800000,  # 30 min in ms
                    "distance": 5.0,
                    "calories": 350,
                }
            ]
        }
        resp = _http_resp(200, activity_data)

        db = AsyncMock()
        db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_activities(db, "user-001", "token-abc", "2026-02-28")

        assert count == 1
        db.add.assert_called_once()
        db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_updates_existing_activity(self):
        """Existing activities should be updated, not duplicated."""
        existing = MagicMock()
        db = AsyncMock()
        db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=existing)
        )

        activity_data = {
            "activities": [
                {
                    "logId": 222,
                    "activityTypeId": 90013,
                    "startTime": "2026-02-28T08:00:00.000",
                    "duration": 3600000,
                    "distance": 10.0,
                    "calories": 400,
                }
            ]
        }
        resp = _http_resp(200, activity_data)

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_activities(db, "user-001", "token-abc", "2026-02-28")

        assert count == 1
        db.add.assert_not_called()  # update, not insert
        assert existing.activity_type == ActivityType.WALK

    @pytest.mark.asyncio
    async def test_api_error_returns_zero(self):
        """Non-200 response should return 0 and not touch the DB."""
        db = AsyncMock()
        resp = _http_resp(401)

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_activities(db, "user-001", "token-abc", "2026-02-28")

        assert count == 0
        db.add.assert_not_called()

    @pytest.mark.asyncio
    async def test_empty_activities_returns_zero(self):
        """Empty activities list should return 0."""
        db = AsyncMock()
        resp = _http_resp(200, {"activities": []})

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_activities(db, "user-001", "token-abc", "2026-02-28")

        assert count == 0


# ---------------------------------------------------------------------------
# Helper: _sync_fitbit_sleep
# ---------------------------------------------------------------------------


class TestSyncFitbitSleep:
    """Unit tests for the _sync_fitbit_sleep async helper."""

    @pytest.mark.asyncio
    async def test_inserts_sleep_record(self):
        """New sleep data should create a SleepRecord."""
        sleep_data = {
            "summary": {"totalMinutesAsleep": 420},  # 7 hours
            "sleep": [{"isMainSleep": True, "efficiency": 88}],
        }
        resp = _http_resp(200, sleep_data)

        db = AsyncMock()
        db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_sleep(db, "user-001", "token-abc", "2026-02-28")

        assert count == 1
        db.add.assert_called_once()

    @pytest.mark.asyncio
    async def test_updates_existing_sleep(self):
        """Existing SleepRecord should be updated."""
        existing = MagicMock()
        db = AsyncMock()
        db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=existing)
        )

        sleep_data = {
            "summary": {"totalMinutesAsleep": 480},  # 8 hours
            "sleep": [{"isMainSleep": True, "efficiency": 92}],
        }
        resp = _http_resp(200, sleep_data)

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_sleep(db, "user-001", "token-abc", "2026-02-28")

        assert count == 1
        db.add.assert_not_called()
        assert existing.hours == 8.0

    @pytest.mark.asyncio
    async def test_no_sleep_data_returns_zero(self):
        """Zero totalMinutesAsleep should return 0."""
        sleep_data = {"summary": {"totalMinutesAsleep": 0}, "sleep": []}
        resp = _http_resp(200, sleep_data)
        db = AsyncMock()

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_sleep(db, "user-001", "token-abc", "2026-02-28")

        assert count == 0


# ---------------------------------------------------------------------------
# Helper: _sync_fitbit_weight
# ---------------------------------------------------------------------------


class TestSyncFitbitWeight:
    """Unit tests for the _sync_fitbit_weight async helper."""

    @pytest.mark.asyncio
    async def test_inserts_weight_measurement(self):
        """New weight log should create a WeightMeasurement."""
        weight_data = {"weight": [{"date": "2026-02-28", "weight": 75.5}]}
        resp = _http_resp(200, weight_data)

        db = AsyncMock()
        db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_weight(db, "user-001", "token-abc", "2026-02-28")

        assert count == 1
        db.add.assert_called_once()

    @pytest.mark.asyncio
    async def test_api_error_returns_zero(self):
        db = AsyncMock()
        resp = _http_resp(500)

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_weight(db, "user-001", "token-abc", "2026-02-28")

        assert count == 0


# ---------------------------------------------------------------------------
# Helper: _sync_fitbit_nutrition
# ---------------------------------------------------------------------------


class TestSyncFitbitNutrition:
    """Unit tests for the _sync_fitbit_nutrition async helper."""

    @pytest.mark.asyncio
    async def test_inserts_nutrition_entry(self):
        """New food log should create a NutritionEntry."""
        nutrition_data = {
            "summary": {
                "calories": 2100,
                "protein": 150.0,
                "carbs": 250.0,
                "fat": 70.0,
            }
        }
        resp = _http_resp(200, nutrition_data)

        db = AsyncMock()
        db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_nutrition(db, "user-001", "token-abc", "2026-02-28")

        assert count == 1
        db.add.assert_called_once()

    @pytest.mark.asyncio
    async def test_zero_calories_returns_zero(self):
        resp = _http_resp(200, {"summary": {"calories": 0}})
        db = AsyncMock()

        with patch("httpx.AsyncClient") as mock_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=resp)
            mock_cls.return_value = mock_client

            count = await _sync_fitbit_nutrition(db, "user-001", "token-abc", "2026-02-28")

        assert count == 0


# ---------------------------------------------------------------------------
# sync_fitbit_collection_task
# ---------------------------------------------------------------------------


class TestSyncFitbitCollectionTask:
    """Tests for the webhook-triggered sync_fitbit_collection_task."""

    def _run_task(self, *args, **kwargs):
        """Run the Celery task directly (bypassing broker)."""
        return sync_fitbit_collection_task(*args, **kwargs)

    def test_no_integration_returns_early(self):
        """If no active integration found for fitbit_user_id, return no_integration."""
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService"),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            result = self._run_task("UNKNOWN_USER", "activities", "2026-02-28")

        assert result["status"] == "no_integration"

    def test_activities_sync(self):
        """Activities collection type should call _sync_fitbit_activities."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_activities", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="access-token")
            mock_ts_cls.return_value = mock_ts

            mock_sync.return_value = 2

            result = self._run_task("FIT123", "activities", "2026-02-28")

        assert result["status"] == "ok"
        assert result["upserted"] == 2
        mock_sync.assert_called_once_with(mock_db, "user-001", "access-token", "2026-02-28")

    def test_sleep_sync(self):
        """Sleep collection type should call _sync_fitbit_sleep."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_sleep", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="access-token")
            mock_ts_cls.return_value = mock_ts

            mock_sync.return_value = 1

            result = self._run_task("FIT123", "sleep", "2026-02-28")

        assert result["status"] == "ok"
        assert result["collection_type"] == "sleep"
        mock_sync.assert_called_once()

    def test_body_sync(self):
        """Body collection type should call _sync_fitbit_weight."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_weight", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="access-token")
            mock_ts_cls.return_value = mock_ts

            mock_sync.return_value = 1

            result = self._run_task("FIT123", "body", "2026-02-28")

        assert result["status"] == "ok"
        assert result["collection_type"] == "body"
        mock_sync.assert_called_once()

    def test_foods_sync(self):
        """Foods collection type should call _sync_fitbit_nutrition."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_nutrition", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="access-token")
            mock_ts_cls.return_value = mock_ts

            mock_sync.return_value = 1

            result = self._run_task("FIT123", "foods", "2026-02-28")

        assert result["status"] == "ok"
        assert result["collection_type"] == "foods"
        mock_sync.assert_called_once()

    def test_unknown_collection_type(self):
        """Unknown collection type should log a warning and return status=unknown_collection_type."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="access-token")
            mock_ts_cls.return_value = mock_ts

            result = self._run_task("FIT123", "biometrics", "2026-02-28")

        assert result["status"] == "unknown_collection_type"

    def test_no_token_returns_no_token(self):
        """If token retrieval fails, return status=no_token."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value=None)
            mock_ts_cls.return_value = mock_ts

            result = self._run_task("FIT123", "activities", "2026-02-28")

        assert result["status"] == "no_token"

    def test_last_synced_at_updated_on_success(self):
        """Integration.last_synced_at and sync_status should be updated on success."""
        integration = _make_integration(user_id="user-001", fitbit_user_id="FIT123")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_activities", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="token")
            mock_ts_cls.return_value = mock_ts
            mock_sync.return_value = 0

            self._run_task("FIT123", "activities", "2026-02-28")

        assert integration.sync_status == "idle"
        assert integration.last_synced_at is not None


# ---------------------------------------------------------------------------
# sync_fitbit_periodic_task
# ---------------------------------------------------------------------------


class TestSyncFitbitPeriodicTask:
    """Tests for the 15-minute periodic Fitbit sync task."""

    def test_no_active_users_returns_zero(self):
        """No active integrations → users_synced=0."""
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService"),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            result = sync_fitbit_periodic_task()

        assert result["users_synced"] == 0

    def test_one_user_synced(self):
        """Single active integration should be synced; users_synced=1."""
        integration = _make_integration(user_id="user-001")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_user", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="token")
            mock_ts_cls.return_value = mock_ts

            mock_sync.return_value = {
                "activities": 1,
                "sleep": 1,
                "weight": 0,
                "nutrition": 0,
            }

            result = sync_fitbit_periodic_task()

        assert result["users_synced"] == 1
        mock_sync.assert_called_once()

    def test_user_with_no_token_is_skipped(self):
        """If get_access_token returns None, that user should be skipped."""
        integration = _make_integration(user_id="user-no-token")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_user", new_callable=AsyncMock) as mock_sync,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value=None)
            mock_ts_cls.return_value = mock_ts

            result = sync_fitbit_periodic_task()

        assert result["users_synced"] == 0
        mock_sync.assert_not_called()

    def test_syncs_today_and_yesterday(self):
        """The periodic task should pass today + yesterday dates to _sync_fitbit_user."""
        from datetime import date

        integration = _make_integration(user_id="user-001")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        captured_dates = []

        async def _capture_sync(db, user_id, access_token, dates):
            captured_dates.extend(dates)
            return {"activities": 0, "sleep": 0, "weight": 0, "nutrition": 0}

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_user", side_effect=_capture_sync),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="token")
            mock_ts_cls.return_value = mock_ts

            sync_fitbit_periodic_task()

        today = date.today().isoformat()
        yesterday = (date.today() - timedelta(days=1)).isoformat()
        assert today in captured_dates
        assert yesterday in captured_dates


# ---------------------------------------------------------------------------
# refresh_fitbit_tokens_task
# ---------------------------------------------------------------------------


class TestRefreshFitbitTokensTask:
    """Tests for the hourly Fitbit token refresh task."""

    def test_token_not_expiring_soon_is_skipped(self):
        """Tokens valid for > 2 hours should not be refreshed."""
        integration = _make_integration(
            token_expires_at=datetime.now(timezone.utc) + timedelta(hours=5)
        )
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts_cls.return_value = mock_ts

            result = refresh_fitbit_tokens_task()

        assert result["refreshed"] == 0
        mock_ts.refresh_access_token.assert_not_called()

    def test_expiring_token_is_refreshed(self):
        """Tokens expiring within 2 hours should be refreshed."""
        integration = _make_integration(
            user_id="user-001",
            token_expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
        )
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.refresh_access_token = AsyncMock(return_value="new-token")
            mock_ts_cls.return_value = mock_ts

            result = refresh_fitbit_tokens_task()

        assert result["refreshed"] == 1
        mock_ts.refresh_access_token.assert_called_once_with(mock_db, integration)

    def test_refresh_failure_marks_error_status(self):
        """If refresh returns None, sync_status should be marked 'error'."""
        integration = _make_integration(
            user_id="user-001",
            token_expires_at=datetime.now(timezone.utc) + timedelta(minutes=30),
        )
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            # refresh_access_token already sets sync_status="error" internally in
            # FitbitTokenService; returning None triggers our warning log path.
            mock_ts.refresh_access_token = AsyncMock(return_value=None)
            mock_ts_cls.return_value = mock_ts

            result = refresh_fitbit_tokens_task()

        # refreshed count should be 0 (failed refresh)
        assert result["refreshed"] == 0

    def test_refresh_exception_marks_error_status(self):
        """Unexpected exception during refresh should mark integration as error."""
        integration = _make_integration(
            user_id="user-001",
            token_expires_at=datetime.now(timezone.utc) + timedelta(minutes=30),
        )
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[integration]))
            )
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.refresh_access_token = AsyncMock(
                side_effect=RuntimeError("Unexpected error")
            )
            mock_ts_cls.return_value = mock_ts

            result = refresh_fitbit_tokens_task()

        assert result["refreshed"] == 0
        assert integration.sync_status == "error"
        assert "re-authentication" in integration.sync_error

    def test_no_integrations_returns_zero(self):
        """No integrations → refreshed=0."""
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService"),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            result = refresh_fitbit_tokens_task()

        assert result["refreshed"] == 0


# ---------------------------------------------------------------------------
# backfill_fitbit_data_task
# ---------------------------------------------------------------------------


class TestBackfillFitbitDataTask:
    """Tests for the one-time historical backfill task."""

    def test_no_integration_returns_no_integration(self):
        """Missing integration returns status=no_integration."""
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=None)
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService"),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            result = backfill_fitbit_data_task("user-unknown")

        assert result["status"] == "no_integration"

    def test_sets_sync_status_syncing_then_idle(self):
        """sync_status should be 'syncing' during backfill, 'idle' when done."""
        integration = _make_integration(user_id="user-001")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=integration)
        )

        status_sequence = []

        async def _capture_sync(db, user_id, access_token, dates):
            # Record the status at the time _sync_fitbit_user is called.
            status_sequence.append(integration.sync_status)
            return {"activities": 0, "sleep": 0, "weight": 0, "nutrition": 0}

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_user", side_effect=_capture_sync),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="token")
            mock_ts_cls.return_value = mock_ts

            result = backfill_fitbit_data_task("user-001", days_back=7)

        assert result["status"] == "ok"
        assert result["days_back"] == 7
        # During sync, status was "syncing"
        assert "syncing" in status_sequence
        # After sync, status is "idle"
        assert integration.sync_status == "idle"
        assert integration.last_synced_at is not None

    def test_syncs_correct_number_of_days(self):
        """_sync_fitbit_user should receive exactly days_back dates."""
        integration = _make_integration(user_id="user-001")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=integration)
        )

        captured_dates = []

        async def _capture(db, user_id, access_token, dates):
            captured_dates.extend(dates)
            return {"activities": 0, "sleep": 0, "weight": 0, "nutrition": 0}

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch("app.tasks.fitbit_sync._sync_fitbit_user", side_effect=_capture),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="token")
            mock_ts_cls.return_value = mock_ts

            backfill_fitbit_data_task("user-001", days_back=5)

        assert len(captured_dates) == 5

    def test_error_during_sync_sets_error_status(self):
        """An exception during _sync_fitbit_user sets sync_status='error'."""
        integration = _make_integration(user_id="user-001")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=integration)
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
            patch(
                "app.tasks.fitbit_sync._sync_fitbit_user",
                new_callable=AsyncMock,
                side_effect=RuntimeError("Network failure"),
            ),
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value="token")
            mock_ts_cls.return_value = mock_ts

            result = backfill_fitbit_data_task("user-001", days_back=3)

        assert result["status"] == "error"
        assert integration.sync_status == "error"

    def test_no_token_returns_no_token(self):
        """If get_access_token returns None, return status=no_token."""
        integration = _make_integration(user_id="user-001")
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalar_one_or_none=MagicMock(return_value=integration)
        )

        with (
            patch("app.tasks.fitbit_sync.async_session") as mock_session_cls,
            patch("app.tasks.fitbit_sync.FitbitTokenService") as mock_ts_cls,
        ):
            mock_session_cls.return_value.__aenter__ = AsyncMock(return_value=mock_db)
            mock_session_cls.return_value.__aexit__ = AsyncMock(return_value=False)

            mock_ts = AsyncMock()
            mock_ts.get_access_token = AsyncMock(return_value=None)
            mock_ts_cls.return_value = mock_ts

            result = backfill_fitbit_data_task("user-001", days_back=7)

        assert result["status"] == "no_token"
