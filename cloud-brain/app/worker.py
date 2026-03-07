"""
Zuralog Cloud Brain — Celery Worker Configuration.

Configures the Celery application for background task processing.
Uses Redis as the message broker (already provisioned in docker-compose).

Usage:
    celery -A app.worker worker --loglevel=info
    celery -A app.worker beat --loglevel=info
"""

import logging
import ssl

from celery import Celery

from app.config import settings

logger = logging.getLogger(__name__)

import sentry_sdk  # noqa: E402

if settings.sentry_dsn:
    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.app_env,
        release="cloud-brain@worker",
        traces_sample_rate=settings.sentry_traces_sample_rate,
        send_default_pii=False,
        enable_tracing=True,
    )

import posthog as _posthog  # noqa: E402

_settings = settings  # capture for signal handler closure


def _on_posthog_error(error: Exception, items: list) -> None:
    """PostHog error callback — log but never raise."""
    logger.warning("PostHog flush error: %s (items=%d)", error, len(items))


if settings.posthog_api_key:
    _posthog.api_key = settings.posthog_api_key
    _posthog.host = settings.posthog_host
    _posthog.debug = settings.app_env == "development"
    _posthog.on_error = _on_posthog_error
    _posthog.max_queue_size = 100
    _posthog.flush_interval = 5.0
    logger.info("PostHog initialized for Celery worker (host=%s)", settings.posthog_host)

from celery.signals import worker_shutdown  # noqa: E402


@worker_shutdown.connect
def _flush_posthog_on_shutdown(**kwargs):
    """Flush pending PostHog events before Celery worker exits."""
    if _settings.posthog_api_key:
        try:
            _posthog.shutdown()
            logger.info("PostHog flushed on worker shutdown")
        except Exception:
            logger.warning("PostHog worker shutdown flush failed", exc_info=True)


celery_app = Celery(
    "zuralog",
    broker=settings.redis_url,
    backend=settings.redis_url,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)

# When using TLS Redis (rediss://), ssl_cert_reqs must be set explicitly for Celery.
# CERT_REQUIRED enforces full certificate verification against the system CA bundle.
# Railway Redis uses plain redis:// internally. This block only activates if REDIS_URL starts with rediss://.
if settings.redis_url.startswith("rediss://"):
    _ssl_opts = {"ssl_cert_reqs": ssl.CERT_REQUIRED}
    celery_app.conf.update(
        broker_use_ssl=_ssl_opts,
        redis_backend_use_ssl=_ssl_opts,
    )

# Beat schedule: periodic tasks
celery_app.conf.beat_schedule = {
    "sync-active-users-15m": {
        "task": "app.services.sync_scheduler.sync_all_users_task",
        "schedule": 900.0,  # 15 minutes
    },
    "refresh-expiring-tokens-1h": {
        "task": "app.services.sync_scheduler.refresh_tokens_task",
        "schedule": 3600.0,  # 1 hour
    },
    "sync-fitbit-users-15m": {
        "task": "app.tasks.fitbit_sync.sync_fitbit_periodic_task",
        "schedule": 900.0,  # 15 minutes
    },
    "refresh-fitbit-tokens-1h": {
        "task": "app.tasks.fitbit_sync.refresh_fitbit_tokens_task",
        "schedule": 3600.0,  # 1 hour
    },
    "sync-oura-users-15m": {
        "task": "app.tasks.oura_sync.sync_oura_periodic_task",
        "schedule": 900.0,  # 15 minutes
    },
    "refresh-oura-tokens-4h": {
        "task": "app.tasks.oura_sync.refresh_oura_tokens_task",
        "schedule": 14400.0,  # 4 hours
    },
    "renew-oura-webhooks-daily": {
        "task": "app.tasks.oura_sync.renew_oura_webhook_subscriptions_task",
        "schedule": 86400.0,  # 24 hours
    },
    "sync-withings-users-15m": {
        "task": "app.tasks.withings_sync.sync_withings_periodic_task",
        "schedule": 900.0,  # 15 minutes
    },
    "refresh-withings-tokens-1h": {
        "task": "app.tasks.withings_sync.refresh_withings_tokens_task",
        "schedule": 3600.0,  # 1 hour (tokens expire in 3h, refresh buffer is 30min)
    },
    "sync-polar-users-15m": {
        "task": "polar.sync_periodic",
        "schedule": 900.0,  # 15 minutes
    },
    "monitor-polar-token-expiry-daily": {
        "task": "polar.monitor_token_expiry",
        "schedule": 86400.0,  # 24 hours
    },
    "check-polar-webhook-status-daily": {
        "task": "polar.check_webhook_status",
        "schedule": 86400.0,  # 24 hours
    },
    # Phase 2 — notification / reminder / report / alert tasks
    "send-morning-briefings-15m": {
        "task": "app.tasks.morning_briefing_task.send_morning_briefings",
        "schedule": 900.0,  # 15 minutes
    },
    "send-smart-reminders-1h": {
        "task": "app.tasks.smart_reminder_tasks.send_smart_reminders",
        "schedule": 3600.0,  # 1 hour
    },
    "generate-weekly-reports-monday": {
        "task": "app.tasks.report_tasks.generate_weekly_reports_task",
        "schedule": 604800.0,  # 7 days — triggered Monday 06:00 UTC via crontab
    },
    "generate-monthly-reports-1st": {
        "task": "app.tasks.report_tasks.generate_monthly_reports_task",
        "schedule": 2592000.0,  # ~30 days — triggered 1st of month 06:00 UTC
    },
    "check-stale-integrations-daily": {
        "task": "app.tasks.insight_tasks.check_stale_integrations_task",
        "schedule": 86400.0,  # 24 hours
    },
}

# Auto-discover tasks in services and tasks modules
celery_app.autodiscover_tasks(["app.services", "app.tasks"])
