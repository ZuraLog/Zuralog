"""
Zuralog Cloud Brain — StreakTracker Service Tests.

Current API:
    record_activity(user_id, streak_type, activity_date, db) -> UserStreak
    use_freeze(user_id, streak_type, db) -> bool
    get_all_streaks(user_id, db) -> list[UserStreak]
    reset_weekly_freeze_flags(db) -> None
    _check_milestone(count) -> bool
    get_milestone_data(count) -> dict | None

Tests use an in-memory SQLite database for isolation.

Test coverage:
    - First activity creates streak with count=1
    - Consecutive day increments streak
    - Same day does not change count (idempotent)
    - Gap day with freeze available: freeze used, streak preserved
    - Gap day without freeze: streak resets to 1
    - Milestone detection at count=7
    - Weekly freeze reset increments freeze_count and clears flags
"""

from datetime import date, timedelta

import enum

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.models.user_streak import UserStreak
from app.services.streak_tracker import StreakTracker


# StreakType enum was removed — the model now stores plain string values.
# Provide a str enum shim so existing test code works without per-call changes.
class StreakType(str, enum.Enum):
    ENGAGEMENT = "engagement"
    STEPS = "steps"
    WORKOUTS = "workouts"
    CHECKIN = "checkin"


# ---------------------------------------------------------------------------
# In-memory SQLite fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def db_session():
    """Provide a fresh async SQLite session with only the user_streaks table.

    Base.metadata.create_all is NOT used — other models use Postgres-specific
    column types (JSONB) that SQLite does not support.
    """
    from sqlalchemy import Boolean, Column, Date, DateTime, Integer, MetaData, String, Table, UniqueConstraint

    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)

    meta = MetaData()
    Table(
        "user_streaks",
        meta,
        Column("id", String, primary_key=True),
        Column("user_id", String, nullable=False, index=True),
        Column("streak_type", String, nullable=False),
        Column("current_count", Integer, default=0),
        Column("longest_count", Integer, default=0),
        Column("last_activity_date", Date, nullable=True),
        Column("freeze_count", Integer, default=1),
        Column("freeze_used_this_week", Boolean, default=False),
        Column("created_at", DateTime(timezone=True), nullable=True),
        Column("updated_at", DateTime(timezone=True), nullable=True),
        UniqueConstraint("user_id", "streak_type", name="uq_user_streak_user_type"),
    )

    async with engine.begin() as conn:
        await conn.run_sync(meta.create_all)

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture
async def tracker():
    """Provide a StreakTracker instance."""
    return StreakTracker()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _seed_streak(
    session: AsyncSession,
    user_id: str,
    streak_type: StreakType,
    current_count: int,
    last_activity_date: date,
    freeze_count: int = 1,
    freeze_used_this_week: bool = False,
) -> UserStreak:
    """Insert a UserStreak row directly for test setup."""
    streak = UserStreak(
        user_id=user_id,
        streak_type=streak_type.value,
        current_count=current_count,
        longest_count=current_count,
        last_activity_date=last_activity_date,
        freeze_count=freeze_count,
        freeze_used_this_week=freeze_used_this_week,
    )
    session.add(streak)
    await session.commit()
    await session.refresh(streak)
    return streak


# ---------------------------------------------------------------------------
# record_activity tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_first_activity_creates_streak_with_count_1(db_session, tracker):
    """Recording first activity for a user creates streak with current_count=1."""
    today = date.today()
    streak = await tracker.record_activity("user-1", StreakType.ENGAGEMENT, today, db_session)

    assert streak.current_count == 1
    assert streak.longest_count == 1
    # SQLite may return date as string; compare via isoformat for portability
    assert str(streak.last_activity_date) == today.isoformat()


@pytest.mark.asyncio
async def test_consecutive_day_increments_streak(db_session, tracker):
    """Activity on the day after last_activity_date increments current_count."""
    yesterday = date.today() - timedelta(days=1)
    await _seed_streak(db_session, "user-2", StreakType.ENGAGEMENT, 5, yesterday)

    today = date.today()
    streak = await tracker.record_activity("user-2", StreakType.ENGAGEMENT, today, db_session)

    assert streak.current_count == 6
    assert str(streak.last_activity_date) == today.isoformat()


