"""
Zuralog Cloud Brain — Oura Ring Celery Sync Task Tests.

Tests all five Oura Celery tasks and their helper functions:
- sync_oura_webhook_task: webhook-triggered sync for a specific data type
- sync_oura_periodic_task: 15-minute Celery Beat task
- refresh_oura_tokens_task: 4-hour token refresh task
- renew_oura_webhook_subscriptions_task: 24-hour webhook renewal task
- backfill_oura_data_task: one-time historical backfill

All external HTTP calls, DB sessions, and token service calls are mocked.
"""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import httpx

from app.models.health_data import ActivityType
from app.tasks.oura_sync import (
    _OURA_ACTIVITY_TYPE_MAP,
    _DEFAULT_ACTIVITY_TYPE,
    _fetch_oura_collection,
    _upsert_sleep,
    _upsert_workouts,
    backfill_oura_data_task,
    refresh_oura_tokens_task,
    renew_oura_webhook_subscriptions_task,
    sync_oura_periodic_task,
    sync_oura_webhook_task,
)


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------


def _make_integration(
    user_id: str = "user-001",
    oura_user_id: str = "OURA123",
    is_active: bool = True,
    sync_status: str = "idle",
    token_expires_at: datetime | None = None,
) -> MagicMock:
    """Build a mock Integration object for testing."""
    intg = MagicMock()
    intg.user_id = user_id
    intg.provider = "oura"
    intg.is_active = is_active
    intg.sync_status = sync_status
    intg.sync_error = None
    intg.provider_metadata = {"oura_user_id": oura_user_id}
    intg.token_expires_at = token_expires_at or (datetime.now(timezone.utc) + timedelta(hours=12))
    intg.last_synced_at = None
    return intg


def _mock_db_with_integrations(integrations: list) -> AsyncMock:
    """Create an AsyncMock DB session whose execute() returns the given integrations."""
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = integrations
    mock_result.scalar_one_or_none.return_value = integrations[0] if integrations else None

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=mock_result)
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.refresh = AsyncMock()

    mock_ctx = AsyncMock()
    mock_ctx.__aenter__ = AsyncMock(return_value=mock_db)
    mock_ctx.__aexit__ = AsyncMock(return_value=False)

    return mock_ctx


def _mock_empty_db() -> AsyncMock:
    """DB session returning no integrations."""
    return _mock_db_with_integrations([])


# ---------------------------------------------------------------------------
# Test: sync_oura_webhook_task
# ---------------------------------------------------------------------------


class TestSyncOuraWebhookTask:
    """Tests for sync_oura_webhook_task."""

    def test_sync_oura_webhook_task_runs_without_error(self):
        """Task should complete cleanly when no matching integration is found."""
        with patch("app.tasks.oura_sync.async_session", return_value=_mock_empty_db()):
            result = sync_oura_webhook_task(
                data_type="daily_sleep",
                event_type="create",
                oura_user_id="OURA999",
            )
        assert result["status"] == "no_integration"

    def test_sync_oura_webhook_task_finds_user_and_syncs(self):
        """Task should sync data when matching integration is found."""
        integration = _make_integration(oura_user_id="OURA123")
        mock_db = _mock_db_with_integrations([integration])

        empty_oura_resp = {"data": [], "next_token": None}

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.get_access_token",
                new_callable=AsyncMock,
                return_value="tok-abc",
            ),
            patch(
                "app.tasks.oura_sync._fetch_oura_collection",
                new_callable=AsyncMock,
                return_value=[],
            ),
        ):
            result = sync_oura_webhook_task(
                data_type="daily_sleep",
                event_type="create",
                oura_user_id="OURA123",
            )
        assert result["status"] == "ok"

    def test_sync_oura_webhook_task_no_token(self):
        """Task returns 'no_token' when token service returns None."""
        integration = _make_integration(oura_user_id="OURA123")
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.get_access_token",
                new_callable=AsyncMock,
                return_value=None,
            ),
        ):
            result = sync_oura_webhook_task(
                data_type="daily_sleep",
                event_type="create",
                oura_user_id="OURA123",
            )
        assert result["status"] == "no_token"


