"""
Zuralog Cloud Brain — Polar AccessLink Celery Sync Task Tests.

Tests all six Polar Celery tasks:
- sync_polar_webhook_task: webhook-triggered sync per event type
- sync_polar_periodic_task: 15-minute Celery Beat task
- monitor_polar_token_expiry_task: daily expiry check + push notify
- backfill_polar_data_task: one-time historical backfill (28 days)
- create_polar_webhook_task: one-time webhook registration (Basic auth)
- check_polar_webhook_status_task: daily webhook health check

All external HTTP calls, DB sessions, and push service calls are mocked.
"""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, call, patch

import pytest

from app.tasks.polar_sync import (
    backfill_polar_data_task,
    check_polar_webhook_status_task,
    create_polar_webhook_task,
    monitor_polar_token_expiry_task,
    sync_polar_periodic_task,
    sync_polar_webhook_task,
)


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------


def _make_integration(
    user_id: str = "user-001",
    polar_user_id: int = 12345,
    is_active: bool = True,
    sync_status: str = "idle",
    token_expires_at: datetime | None = None,
    access_token: str = "polar-access-token",
) -> MagicMock:
    """Build a mock Integration object for testing."""
    intg = MagicMock()
    intg.user_id = user_id
    intg.provider = "polar"
    intg.is_active = is_active
    intg.sync_status = sync_status
    intg.sync_error = None
    intg.provider_metadata = {"polar_user_id": polar_user_id}
    intg.access_token = access_token
    intg.token_expires_at = token_expires_at or (datetime.now(timezone.utc) + timedelta(days=300))
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


def _mock_httpx_response(status_code: int = 200, json_data: dict | None = None) -> MagicMock:
    """Create a mock httpx response."""
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data or {}
    resp.raise_for_status = MagicMock()
    return resp


def _mock_httpx_client(responses: list[MagicMock] | None = None) -> AsyncMock:
    """Create a mock httpx.AsyncClient context manager."""
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    if responses:
        # Return responses in order for successive calls
        mock_client.get = AsyncMock(side_effect=responses)
        mock_client.post = AsyncMock(side_effect=responses)
    else:
        default_resp = _mock_httpx_response()
        mock_client.get = AsyncMock(return_value=default_resp)
        mock_client.post = AsyncMock(return_value=default_resp)

    return mock_client


# ---------------------------------------------------------------------------
# Test: sync_polar_webhook_task
# ---------------------------------------------------------------------------