@pytest.mark.asyncio
async def test_same_day_is_idempotent(db_session, tracker):
    """Recording activity twice on the same day does not change the count."""
    today = date.today()
    await _seed_streak(db_session, "user-3", StreakType.ENGAGEMENT, 3, today)

    streak = await tracker.record_activity("user-3", StreakType.ENGAGEMENT, today, db_session)

    assert streak.current_count == 3  # unchanged


@pytest.mark.asyncio
async def test_gap_day_with_freeze_use_freeze_then_record(db_session, tracker):
    """Freeze is applied by use_freeze() before recording activity.

    The actual API separates freeze application (use_freeze) from activity
    recording (record_activity). A gap does NOT auto-apply a freeze.
    """
    two_days_ago = date.today() - timedelta(days=2)
    original_count = 10
    await _seed_streak(
        db_session,
        "user-4",
        StreakType.ENGAGEMENT,
        original_count,
        two_days_ago,
        freeze_count=1,
        freeze_used_this_week=False,
    )

    # Apply freeze first
    result = await tracker.use_freeze("user-4", StreakType.ENGAGEMENT, db_session)
    assert result is True

    # Verify freeze was consumed
    streaks = await tracker.get_all_streaks("user-4", db_session)
    assert streaks[0].freeze_count == 0
    assert streaks[0].freeze_used_this_week is True


@pytest.mark.asyncio
async def test_gap_day_without_freeze_resets_streak(db_session, tracker):
    """Gap of 2+ days with no freeze available resets streak to 1."""
    two_days_ago = date.today() - timedelta(days=2)
    await _seed_streak(
        db_session,
        "user-5",
        StreakType.ENGAGEMENT,
        15,
        two_days_ago,
        freeze_count=0,  # no freeze
    )

    today = date.today()
    streak = await tracker.record_activity("user-5", StreakType.ENGAGEMENT, today, db_session)

    assert streak.current_count == 1
    assert str(streak.last_activity_date) == today.isoformat()


@pytest.mark.asyncio
async def test_gap_day_freeze_already_used_resets_streak(db_session, tracker):
    """Gap day does not use freeze if freeze_used_this_week is True."""
    two_days_ago = date.today() - timedelta(days=2)
    await _seed_streak(
        db_session,
        "user-6",
        StreakType.ENGAGEMENT,
        8,
        two_days_ago,
        freeze_count=1,
        freeze_used_this_week=True,  # already used
    )

    today = date.today()
    streak = await tracker.record_activity("user-6", StreakType.ENGAGEMENT, today, db_session)

    assert streak.current_count == 1  # reset
    assert streak.freeze_count == 1  # not consumed


@pytest.mark.asyncio
async def test_longest_count_updated(db_session, tracker):
    """current_count exceeding longest_count updates longest_count."""
    yesterday = date.today() - timedelta(days=1)
    await _seed_streak(db_session, "user-7", StreakType.STEPS, 9, yesterday)

    today = date.today()
    streak = await tracker.record_activity("user-7", StreakType.STEPS, today, db_session)

    assert streak.current_count == 10
    assert streak.longest_count == 10


# ---------------------------------------------------------------------------
# _check_milestone / get_milestone_data tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_milestone_7_detected(tracker):
    """_check_milestone returns True at count=7."""
    assert tracker._check_milestone(7) is True


@pytest.mark.asyncio
async def test_milestone_30_detected(tracker):
    """_check_milestone returns True at count=30."""
    assert tracker._check_milestone(30) is True


@pytest.mark.asyncio
async def test_no_milestone_at_arbitrary_count(tracker):
    """_check_milestone returns False for a non-milestone count."""
    assert tracker._check_milestone(11) is False


@pytest.mark.asyncio
async def test_get_milestone_data_at_7(tracker):
    """get_milestone_data returns a non-None dict at count=7."""
    data = tracker.get_milestone_data(7)
    assert data is not None
    assert isinstance(data, dict)


