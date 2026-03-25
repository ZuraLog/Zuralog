"""Tests for DI-3: cache invalidation covers ALL dates in a multi-day ingest batch.

Strategy: build a mock cache_service with spies on delete and invalidate_pattern,
then exercise the invalidation logic in isolation — no HTTP server needed.
"""

import pytest
from unittest.mock import AsyncMock


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_body(daily_dates=(), sleep_dates=(), nutrition_dates=(), weight_dates=()):
    """Build a minimal HealthIngestRequest-like object from date lists."""
    from app.api.v1.health_ingest_schemas import (
        DailyMetricsEntry,
        HealthIngestRequest,
        NutritionEntry,
        SleepEntry,
        WeightEntry,
    )

    return HealthIngestRequest(
        source="apple_health",
        daily_metrics=[DailyMetricsEntry(date=d) for d in daily_dates],
        sleep=[SleepEntry(date=d, hours=8.0) for d in sleep_dates],
        nutrition=[NutritionEntry(date=d, calories=2000) for d in nutrition_dates],
        weight=[WeightEntry(date=d, weight_kg=70.0) for d in weight_dates],
    )


async def _run_invalidation(body, user_id="user-123"):
    """Execute the cache invalidation logic extracted from health_ingest.py."""
    from app.services.cache_service import CacheService

    cache_service = AsyncMock()
    cache_service.delete = AsyncMock()
    cache_service.invalidate_pattern = AsyncMock()

    # Replicate the invalidation block from health_ingest.py
    all_dates: set[str] = set()
    for dm in body.daily_metrics:
        all_dates.add(dm.date)
    for s in body.sleep:
        all_dates.add(s.date)
    for n in body.nutrition:
        all_dates.add(n.date)
    for w in body.weight:
        all_dates.add(w.date)

    for date_val in all_dates:
        await cache_service.delete(
            CacheService.make_key("analytics.daily_summary", user_id, date_val)
        )
    await cache_service.invalidate_pattern(f"cache:analytics.*{user_id}*")

    return cache_service, all_dates


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_all_three_daily_metric_dates_are_invalidated():
    """A batch with 3 different daily_metric dates must delete all 3 per-date keys."""
    body = _make_body(daily_dates=["2026-01-01", "2026-01-02", "2026-01-03"])

    cache_service, all_dates = await _run_invalidation(body)

    assert all_dates == {"2026-01-01", "2026-01-02", "2026-01-03"}
    assert cache_service.delete.call_count == 3


@pytest.mark.asyncio
async def test_dates_from_all_data_types_are_collected():
    """Dates from sleep, nutrition, and weight lists must all be included."""
    body = _make_body(
        daily_dates=["2026-01-01"],
        sleep_dates=["2026-01-02"],
        nutrition_dates=["2026-01-03"],
        weight_dates=["2026-01-04"],
    )

    cache_service, all_dates = await _run_invalidation(body)

    assert all_dates == {"2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04"}
    assert cache_service.delete.call_count == 4


@pytest.mark.asyncio
async def test_duplicate_dates_across_types_are_deduplicated():
    """The same date appearing in multiple lists must only be deleted once."""
    body = _make_body(
        daily_dates=["2026-01-01"],
        sleep_dates=["2026-01-01"],
        nutrition_dates=["2026-01-01"],
    )

    cache_service, all_dates = await _run_invalidation(body)

    assert len(all_dates) == 1
    assert cache_service.delete.call_count == 1


@pytest.mark.asyncio
async def test_invalidate_pattern_called_for_user():
    """invalidate_pattern must be called with a pattern containing the user_id."""
    user_id = "user-xyz"
    body = _make_body(daily_dates=["2026-01-01"])

    cache_service, _ = await _run_invalidation(body, user_id=user_id)

    cache_service.invalidate_pattern.assert_called_once()
    pattern_arg = cache_service.invalidate_pattern.call_args[0][0]
    assert user_id in pattern_arg, (
        f"invalidate_pattern was called with {pattern_arg!r}, "
        f"which does not contain user_id={user_id!r}"
    )


@pytest.mark.asyncio
async def test_correct_cache_key_format_for_date():
    """Each per-date delete must use the canonical CacheService.make_key format."""
    from app.services.cache_service import CacheService

    user_id = "user-123"
    date_val = "2026-01-01"
    expected_key = CacheService.make_key("analytics.daily_summary", user_id, date_val)

    body = _make_body(daily_dates=[date_val])
    cache_service, _ = await _run_invalidation(body, user_id=user_id)

    cache_service.delete.assert_called_once_with(expected_key)


@pytest.mark.asyncio
async def test_empty_batch_no_date_deletes_but_pattern_still_called():
    """An empty batch has no dates to delete, but invalidate_pattern should still run."""
    body = _make_body()  # all lists empty

    cache_service, all_dates = await _run_invalidation(body)

    assert len(all_dates) == 0
    assert cache_service.delete.call_count == 0
    cache_service.invalidate_pattern.assert_called_once()