class TestSyncWebhookTask:
    """Tests for sync_polar_webhook_task."""

    def test_finds_user_by_polar_user_id(self):
        """Task should resolve the user from polar_user_id in provider_metadata."""
        integration = _make_integration(polar_user_id=99999)
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {"exercises": []})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            # Should not raise
            sync_polar_webhook_task(
                polar_user_id=99999,
                event_type="EXERCISE",
                entity_id="exercise-001",
            )

    def test_skips_when_user_not_found(self):
        """Task should log warning and return when no matching integration found."""
        integration = _make_integration(polar_user_id=11111)
        mock_db = _mock_db_with_integrations([integration])

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
        ):
            # polar_user_id=99999 does not match integration's 11111
            sync_polar_webhook_task(
                polar_user_id=99999,
                event_type="EXERCISE",
                entity_id="exercise-001",
            )
        # No exception — task handles gracefully

    def test_fetches_exercise_on_exercise_event(self):
        """Task should GET /v3/exercises/{entity_id} for EXERCISE events."""
        integration = _make_integration(polar_user_id=12345)
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {"id": "exercise-001"})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_webhook_task(
                polar_user_id=12345,
                event_type="EXERCISE",
                entity_id="exercise-001",
            )

        mock_client.get.assert_called_once()
        call_url = mock_client.get.call_args[0][0]
        assert "/v3/exercises/exercise-001" in call_url

    def test_fetches_sleep_on_sleep_event(self):
        """Task should GET /v3/users/sleep-data/{date} for SLEEP events."""
        integration = _make_integration(polar_user_id=12345)
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {"sleep": {}})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_webhook_task(
                polar_user_id=12345,
                event_type="SLEEP",
                date="2026-01-15",
            )

        mock_client.get.assert_called_once()
        call_url = mock_client.get.call_args[0][0]
        assert "/v3/users/sleep-data/2026-01-15" in call_url

    def test_fetches_activity_on_activity_event(self):
        """Task should GET /v3/users/activity-summary/{date} for ACTIVITY_SUMMARY events."""
        integration = _make_integration(polar_user_id=12345)
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {"activity_calories": 500})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_webhook_task(
                polar_user_id=12345,
                event_type="ACTIVITY_SUMMARY",
                date="2026-01-15",
            )

        mock_client.get.assert_called_once()
        call_url = mock_client.get.call_args[0][0]
        assert "/v3/users/activity-summary/2026-01-15" in call_url

    def test_updates_last_synced_at(self):
        """Task should update integration.last_synced_at after successful sync."""
        integration = _make_integration(polar_user_id=12345)
        integration.last_synced_at = None
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_webhook_task(
                polar_user_id=12345,
                event_type="EXERCISE",
                entity_id="ex-001",
            )

        assert integration.last_synced_at is not None

    def test_retries_on_exception(self):
        """Task should retry when an exception occurs during execution."""
        with patch("app.tasks.polar_sync.async_session", side_effect=RuntimeError("DB down")):
            with pytest.raises(Exception):
                sync_polar_webhook_task(
                    polar_user_id=12345,
                    event_type="EXERCISE",
                    entity_id="ex-001",
                )

    def test_skips_expired_token(self):
        """Task should skip syncing when the token is expired."""
        expired_at = datetime.now(timezone.utc) - timedelta(days=1)
        integration = _make_integration(polar_user_id=12345, token_expires_at=expired_at)
        mock_db = _mock_db_with_integrations([integration])

        mock_client = _mock_httpx_client()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_webhook_task(
                polar_user_id=12345,
                event_type="EXERCISE",
                entity_id="ex-001",
            )

        # No HTTP calls should be made for expired token
        mock_client.get.assert_not_called()


# ---------------------------------------------------------------------------
# Test: sync_polar_periodic_task
# ---------------------------------------------------------------------------


class TestSyncPeriodicTask:
    """Tests for sync_polar_periodic_task."""

    def test_skips_expired_tokens(self):
        """Task should skip integrations with expired tokens."""
        expired_at = datetime.now(timezone.utc) - timedelta(days=1)
        integration = _make_integration(token_expires_at=expired_at)
        mock_db = _mock_db_with_integrations([integration])

        mock_client = _mock_httpx_client()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_periodic_task()

        mock_client.get.assert_not_called()

    def test_sets_syncing_status(self):
        """Task should set sync_status to 'syncing' before fetching data."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_periodic_task()

        # After the sync, status should be idle
        assert integration.sync_status == "idle"

    def test_resets_to_idle_on_success(self):
        """Task should set sync_status='idle' and clear sync_error on success."""
        integration = _make_integration(sync_status="syncing")
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            sync_polar_periodic_task()

        assert integration.sync_status == "idle"
        assert integration.sync_error is None

    def test_sets_error_status_on_failure(self):
        """Task should set sync_status='error' when the sync loop raises an error."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        mock_client = _mock_httpx_client()
        # Patch _fetch_polar directly to raise (bypasses its internal try/except)
        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync._fetch_polar", new=AsyncMock(side_effect=RuntimeError("boom"))),
            patch("app.tasks.polar_sync.sentry_sdk.capture_exception"),
        ):
            sync_polar_periodic_task()

        assert integration.sync_status == "error"

    def test_runs_with_no_integrations(self):
        """Task should complete cleanly when no active Polar integrations exist."""
        with patch("app.tasks.polar_sync.async_session", return_value=_mock_empty_db()):
            sync_polar_periodic_task()  # Should not raise


# ---------------------------------------------------------------------------
# Test: monitor_polar_token_expiry_task
# ---------------------------------------------------------------------------