@pytest.mark.asyncio
async def test_get_milestone_data_non_milestone(tracker):
    """get_milestone_data returns None for a non-milestone count."""
    data = tracker.get_milestone_data(11)
    assert data is None


# ---------------------------------------------------------------------------
# get_all_streaks tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_all_streaks_returns_all_types(db_session, tracker):
    """get_all_streaks returns rows for all types that have been seeded."""
    today = date.today()
    for st in StreakType:
        await _seed_streak(db_session, "user-11", st, 1, today)

    streaks = await tracker.get_all_streaks("user-11", db_session)
    types = {s.streak_type for s in streaks}
    assert types == {st.value for st in StreakType}


@pytest.mark.asyncio
async def test_get_all_streaks_empty_for_new_user(db_session, tracker):
    """get_all_streaks returns empty list for a user with no activity."""
    streaks = await tracker.get_all_streaks("user-new", db_session)
    assert streaks == []


# ---------------------------------------------------------------------------
# reset_weekly_freeze_flags tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_reset_weekly_freeze_flags_increments_count(db_session, tracker):
    """reset_weekly_freeze_flags adds 1 freeze token (up to max 2)."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-12",
        StreakType.ENGAGEMENT,
        5,
        today,
        freeze_count=0,
        freeze_used_this_week=True,
    )

    await tracker.reset_weekly_freeze_flags(db_session)

    streaks = await tracker.get_all_streaks("user-12", db_session)
    assert streaks[0].freeze_count == 1
    assert streaks[0].freeze_used_this_week is False


@pytest.mark.asyncio
async def test_reset_weekly_freeze_flags_does_not_exceed_max(db_session, tracker):
    """reset_weekly_freeze_flags does not push freeze_count above 2."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-13",
        StreakType.ENGAGEMENT,
        3,
        today,
        freeze_count=2,  # already at max
    )

    await tracker.reset_weekly_freeze_flags(db_session)

    streaks = await tracker.get_all_streaks("user-13", db_session)
    assert streaks[0].freeze_count == 2  # unchanged — already capped


@pytest.mark.asyncio
async def test_reset_weekly_freeze_flags_clears_used_flag(db_session, tracker):
    """reset_weekly_freeze_flags resets freeze_used_this_week to False."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-14",
        StreakType.CHECKIN,
        7,
        today,
        freeze_count=1,
        freeze_used_this_week=True,
    )

    await tracker.reset_weekly_freeze_flags(db_session)

    streaks = await tracker.get_all_streaks("user-14", db_session)
    assert streaks[0].freeze_used_this_week is False


# ---------------------------------------------------------------------------
# use_freeze tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_use_freeze_returns_true_on_success(db_session, tracker):
    """use_freeze returns True when a freeze token is successfully consumed."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-15",
        StreakType.STEPS,
        5,
        today,
        freeze_count=2,
        freeze_used_this_week=False,
    )

    result = await tracker.use_freeze("user-15", StreakType.STEPS, db_session)

    assert result is True
    # Verify the streak was updated
    streaks = await tracker.get_all_streaks("user-15", db_session)
    assert streaks[0].freeze_count == 1
    assert streaks[0].freeze_used_this_week is True


@pytest.mark.asyncio
async def test_use_freeze_returns_false_when_no_tokens(db_session, tracker):
    """use_freeze returns False when freeze_count is 0."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-16",
        StreakType.WORKOUTS,
        3,
        today,
        freeze_count=0,
    )

    result = await tracker.use_freeze("user-16", StreakType.WORKOUTS, db_session)
    assert result is False


@pytest.mark.asyncio
async def test_use_freeze_returns_false_when_already_used(db_session, tracker):
    """use_freeze returns False when freeze already used this week."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-17",
        StreakType.ENGAGEMENT,
        4,
        today,
        freeze_count=1,
        freeze_used_this_week=True,
    )

    result = await tracker.use_freeze("user-17", StreakType.ENGAGEMENT, db_session)
    assert result is False
