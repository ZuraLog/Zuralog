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

if settings.posthog_api_key:
    _posthog.api_key = settings.posthog_api_key
    _posthog.host = settings.posthog_host
    logger.info("PostHog initialized for Celery worker")

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

# Upstash Redis requires ssl_cert_reqs to be set explicitly when using rediss://.
# CERT_REQUIRED enforces full certificate verification against the system CA bundle.
# Upstash uses valid CA-signed certificates (DigiCert), so this is safe and correct.
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
}

# Auto-discover tasks in services and tasks modules
celery_app.autodiscover_tasks(["app.services", "app.tasks"])
