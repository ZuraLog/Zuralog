"""
Zuralog Cloud Brain — Celery Worker Configuration.

Configures the Celery application for background task processing.
Uses Redis as the message broker (already provisioned in docker-compose).

Usage:
    celery -A app.worker worker --loglevel=info
    celery -A app.worker beat --loglevel=info
"""

import logging

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
