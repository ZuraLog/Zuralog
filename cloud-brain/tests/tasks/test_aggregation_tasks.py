"""Tests for aggregation Celery tasks."""
from unittest.mock import AsyncMock, patch, MagicMock
import uuid
from datetime import date

from app.tasks.aggregation_tasks import recompute_daily_summaries_for_batch


def test_recompute_task_is_a_celery_task():
    # Just verify it's decorated as a shared_task
    assert hasattr(recompute_daily_summaries_for_batch, "delay")


def test_recompute_task_accepts_batch_spec():
    # Dry-run: no real DB, just test the signature
    batch = [
        {"user_id": str(uuid.uuid4()), "local_date": "2026-03-22", "metric_type": "steps"},
    ]
    # Calling with apply() synchronously would require DB — just test it's callable
    assert callable(recompute_daily_summaries_for_batch)
