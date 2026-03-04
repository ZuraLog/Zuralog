"""
Zuralog Cloud Brain — StreakTracker Service Tests.

Validates streak increment, freeze, reset, and milestone logic using an
in-memory SQLite database so no external infrastructure is required.

Test coverage:
    - First activity creates streak with count=1
    - Consecutive day increments streak
    - Same day does not change count (idempotent)
    - Gap day with freeze available: freeze used, streak preserved
    - Gap day without freeze: streak resets to 1
    - Milestone detection returns correct milestone at count=7
    - Weekly freeze reset increments freeze_count and clears flags
"""

from datetime import date, timedelta

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.models.user_streak import StreakType, UserStreak
from app.services.streak_tracker import StreakTracker


# ---------------------------------------------------------------------------
# In-memory SQLite fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def db_session():
    """Provide a fresh async SQLite session with the streak table."""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

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
    streak = await tracker.record_activity("user-1", StreakType.ENGAGEMENT, db_session)

    assert streak.current_count == 1
    assert streak.longest_count == 1
    assert streak.last_activity_date == date.today()


@pytest.mark.asyncio
async def test_consecutive_day_increments_streak(db_session, tracker):
    """Activity on the day after last_activity_date increments current_count."""
    yesterday = date.today() - timedelta(days=1)
    await _seed_streak(db_session, "user-2", StreakType.ENGAGEMENT, 5, yesterday)

    streak = await tracker.record_activity("user-2", StreakType.ENGAGEMENT, db_session)

    assert streak.current_count == 6
    assert streak.last_activity_date == date.today()


@pytest.mark.asyncio
async def test_same_day_is_idempotent(db_session, tracker):
    """Recording activity twice on the same day does not change the count."""
    today = date.today()
    await _seed_streak(db_session, "user-3", StreakType.ENGAGEMENT, 3, today)

    streak = await tracker.record_activity("user-3", StreakType.ENGAGEMENT, db_session)

    assert streak.current_count == 3  # unchanged


@pytest.mark.asyncio
async def test_gap_day_with_freeze_preserves_streak(db_session, tracker):
    """Gap of 2+ days uses a freeze if available and preserves streak count."""
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

    streak = await tracker.record_activity("user-4", StreakType.ENGAGEMENT, db_session)

    assert streak.current_count == original_count  # preserved
    assert streak.freeze_count == 0  # consumed
    assert streak.freeze_used_this_week is True
    assert streak.last_activity_date == date.today()


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

    streak = await tracker.record_activity("user-5", StreakType.ENGAGEMENT, db_session)

    assert streak.current_count == 1
    assert streak.last_activity_date == date.today()


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

    streak = await tracker.record_activity("user-6", StreakType.ENGAGEMENT, db_session)

    assert streak.current_count == 1  # reset
    assert streak.freeze_count == 1  # not consumed


@pytest.mark.asyncio
async def test_longest_count_updated(db_session, tracker):
    """current_count exceeding longest_count updates longest_count."""
    yesterday = date.today() - timedelta(days=1)
    await _seed_streak(db_session, "user-7", StreakType.STEPS, 9, yesterday)

    streak = await tracker.record_activity("user-7", StreakType.STEPS, db_session)

    assert streak.current_count == 10
    assert streak.longest_count == 10


# ---------------------------------------------------------------------------
# check_milestones tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_milestone_7_detected(db_session, tracker):
    """check_milestones returns [7] when current_count == 7."""
    yesterday = date.today() - timedelta(days=1)
    await _seed_streak(db_session, "user-8", StreakType.ENGAGEMENT, 6, yesterday)

    streak = await tracker.record_activity("user-8", StreakType.ENGAGEMENT, db_session)
    milestones = await tracker.check_milestones(streak)

    assert 7 in milestones


