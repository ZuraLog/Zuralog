"""Tests for app.services.goal_history_service.get_goal_history.

Uses in-memory SQLite to exercise the real query logic.
Verifies:
- Returns rows oldest-first for a seeded metric.
- Returns [] when no data exists.
- Excludes stale rows.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import Boolean, Column, Date, DateTime, Float, Integer, MetaData, String, Table, UniqueConstraint
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.services.goal_history_service import get_goal_history


# ---------------------------------------------------------------------------
# Fixtures: in-memory SQLite with only the daily_summaries table
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def db_session():
    """Provide a fresh async SQLite session with a minimal daily_summaries table.

    Avoids Base.metadata.create_all which would fail on Postgres-only column
    types (JSONB) present on other models.
    """
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)

    meta = MetaData()
    Table(
        "daily_summaries",
        meta,
        Column("id", String, primary_key=True),
        Column("user_id", String, nullable=False),
        Column("date", Date, nullable=False),
        Column("metric_type", String(100), nullable=False),
        Column("value", Float, nullable=False),
        Column("unit", String(50), nullable=False),
        Column("event_count", Integer, nullable=False, default=1),
        Column("is_stale", Boolean, nullable=False, default=False),
        Column("computed_at", DateTime, nullable=True),
        UniqueConstraint("user_id", "date", "metric_type", name="uq_daily_summaries_user_date_metric"),
    )

    async with engine.begin() as conn:
        await conn.run_sync(meta.create_all)

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session

    await engine.dispose()


async def _seed_summary(
    session: AsyncSession,
    user_id: str,
    summary_date: date,
    metric_type: str,
    value: float,
    is_stale: bool = False,
) -> None:
    """Insert a DailySummary row directly for test setup."""
    from app.models.daily_summary import DailySummary

    row = DailySummary(
        id=str(uuid.uuid4()),
        user_id=user_id,
        date=summary_date,
        metric_type=metric_type,
        value=value,
        unit="steps",
        event_count=1,
        is_stale=is_stale,
    )
    session.add(row)
    await session.commit()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_goal_history_returns_rows_oldest_first(db_session):
    """get_goal_history returns rows sorted ascending by date."""
    user_id = "hist-user-001"
    today = date.today()
    day1 = today - timedelta(days=5)
    day2 = today - timedelta(days=3)
    day3 = today - timedelta(days=1)

    await _seed_summary(db_session, user_id, day2, "steps", 7800.0)
    await _seed_summary(db_session, user_id, day1, "steps", 6500.0)
    await _seed_summary(db_session, user_id, day3, "steps", 9200.0)

    result = await get_goal_history(db_session, user_id, "steps", days=30)

    assert len(result) == 3
    # Oldest first
    assert result[0]["date"] == str(day1)
    assert result[0]["value"] == 6500.0
    assert result[1]["date"] == str(day2)
    assert result[1]["value"] == 7800.0
    assert result[2]["date"] == str(day3)
    assert result[2]["value"] == 9200.0


@pytest.mark.asyncio
async def test_get_goal_history_returns_empty_when_no_data(db_session):
    """get_goal_history returns [] when no rows exist for the metric."""
    result = await get_goal_history(db_session, "no-such-user", "steps", days=30)
    assert result == []


@pytest.mark.asyncio
async def test_get_goal_history_excludes_stale_rows(db_session):
    """get_goal_history does not include rows where is_stale=True."""
    user_id = "hist-user-002"
    today = date.today()
    fresh_day = today - timedelta(days=2)
    stale_day = today - timedelta(days=4)

    await _seed_summary(db_session, user_id, fresh_day, "weight_kg", 75.0, is_stale=False)
    await _seed_summary(db_session, user_id, stale_day, "weight_kg", 76.0, is_stale=True)

    result = await get_goal_history(db_session, user_id, "weight_kg", days=30)

    assert len(result) == 1
    assert result[0]["date"] == str(fresh_day)
    assert result[0]["value"] == 75.0


@pytest.mark.asyncio
async def test_get_goal_history_respects_days_window(db_session):
    """get_goal_history excludes rows outside the requested day window."""
    user_id = "hist-user-003"
    today = date.today()
    recent = today - timedelta(days=7)
    old = today - timedelta(days=35)  # outside 30-day window

    await _seed_summary(db_session, user_id, recent, "sleep_hours", 7.5)
    await _seed_summary(db_session, user_id, old, "sleep_hours", 6.0)

    result = await get_goal_history(db_session, user_id, "sleep_hours", days=30)

    assert len(result) == 1
    assert result[0]["date"] == str(recent)
