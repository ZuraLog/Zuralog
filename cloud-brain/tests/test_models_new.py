"""Tests for new unified health data ORM models."""
import uuid
from datetime import date, datetime, timezone

from app.models.metric_definition import MetricDefinition
from app.models.activity_session import ActivitySession
from app.models.health_event import HealthEvent
from app.models.daily_summary import DailySummary


def test_metric_definition_instantiation():
    md = MetricDefinition(
        metric_type="steps",
        display_name="Steps",
        unit="steps",
        category="activity",
        aggregation_fn="sum",
        data_type="integer",
    )
    assert md.metric_type == "steps"
    assert md.is_active is True


def test_health_event_instantiation():
    event = HealthEvent(
        user_id=uuid.uuid4(),
        metric_type="water_ml",
        value=250.0,
        unit="mL",
        source="manual",
        recorded_at=datetime.now(tz=timezone.utc),
        local_date=date.today(),
        granularity="point_in_time",
    )
    assert event.value == 250.0
    assert event.deleted_at is None
    assert event.updated_at is None


def test_daily_summary_instantiation():
    ds = DailySummary(
        user_id=uuid.uuid4(),
        date=date.today(),
        metric_type="steps",
        value=8500.0,
        unit="steps",
    )
    assert ds.is_stale is False
    assert ds.event_count == 1


def test_activity_session_instantiation():
    session = ActivitySession(
        user_id=uuid.uuid4(),
        activity_type="run",
        source="manual",
        started_at=datetime.now(tz=timezone.utc),
    )
    assert session.ended_at is None
    assert session.idempotency_key is None