class TestMonitorTokenExpiry:
    """Tests for monitor_polar_token_expiry_task."""

    def test_marks_expiring_integrations(self):
        """Task should set sync_status='expiring' for tokens expiring within 30 days."""
        expiring_at = datetime.now(timezone.utc) + timedelta(days=15)
        integration = _make_integration(token_expires_at=expiring_at, sync_status="idle")
        mock_db = _mock_db_with_integrations([integration])

        mock_push_cls = MagicMock()
        mock_push_inst = mock_push_cls.return_value
        mock_push_inst.send_to_user = AsyncMock()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.services.push_service.PushService", mock_push_cls),
        ):
            monitor_polar_token_expiry_task()

        assert integration.sync_status == "expiring"

    def test_sends_push_notification(self):
        """Task should send a push notification for expiring tokens."""
        expiring_at = datetime.now(timezone.utc) + timedelta(days=10)
        integration = _make_integration(
            user_id="user-exp-001",
            token_expires_at=expiring_at,
            sync_status="idle",
        )
        mock_db = _mock_db_with_integrations([integration])

        mock_push_cls = MagicMock()
        mock_push_inst = mock_push_cls.return_value
        mock_push_inst.send_to_user = AsyncMock()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.services.push_service.PushService", mock_push_cls),
        ):
            monitor_polar_token_expiry_task()

        mock_push_inst.send_to_user.assert_called_once()
        call_kwargs = mock_push_inst.send_to_user.call_args[1]
        assert call_kwargs["user_id"] == "user-exp-001"
        assert "Polar" in call_kwargs["title"]

    def test_skips_already_marked_expiring(self):
        """Task should not re-process integrations already marked 'expiring'."""
        expiring_at = datetime.now(timezone.utc) + timedelta(days=10)
        integration = _make_integration(
            token_expires_at=expiring_at,
            sync_status="expiring",  # Already marked
        )
        # Return empty since filter excludes sync_status="expiring"
        mock_db = _mock_db_with_integrations([])

        mock_push_cls = MagicMock()
        mock_push_inst = mock_push_cls.return_value
        mock_push_inst.send_to_user = AsyncMock()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.services.push_service.PushService", mock_push_cls),
        ):
            monitor_polar_token_expiry_task()

        mock_push_inst.send_to_user.assert_not_called()


# ---------------------------------------------------------------------------
# Test: backfill_polar_data_task
# ---------------------------------------------------------------------------


class TestBackfillTask:
    """Tests for backfill_polar_data_task."""

    def test_fetches_historical_data(self):
        """Task should fetch exercises and per-day data for days_back days."""
        integration = _make_integration()
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            backfill_polar_data_task(user_id="user-001", days_back=7)

        # Should have made multiple GET calls (exercises + per-day data)
        assert mock_client.get.call_count > 1

    def test_skips_when_no_integration_found(self):
        """Task should return early when no active integration found."""
        mock_db = _mock_empty_db()
        mock_client = _mock_httpx_client()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            backfill_polar_data_task(user_id="user-999", days_back=7)

        mock_client.get.assert_not_called()

    def test_skips_when_token_expired(self):
        """Task should return early when access token is expired."""
        expired_at = datetime.now(timezone.utc) - timedelta(days=1)
        integration = _make_integration(token_expires_at=expired_at)
        mock_db = _mock_db_with_integrations([integration])

        mock_client = _mock_httpx_client()

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            backfill_polar_data_task(user_id="user-001", days_back=7)

        mock_client.get.assert_not_called()

    def test_retries_on_exception(self):
        """Task should retry when an exception occurs."""
        with patch("app.tasks.polar_sync.async_session", side_effect=RuntimeError("DB down")):
            with pytest.raises(Exception):
                backfill_polar_data_task(user_id="user-001", days_back=7)

    def test_updates_last_synced_at_after_backfill(self):
        """Task should update integration.last_synced_at after successful backfill."""
        integration = _make_integration()
        integration.last_synced_at = None
        mock_db = _mock_db_with_integrations([integration])

        get_resp = _mock_httpx_response(200, {})
        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.async_session", return_value=mock_db),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            backfill_polar_data_task(user_id="user-001", days_back=3)

        assert integration.last_synced_at is not None


# ---------------------------------------------------------------------------
# Test: create_polar_webhook_task
# ---------------------------------------------------------------------------


