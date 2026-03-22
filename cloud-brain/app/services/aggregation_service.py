"""Pure aggregation logic for daily_summaries recomputation.

No database access. Takes a list of event dicts (value, recorded_at) and
returns an aggregated result using the rule from metric_definitions.
"""
from dataclasses import dataclass
from datetime import datetime


@dataclass
class AggregationResult:
    value: float
    event_count: int
    unit: str


def aggregate_events(
    events: list[dict],   # each: {"value": float, "recorded_at": datetime}
    fn: str,              # "sum" | "avg" | "latest"
    unit: str,
) -> AggregationResult | None:
    """Compute the aggregated daily value from a list of health events.

    Returns None if events is empty (caller should not upsert daily_summaries
    for an empty event set — this means all events were deleted).
    """
    if not events:
        return None

    values = [e["value"] for e in events]

    if fn == "sum":
        return AggregationResult(value=sum(values), event_count=len(events), unit=unit)

    if fn == "avg":
        return AggregationResult(value=sum(values) / len(values), event_count=len(events), unit=unit)

    if fn == "latest":
        latest = max(events, key=lambda e: (e["recorded_at"], e.get("created_at", datetime.min)))
        return AggregationResult(value=latest["value"], event_count=len(events), unit=unit)

    raise ValueError(f"Unknown aggregation_fn: {fn!r}. Must be 'sum', 'avg', or 'latest'.")
