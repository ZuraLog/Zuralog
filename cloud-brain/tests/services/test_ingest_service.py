"""Tests for ingest service: local_date extraction and value validation."""
from datetime import date
import pytest
from app.services.ingest_service import compute_local_date, validate_metric_value


def test_local_date_negative_offset():
    # 23:45 at -05:00 → local date is still the same day
    result = compute_local_date("2026-03-22T23:45:00-05:00")
    assert result == date(2026, 3, 22)


def test_local_date_crosses_midnight_positive():
    # 00:15 at +05:00 means UTC is previous day; local date is the +05:00 day
    result = compute_local_date("2026-03-23T00:15:00+05:00")
    assert result == date(2026, 3, 23)


def test_local_date_utc():
    result = compute_local_date("2026-03-22T12:00:00+00:00")
    assert result == date(2026, 3, 22)


def test_local_date_midnight_negative_offset():
    # 00:30 at -05:00 → local date is the same as submitted
    result = compute_local_date("2026-03-22T00:30:00-05:00")
    assert result == date(2026, 3, 22)


def test_compute_local_date_requires_offset():
    # No offset → raises ValueError
    with pytest.raises(ValueError, match="UTC offset"):
        compute_local_date("2026-03-22T12:00:00")


def test_validate_metric_value_in_range():
    # Should not raise
    validate_metric_value(metric_type="steps", value=5000.0, min_value=0, max_value=100000)


def test_validate_metric_value_out_of_range():
    with pytest.raises(ValueError, match="out of range"):
        validate_metric_value(metric_type="steps", value=-1.0, min_value=0, max_value=100000)


def test_validate_metric_value_no_bounds():
    # min_value=None, max_value=None → always passes
    validate_metric_value(metric_type="unknown_metric", value=999.0, min_value=None, max_value=None)