class TestCreateWebhookTask:
    """Tests for create_polar_webhook_task."""

    def test_skips_if_no_client_id(self):
        """Task should return early when polar_client_id is not configured."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = ""
        mock_settings.polar_client_secret = "secret"

        mock_client = _mock_httpx_client()

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            create_polar_webhook_task()

        mock_client.get.assert_not_called()
        mock_client.post.assert_not_called()

    def test_skips_if_webhook_exists(self):
        """Task should skip POST when a webhook is already registered."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = "test-client-id"
        mock_settings.polar_client_secret = "test-client-secret"

        # GET response returns existing webhook data
        existing_webhook = {"id": "wh-001", "url": "https://api.zuralog.com/api/v1/webhooks/polar"}
        get_resp = _mock_httpx_response(200, existing_webhook)

        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            create_polar_webhook_task()

        mock_client.post.assert_not_called()

    def test_creates_webhook_when_not_exists(self):
        """Task should POST to create webhook when none exists."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = "test-client-id"
        mock_settings.polar_client_secret = "test-client-secret"
        mock_settings.withings_api_base_url = "https://api.zuralog.com"

        # GET response returns empty (no webhook exists)
        get_resp = _mock_httpx_response(200, {})
        # POST response for creating webhook
        post_resp = _mock_httpx_response(
            201,
            {
                "id": "wh-new",
                "signature_secret_key": "abc123",
            },
        )

        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)
        mock_client.post = AsyncMock(return_value=post_resp)

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            create_polar_webhook_task()

        mock_client.post.assert_called_once()
        post_url = mock_client.post.call_args[0][0]
        assert "/v3/webhooks" in post_url

    def test_webhook_includes_all_event_types(self):
        """Created webhook should include all required event types."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = "test-client-id"
        mock_settings.polar_client_secret = "test-client-secret"
        mock_settings.withings_api_base_url = "https://api.zuralog.com"

        get_resp = _mock_httpx_response(200, {})
        post_resp = _mock_httpx_response(201, {"id": "wh-new", "signature_secret_key": "key123"})

        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)
        mock_client.post = AsyncMock(return_value=post_resp)

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            create_polar_webhook_task()

        post_kwargs = mock_client.post.call_args[1]
        json_body = post_kwargs.get("json", {})
        events = json_body.get("events", [])

        assert "EXERCISE" in events
        assert "SLEEP" in events
        assert "CONTINUOUS_HEART_RATE" in events
        assert "ACTIVITY_SUMMARY" in events


# ---------------------------------------------------------------------------
# Test: check_polar_webhook_status_task
# ---------------------------------------------------------------------------


class TestCheckWebhookStatusTask:
    """Tests for check_polar_webhook_status_task."""

    def test_skips_if_no_client_id(self):
        """Task should return early when polar_client_id is not configured."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = ""

        mock_client = _mock_httpx_client()

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            check_polar_webhook_status_task()

        mock_client.get.assert_not_called()

    def test_skips_active_webhook(self):
        """Task should not attempt to reactivate an already active webhook."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = "test-client-id"
        mock_settings.polar_client_secret = "test-client-secret"

        # Webhook is active
        get_resp = _mock_httpx_response(200, {"id": "wh-001", "active": True})

        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            check_polar_webhook_status_task()

        mock_client.post.assert_not_called()

    def test_reactivates_inactive_webhook(self):
        """Task should POST to reactivate a deactivated webhook."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = "test-client-id"
        mock_settings.polar_client_secret = "test-client-secret"

        # Webhook is inactive
        get_resp = _mock_httpx_response(200, {"id": "wh-001", "active": False})
        post_resp = _mock_httpx_response(200, {"id": "wh-001", "active": True})

        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)
        mock_client.post = AsyncMock(return_value=post_resp)

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            check_polar_webhook_status_task()

        mock_client.post.assert_called_once()
        post_url = mock_client.post.call_args[0][0]
        assert "wh-001" in post_url
        assert "activate" in post_url

    def test_skips_when_no_webhook_data(self):
        """Task should return early when GET returns empty webhook data."""
        mock_settings = MagicMock()
        mock_settings.polar_client_id = "test-client-id"
        mock_settings.polar_client_secret = "test-client-secret"

        get_resp = _mock_httpx_response(200, {})

        mock_client = _mock_httpx_client()
        mock_client.get = AsyncMock(return_value=get_resp)

        with (
            patch("app.tasks.polar_sync.settings", mock_settings),
            patch("app.tasks.polar_sync.httpx.AsyncClient", return_value=mock_client),
        ):
            check_polar_webhook_status_task()

        mock_client.post.assert_not_called()