@pytest.mark.asyncio
async def test_no_milestone_at_arbitrary_count(db_session, tracker):
    """check_milestones returns empty list for a non-milestone count."""
    yesterday = date.today() - timedelta(days=1)
    await _seed_streak(db_session, "user-9", StreakType.ENGAGEMENT, 10, yesterday)

    streak = await tracker.record_activity("user-9", StreakType.ENGAGEMENT, db_session)
    milestones = await tracker.check_milestones(streak)

    assert milestones == []


@pytest.mark.asyncio
async def test_milestone_30_detected(db_session, tracker):
    """check_milestones returns [30] when current_count == 30."""
    streak = UserStreak(
        user_id="user-10",
        streak_type=StreakType.ENGAGEMENT.value,
        current_count=30,
        longest_count=30,
    )
    milestones = await tracker.check_milestones(streak)
    assert 30 in milestones


# ---------------------------------------------------------------------------
# get_streaks tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_streaks_returns_all_types(db_session, tracker):
    """get_streaks returns rows for all types that have been activated."""
    today = date.today()
    for st in StreakType:
        await _seed_streak(db_session, "user-11", st, 1, today)

    streaks = await tracker.get_streaks("user-11", db_session)
    types = {s.streak_type for s in streaks}
    assert types == {st.value for st in StreakType}


@pytest.mark.asyncio
async def test_get_streaks_empty_for_new_user(db_session, tracker):
    """get_streaks returns empty list for a user with no activity."""
    streaks = await tracker.get_streaks("user-new", db_session)
    assert streaks == []


# ---------------------------------------------------------------------------
# reset_weekly_freezes tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_reset_weekly_freezes_increments_count(db_session, tracker):
    """reset_weekly_freezes adds 1 freeze token (up to max 2)."""
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

    await tracker.reset_weekly_freezes(db_session)

    streaks = await tracker.get_streaks("user-12", db_session)
    assert streaks[0].freeze_count == 1
    assert streaks[0].freeze_used_this_week is False


@pytest.mark.asyncio
async def test_reset_weekly_freezes_does_not_exceed_max(db_session, tracker):
    """reset_weekly_freezes does not push freeze_count above 2."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-13",
        StreakType.ENGAGEMENT,
        3,
        today,
        freeze_count=2,  # already at max
    )

    await tracker.reset_weekly_freezes(db_session)

    streaks = await tracker.get_streaks("user-13", db_session)
    assert streaks[0].freeze_count == 2  # unchanged — already capped


@pytest.mark.asyncio
async def test_reset_weekly_freezes_clears_used_flag(db_session, tracker):
    """reset_weekly_freezes resets freeze_used_this_week to False."""
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

    await tracker.reset_weekly_freezes(db_session)

    streaks = await tracker.get_streaks("user-14", db_session)
    assert streaks[0].freeze_used_this_week is False


# ---------------------------------------------------------------------------
# use_freeze tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_use_freeze_decrements_count(db_session, tracker):
    """use_freeze reduces freeze_count by 1 and marks weekly flag."""
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

    streak = await tracker.use_freeze("user-15", StreakType.STEPS, db_session)

    assert streak.freeze_count == 1
    assert streak.freeze_used_this_week is True


@pytest.mark.asyncio
async def test_use_freeze_raises_when_none_available(db_session, tracker):
    """use_freeze raises ValueError when freeze_count is 0."""
    today = date.today()
    await _seed_streak(
        db_session,
        "user-16",
        StreakType.WORKOUTS,
        3,
        today,
        freeze_count=0,
    )

    with pytest.raises(ValueError, match="No freeze tokens"):
        await tracker.use_freeze("user-16", StreakType.WORKOUTS, db_session)


@pytest.mark.asyncio
async def test_use_freeze_raises_when_already_used(db_session, tracker):
    """use_freeze raises ValueError when freeze already used this week."""
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

    with pytest.raises(ValueError, match="already used"):
        await tracker.use_freeze("user-17", StreakType.ENGAGEMENT, db_session)
