"""
Zuralog Cloud Brain — AchievementTracker Service Tests.

Validates the core achievement unlocking logic using an in-memory
SQLite database so no external infrastructure is required.

Test coverage:
    - First integration event unlocks "first_integration"
    - Third integration event unlocks "connected_3"
    - Same achievement is not unlocked twice (idempotent)
    - Streak 7 event unlocks "streak_7"
    - get_all_achievements returns all registry keys with state
    - get_recent_achievements returns most recently unlocked first
"""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.models.achievement import ACHIEVEMENT_REGISTRY, Achievement
from app.services.achievement_tracker import AchievementTracker


# ---------------------------------------------------------------------------
# In-memory SQLite fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def db_session():
    """Provide a fresh async SQLite session with the achievement table.

    Uses SQLite's in-memory engine so tests are hermetic and fast.
    """
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture
async def tracker(db_session):
    """Provide an AchievementTracker bound to the in-memory session."""
    return AchievementTracker(session=db_session)


# ---------------------------------------------------------------------------
# Tests: check_and_unlock
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_first_integration_unlocks(tracker):
    """integration_connected event with count=1 unlocks first_integration."""
    unlocked = await tracker.check_and_unlock(
        "user-1",
        "integration_connected",
        context={"connected_count": 1},
    )

    keys = [a.achievement_key for a in unlocked]
    assert "first_integration" in keys
    assert len(unlocked) == 1


@pytest.mark.asyncio
async def test_third_integration_unlocks_connected_3(tracker):
    """integration_connected with count=3 unlocks both achievements."""
    unlocked = await tracker.check_and_unlock(
        "user-2",
        "integration_connected",
        context={"connected_count": 3},
    )

    keys = [a.achievement_key for a in unlocked]
    assert "first_integration" in keys
    assert "connected_3" in keys
    assert len(unlocked) == 2


@pytest.mark.asyncio
async def test_idempotent_no_double_unlock(tracker):
    """Triggering the same event twice does not unlock the achievement twice."""
    ctx = {"connected_count": 1}

    first = await tracker.check_and_unlock("user-3", "integration_connected", ctx)
    assert len(first) == 1

    second = await tracker.check_and_unlock("user-3", "integration_connected", ctx)
    assert len(second) == 0  # already unlocked — no-op


@pytest.mark.asyncio
async def test_streak_7_unlocks(tracker):
    """streak_updated event with streak_count=7 unlocks streak_7."""
    unlocked = await tracker.check_and_unlock(
        "user-4",
        "streak_updated",
        context={"streak_count": 7},
    )

    keys = [a.achievement_key for a in unlocked]
    assert "streak_7" in keys


@pytest.mark.asyncio
async def test_streak_30_unlocks_multiple(tracker):
    """streak_count=30 unlocks streak_7 and streak_30 simultaneously."""
    unlocked = await tracker.check_and_unlock(
        "user-5",
        "streak_updated",
        context={"streak_count": 30},
    )

    keys = [a.achievement_key for a in unlocked]
    assert "streak_7" in keys
    assert "streak_30" in keys
    assert "streak_90" not in keys


@pytest.mark.asyncio
async def test_first_chat_unlocks(tracker):
    """chat_started event unlocks first_chat."""
    unlocked = await tracker.check_and_unlock("user-6", "chat_started")
    assert any(a.achievement_key == "first_chat" for a in unlocked)


@pytest.mark.asyncio
async def test_first_insight_unlocks(tracker):
    """insight_received event unlocks first_insight."""
    unlocked = await tracker.check_and_unlock("user-7", "insight_received")
    assert any(a.achievement_key == "first_insight" for a in unlocked)


@pytest.mark.asyncio
async def test_first_goal_unlocks(tracker):
    """goal_created event unlocks first_goal."""
    unlocked = await tracker.check_and_unlock("user-8", "goal_created")
    assert any(a.achievement_key == "first_goal" for a in unlocked)


@pytest.mark.asyncio
async def test_goal_completed_5_unlocks(tracker):
    """goal_completed with completed_count=5 unlocks goals_5_complete."""
    unlocked = await tracker.check_and_unlock(
        "user-9",
        "goal_completed",
        context={"completed_count": 5},
    )
    assert any(a.achievement_key == "goals_5_complete" for a in unlocked)