# ---------------------------------------------------------------------------
# Test: sync_oura_periodic_task
# ---------------------------------------------------------------------------


class TestSyncOuraPeriodicTask:
    """Tests for sync_oura_periodic_task."""

    def test_sync_oura_periodic_task_runs_without_error(self):
        """Task should return users_synced=0 when no integrations exist."""
        with patch("app.tasks.oura_sync.async_session", return_value=_mock_empty_db()):
            result = sync_oura_periodic_task()
        assert result == {"users_synced": 0}

    def test_sync_oura_periodic_task_syncs_users(self):
        """Task should sync all active integrations."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.get_access_token",
                new_callable=AsyncMock,
                return_value="tok-xyz",
            ),
            patch(
                "app.tasks.oura_sync._fetch_oura_collection",
                new_callable=AsyncMock,
                return_value=[],
            ),
        ):
            result = sync_oura_periodic_task()
        assert result["users_synced"] == 1

    def test_sync_oura_periodic_task_skips_no_token(self):
        """Task should skip user when token service returns None."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.get_access_token",
                new_callable=AsyncMock,
                return_value=None,
            ),
        ):
            result = sync_oura_periodic_task()
        assert result["users_synced"] == 0


# ---------------------------------------------------------------------------
# Test: refresh_oura_tokens_task
# ---------------------------------------------------------------------------


class TestRefreshOuraTokensTask:
    """Tests for refresh_oura_tokens_task."""

    def test_refresh_oura_tokens_task_runs_without_error(self):
        """Task should complete with refreshed=0 when no integrations exist."""
        with patch("app.tasks.oura_sync.async_session", return_value=_mock_empty_db()):
            result = refresh_oura_tokens_task()
        assert result == {"refreshed": 0}

    def test_refresh_oura_tokens_task_refreshes_expiring_token(self):
        """Task should refresh tokens expiring within 6 hours."""
        # Token expires in 1 hour — within the 6-hour cutoff
        expiring_soon = datetime.now(timezone.utc) + timedelta(hours=1)
        integration = _make_integration(token_expires_at=expiring_soon)
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.refresh_access_token",
                new_callable=AsyncMock,
                return_value="new-access-token",
            ),
        ):
            result = refresh_oura_tokens_task()
        assert result["refreshed"] == 1

    def test_refresh_oura_tokens_task_skips_fresh_token(self):
        """Task should NOT refresh tokens that are not expiring soon."""
        # Token expires in 12 hours — well outside the 6-hour cutoff
        fresh = datetime.now(timezone.utc) + timedelta(hours=12)
        integration = _make_integration(token_expires_at=fresh)
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.refresh_access_token",
                new_callable=AsyncMock,
            ) as mock_refresh,
        ):
            result = refresh_oura_tokens_task()
        assert result["refreshed"] == 0
        mock_refresh.assert_not_called()


# ---------------------------------------------------------------------------
# Test: renew_oura_webhook_subscriptions_task
# ---------------------------------------------------------------------------


