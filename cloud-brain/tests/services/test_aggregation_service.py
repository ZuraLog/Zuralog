"""Tests for the pure aggregation logic."""
from datetime import date, datetime, timezone
from app.services.aggregation_service import aggregate_events, AggregationResult


def _event(value: float, recorded_at: datetime | None = None):
    return {"value": value, "recorded_at": recorded_at or datetime.now(tz=timezone.utc)}


def test_sum_aggregation():
    events = [_event(250.0), _event(300.0), _event(200.0)]
    result = aggregate_events(events, fn="sum", unit="mL")
    assert result.value == 750.0
    assert result.event_count == 3


def test_avg_aggregation():
    events = [_event(58.0), _event(62.0), _event(60.0)]
    result = aggregate_events(events, fn="avg", unit="bpm")
    assert result.value == 60.0


def test_latest_aggregation():
    t1 = datetime(2026, 3, 22, 8, 0, tzinfo=timezone.utc)
    t2 = datetime(2026, 3, 22, 20, 0, tzinfo=timezone.utc)
    events = [_event(70.0, t1), _event(71.5, t2)]
    result = aggregate_events(events, fn="latest", unit="kg")
    assert result.value == 71.5


def test_single_event_latest():
    events = [_event(65.0)]
    result = aggregate_events(events, fn="latest", unit="kg")
    assert result.value == 65.0


def test_empty_events_returns_none():
    result = aggregate_events([], fn="sum", unit="steps")
    assert result is None


def test_sum_single_event():
    result = aggregate_events([_event(10000.0)], fn="sum", unit="steps")
    assert result.value == 10000.0
    assert result.event_count == 1