@pytest.mark.asyncio
async def test_overachiever_unlocks(tracker):
    """goal_completed with exceeded_by_pct>=20 unlocks overachiever."""
    unlocked = await tracker.check_and_unlock(
        "user-10",
        "goal_completed",
        context={"completed_count": 1, "exceeded_by_pct": 25},
    )
    keys = [a.achievement_key for a in unlocked]
    assert "overachiever" in keys


@pytest.mark.asyncio
async def test_overachiever_not_unlocked_below_threshold(tracker):
    """exceeded_by_pct=10 does not unlock overachiever."""
    unlocked = await tracker.check_and_unlock(
        "user-11",
        "goal_completed",
        context={"completed_count": 1, "exceeded_by_pct": 10},
    )
    keys = [a.achievement_key for a in unlocked]
    assert "overachiever" not in keys


# ---------------------------------------------------------------------------
# Tests: get_all_achievements
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_all_achievements_returns_all_keys(tracker):
    """get_all_achievements returns one entry per registry key."""
    all_achievements = await tracker.get_all_achievements("user-20")

    returned_keys = {a["achievement_key"] for a in all_achievements}
    registry_keys = set(ACHIEVEMENT_REGISTRY.keys())

    assert returned_keys == registry_keys


@pytest.mark.asyncio
async def test_get_all_achievements_locked_by_default(tracker):
    """All achievements are locked for a user who has triggered nothing."""
    all_achievements = await tracker.get_all_achievements("user-21")

    assert all(not a["unlocked"] for a in all_achievements)
    assert all(a["unlocked_at"] is None for a in all_achievements)


@pytest.mark.asyncio
async def test_get_all_achievements_shows_unlocked_state(tracker):
    """After unlocking, get_all_achievements reflects the updated state."""
    await tracker.check_and_unlock("user-22", "chat_started")

    all_achievements = await tracker.get_all_achievements("user-22")
    first_chat_entry = next(a for a in all_achievements if a["achievement_key"] == "first_chat")

    assert first_chat_entry["unlocked"] is True
    assert first_chat_entry["unlocked_at"] is not None


@pytest.mark.asyncio
async def test_get_all_achievements_has_metadata(tracker):
    """Each achievement dict includes title, description, category, icon."""
    all_achievements = await tracker.get_all_achievements("user-23")

    for a in all_achievements:
        assert "title" in a
        assert "description" in a
        assert "category" in a
        assert "icon" in a


# ---------------------------------------------------------------------------
# Tests: get_recent_achievements
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_recent_achievements_empty(tracker):
    """Returns empty list when user has no unlocked achievements."""
    recent = await tracker.get_recent_achievements("user-30")
    assert recent == []


@pytest.mark.asyncio
async def test_get_recent_achievements_order(db_session):
    """get_recent_achievements returns most recently unlocked first."""
    from datetime import datetime, timedelta, timezone

    # Manually insert two achievements with different unlock times
    earlier = Achievement(
        user_id="user-31",
        achievement_key="first_chat",
        unlocked_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )
    later = Achievement(
        user_id="user-31",
        achievement_key="first_insight",
        unlocked_at=datetime(2026, 1, 2, tzinfo=timezone.utc),
    )
    db_session.add(earlier)
    db_session.add(later)
    await db_session.commit()

    tracker = AchievementTracker(session=db_session)
    recent = await tracker.get_recent_achievements("user-31")

    assert len(recent) == 2
    # Most recent first
    assert recent[0].achievement_key == "first_insight"
    assert recent[1].achievement_key == "first_chat"


@pytest.mark.asyncio
async def test_get_recent_achievements_respects_limit(db_session):
    """get_recent_achievements respects the limit parameter."""
    from datetime import datetime, timezone

    for i, key in enumerate(list(ACHIEVEMENT_REGISTRY.keys())[:6]):
        db_session.add(
            Achievement(
                user_id="user-32",
                achievement_key=key,
                unlocked_at=datetime(2026, 1, i + 1, tzinfo=timezone.utc),
            )
        )
    await db_session.commit()

    tracker = AchievementTracker(session=db_session)
    recent = await tracker.get_recent_achievements("user-32", limit=3)

    assert len(recent) == 3
