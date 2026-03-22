"""Ingest service helpers: local_date computation and value validation."""
from datetime import date, datetime, timezone, timedelta


def compute_local_date(recorded_at_str: str) -> date:
    """Extract the user's local date from an ISO 8601 string with UTC offset.

    The offset must be present in the string (e.g. '+05:00', '-05:00', 'Z').
    This is the canonical way to determine local_date — it is computed from
    the client-supplied offset before PostgreSQL normalises the value to UTC.

    Raises:
        ValueError: if the string has no UTC offset.
    """
    try:
        dt = datetime.fromisoformat(recorded_at_str)
    except ValueError as exc:
        raise ValueError(f"Invalid ISO 8601 timestamp: {recorded_at_str!r}") from exc

    if dt.tzinfo is None or dt.utcoffset() is None:
        raise ValueError(
            f"recorded_at must include a UTC offset (e.g. '+05:00'). "
            f"Got: {recorded_at_str!r}"
        )

    # dt is already in the local timezone implied by the offset.
    # Extract the date directly — it IS the user's local date.
    return dt.date()


def validate_metric_value(
    metric_type: str,
    value: float,
    min_value: float | None,
    max_value: float | None,
) -> None:
    """Raise ValueError if value is outside the defined bounds for this metric.

    min_value=None and max_value=None mean no validation — the metric is
    unbounded or not yet defined.
    """
    if min_value is not None and value < min_value:
        raise ValueError(
            f"{metric_type} value {value} is out of range (min={min_value})"
        )
    if max_value is not None and value > max_value:
        raise ValueError(
            f"{metric_type} value {value} is out of range (max={max_value})"
        )