class TestRenewOuraWebhookSubscriptionsTask:
    """Tests for renew_oura_webhook_subscriptions_task."""

    def test_renew_webhooks_task_runs_without_error(self):
        """Task should complete cleanly when no credentials are configured."""
        with patch("app.config.settings") as mock_settings:
            mock_settings.oura_client_id = ""
            mock_settings.oura_client_secret = ""
            result = renew_oura_webhook_subscriptions_task()
        assert "renewed" in result
        assert "failed" in result

    def test_renew_webhooks_task_with_mock_httpx(self):
        """Task should call the Oura webhook list endpoint."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = []  # No subscriptions to renew

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with (
            patch("app.tasks.oura_sync.httpx.AsyncClient", return_value=mock_client),
            patch("app.tasks.oura_sync.async_session", return_value=_mock_empty_db()),
        ):
            result = renew_oura_webhook_subscriptions_task()

        assert result == {"renewed": 0, "failed": 0}

    def test_renew_webhooks_task_renews_expiring_subscription(self):
        """Task should renew subscriptions expiring within 7 days."""
        # Expires in 3 days — within 7-day cutoff
        expires_soon = (datetime.now(timezone.utc) + timedelta(days=3)).strftime("%Y-%m-%dT%H:%M:%SZ")

        mock_list_response = MagicMock()
        mock_list_response.status_code = 200
        mock_list_response.json.return_value = [{"id": "sub-001", "expiration_time": expires_soon}]

        mock_renew_response = MagicMock()
        mock_renew_response.status_code = 200

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_list_response)
        mock_client.put = AsyncMock(return_value=mock_renew_response)

        mock_settings = MagicMock()
        mock_settings.oura_client_id = "test-client-id"
        mock_settings.oura_client_secret = "test-client-secret"

        with (
            patch("app.tasks.oura_sync.httpx.AsyncClient", return_value=mock_client),
            patch("app.config.settings", mock_settings),
        ):
            result = renew_oura_webhook_subscriptions_task()

        assert result["renewed"] == 1
        assert result["failed"] == 0


# ---------------------------------------------------------------------------
# Test: backfill_oura_data_task
# ---------------------------------------------------------------------------


class TestBackfillOuraDataTask:
    """Tests for backfill_oura_data_task."""

    def test_backfill_task_runs_without_error(self):
        """Task should return 'no_integration' when no integration found."""
        with patch("app.tasks.oura_sync.async_session", return_value=_mock_empty_db()):
            result = backfill_oura_data_task(user_id="user-999", days_back=90)
        assert result["status"] == "no_integration"

    def test_backfill_task_completes_successfully(self):
        """Task should complete a full backfill when integration exists."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.get_access_token",
                new_callable=AsyncMock,
                return_value="tok-backfill",
            ),
            patch(
                "app.tasks.oura_sync._fetch_oura_collection",
                new_callable=AsyncMock,
                return_value=[],
            ),
        ):
            result = backfill_oura_data_task(user_id="user-001", days_back=30)
        assert result["status"] == "ok"
        assert result["days_back"] == 30

    def test_backfill_task_no_token(self):
        """Task should return 'no_token' when token service fails."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.oura_sync.async_session", return_value=mock_db),
            patch(
                "app.tasks.oura_sync.OuraTokenService.get_access_token",
                new_callable=AsyncMock,
                return_value=None,
            ),
        ):
            result = backfill_oura_data_task(user_id="user-001", days_back=7)
        assert result["status"] == "no_token"


# ---------------------------------------------------------------------------
# Test: _fetch_oura_collection (pagination)
# ---------------------------------------------------------------------------


class TestFetchOuraCollection:
    """Tests for the _fetch_oura_collection async helper."""

    def test_fetch_oura_collection_paginates(self):
        """Should follow next_token pagination and accumulate all pages."""

        async def _run():
            page1 = {"data": [{"id": "r1"}], "next_token": "tok-page2"}
            page2 = {"data": [{"id": "r2"}], "next_token": None}

            responses = [page1, page2]
            call_count = 0

            async def _fake_get(url, params=None, headers=None):
                nonlocal call_count
                resp = MagicMock()
                resp.raise_for_status = MagicMock()
                resp.json.return_value = responses[call_count]
                call_count += 1
                return resp

            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = _fake_get

            with patch("app.tasks.oura_sync.httpx.AsyncClient", return_value=mock_client):
                result = await _fetch_oura_collection(
                    access_token="tok",
                    collection="daily_sleep",
                    start_date="2026-01-01",
                    end_date="2026-01-07",
                )

            return result

        import asyncio

        result = asyncio.run(_run())
        assert len(result) == 2
        assert result[0]["id"] == "r1"
        assert result[1]["id"] == "r2"

    def test_fetch_oura_collection_sandbox_url(self):
        """Should use sandbox URL prefix when use_sandbox=True."""
        seen_urls: list[str] = []

        async def _run():
            async def _fake_get(url, params=None, headers=None):
                seen_urls.append(url)
                resp = MagicMock()
                resp.raise_for_status = MagicMock()
                resp.json.return_value = {"data": [], "next_token": None}
                return resp

            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = _fake_get

            with patch("app.tasks.oura_sync.httpx.AsyncClient", return_value=mock_client):
                await _fetch_oura_collection(
                    access_token="tok",
                    collection="daily_sleep",
                    start_date="2026-01-01",
                    end_date="2026-01-07",
                    use_sandbox=True,
                )

        import asyncio

        asyncio.run(_run())
        assert len(seen_urls) == 1
        assert "/v2/sandbox/usercollection/" in seen_urls[0]

    def test_fetch_oura_collection_production_url(self):
        """Should use production URL prefix when use_sandbox=False."""
        seen_urls: list[str] = []

        async def _run():
            async def _fake_get(url, params=None, headers=None):
                seen_urls.append(url)
                resp = MagicMock()
                resp.raise_for_status = MagicMock()
                resp.json.return_value = {"data": [], "next_token": None}
                return resp

            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = _fake_get

            with patch("app.tasks.oura_sync.httpx.AsyncClient", return_value=mock_client):
                await _fetch_oura_collection(
                    access_token="tok",
                    collection="daily_sleep",
                    start_date="2026-01-01",
                    end_date="2026-01-07",
                    use_sandbox=False,
                )

        import asyncio

        asyncio.run(_run())
        assert len(seen_urls) == 1
        assert "/v2/usercollection/" in seen_urls[0]
        assert "sandbox" not in seen_urls[0]


# ---------------------------------------------------------------------------
# Test: _OURA_ACTIVITY_TYPE_MAP coverage
# ---------------------------------------------------------------------------


class TestOuraActivityTypeMap:
    """Verify the activity type mapping has the expected keys."""

    def test_oura_activity_type_map_coverage(self):
        """All expected activity type strings should be present in the map."""
        expected_keys = [
            "running",
            "cycling",
            "swimming",
            "walking",
            "hiking",
            "strength_training",
            "yoga",
        ]
        for key in expected_keys:
            assert key in _OURA_ACTIVITY_TYPE_MAP, f"Missing key: {key}"

    def test_running_maps_to_run(self):
        assert _OURA_ACTIVITY_TYPE_MAP["running"] == ActivityType.RUN

    def test_cycling_maps_to_cycle(self):
        assert _OURA_ACTIVITY_TYPE_MAP["cycling"] == ActivityType.CYCLE

    def test_swimming_maps_to_swim(self):
        assert _OURA_ACTIVITY_TYPE_MAP["swimming"] == ActivityType.SWIM

    def test_walking_maps_to_walk(self):
        assert _OURA_ACTIVITY_TYPE_MAP["walking"] == ActivityType.WALK

    def test_hiking_maps_to_walk(self):
        assert _OURA_ACTIVITY_TYPE_MAP["hiking"] == ActivityType.WALK

    def test_strength_training_maps_to_strength(self):
        assert _OURA_ACTIVITY_TYPE_MAP["strength_training"] == ActivityType.STRENGTH

    def test_yoga_maps_to_unknown(self):
        assert _OURA_ACTIVITY_TYPE_MAP["yoga"] == ActivityType.UNKNOWN

    def test_default_activity_type_is_unknown(self):
        assert _DEFAULT_ACTIVITY_TYPE == ActivityType.UNKNOWN

    def test_unknown_key_not_in_map(self):
        """Keys not in the map should not be present."""
        assert "bouldering" not in _OURA_ACTIVITY_TYPE_MAP


# ---------------------------------------------------------------------------
# Test: _upsert_sleep helper
# ---------------------------------------------------------------------------


class TestUpsertSleep:
    """Unit tests for the _upsert_sleep async helper."""

    def test_upsert_sleep_skips_empty_records(self):
        """Should return 0 and not touch the DB for empty record lists."""

        async def _run():
            mock_db = AsyncMock()
            return await _upsert_sleep(mock_db, "user-001", [])

        import asyncio

        result = asyncio.run(_run())
        assert result == 0

    def test_upsert_sleep_skips_record_without_day(self):
        """Should skip records that have no 'day' or 'date' field."""

        async def _run():
            mock_db = AsyncMock()
            return await _upsert_sleep(mock_db, "user-001", [{"score": 80}])

        import asyncio

        result = asyncio.run(_run())
        assert result == 0

    def test_upsert_sleep_inserts_new_record(self):
        """Should insert a new SleepRecord when none exists."""

        async def _run():
            mock_result = MagicMock()
            mock_result.scalar_one_or_none.return_value = None
            mock_db = AsyncMock()
            mock_db.execute = AsyncMock(return_value=mock_result)
            mock_db.commit = AsyncMock()
            mock_db.add = MagicMock()

            records = [
                {
                    "day": "2026-01-15",
                    "total_sleep_duration": 28800,  # 8 hours in seconds
                    "score": 85,
                }
            ]
            return await _upsert_sleep(mock_db, "user-001", records)

        import asyncio

        result = asyncio.run(_run())
        assert result == 1

    def test_upsert_sleep_updates_existing_record(self):
        """Should update hours/quality_score on an existing SleepRecord."""

        async def _run():
            existing = MagicMock()
            existing.hours = 6.0
            existing.quality_score = 70

            mock_result = MagicMock()
            mock_result.scalar_one_or_none.return_value = existing
            mock_db = AsyncMock()
            mock_db.execute = AsyncMock(return_value=mock_result)
            mock_db.commit = AsyncMock()

            records = [
                {
                    "day": "2026-01-15",
                    "total_sleep_duration": 27000,  # 7.5 hours
                    "score": 88,
                }
            ]
            count = await _upsert_sleep(mock_db, "user-001", records)
            return count, existing

        import asyncio

        count, existing = asyncio.run(_run())
        assert count == 1
        assert abs(existing.hours - 7.5) < 0.01
        assert existing.quality_score == 88


# ---------------------------------------------------------------------------
# Test: _upsert_workouts helper
# ---------------------------------------------------------------------------


class TestUpsertWorkouts:
    """Unit tests for the _upsert_workouts async helper."""

    def test_upsert_workouts_skips_empty_records(self):
        """Should return 0 for empty record lists."""

        async def _run():
            mock_db = AsyncMock()
            return await _upsert_workouts(mock_db, "user-001", [])

        import asyncio

        result = asyncio.run(_run())
        assert result == 0

    def test_upsert_workouts_skips_record_without_id(self):
        """Should skip records that have no 'id' field."""

        async def _run():
            mock_db = AsyncMock()
            return await _upsert_workouts(mock_db, "user-001", [{"activity": "running"}])

        import asyncio

        result = asyncio.run(_run())
        assert result == 0

    def test_upsert_workouts_inserts_new_workout(self):
        """Should insert a new UnifiedActivity for a running workout."""

        async def _run():
            mock_result = MagicMock()
            mock_result.scalar_one_or_none.return_value = None
            mock_db = AsyncMock()
            mock_db.execute = AsyncMock(return_value=mock_result)
            mock_db.commit = AsyncMock()
            mock_db.add = MagicMock()

            records = [
                {
                    "id": "workout-001",
                    "activity": "running",
                    "start_datetime": "2026-01-15T08:00:00+00:00",
                    "duration": 3600,
                    "distance": 10000.0,
                    "calories": 450,
                }
            ]
            return await _upsert_workouts(mock_db, "user-001", records)

        import asyncio

        result = asyncio.run(_run())
        assert result == 1

    def test_upsert_workouts_maps_unknown_activity_to_unknown(self):
        """Unknown activity strings should map to ActivityType.UNKNOWN."""
        from app.tasks.oura_sync import _OURA_ACTIVITY_TYPE_MAP, _DEFAULT_ACTIVITY_TYPE

        result = _OURA_ACTIVITY_TYPE_MAP.get("bouldering", _DEFAULT_ACTIVITY_TYPE)
        assert result == ActivityType.UNKNOWN
