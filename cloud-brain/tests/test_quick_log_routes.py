"""Tests for _resolve_logged_at."""

from datetime import timezone
from app.api.v1.quick_log_routes import _resolve_logged_at


def test_resolve_logged_at_normalizes_offset_to_utc():
    """A timestamp with a non-UTC offset must be returned as UTC ISO 8601."""
    # +05:30 offset → subtract 5h30m → UTC
    result = _resolve_logged_at("2026-03-17T10:00:00+05:30")
    assert result == "2026-03-17T04:30:00+00:00"


def test_resolve_logged_at_utc_input_unchanged():
    """A timestamp already in UTC must round-trip unchanged."""
    result = _resolve_logged_at("2026-03-17T04:30:00+00:00")
    assert result == "2026-03-17T04:30:00+00:00"


def test_resolve_logged_at_z_suffix_normalized():
    """A timestamp ending in Z must be returned as +00:00."""
    result = _resolve_logged_at("2026-03-17T04:30:00Z")
    assert result == "2026-03-17T04:30:00+00:00"


def test_resolve_logged_at_none_returns_utc_now():
    """None input must return a valid UTC ISO 8601 string."""
    result = _resolve_logged_at(None)
    from datetime import datetime

    dt = datetime.fromisoformat(result)
    assert dt.tzinfo is not None
