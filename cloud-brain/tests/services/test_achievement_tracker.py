"""
Zuralog Cloud Brain — AchievementTracker Service Tests.

Validates the core achievement unlocking logic using an in-memory
SQLite database so no external infrastructure is required.

Test coverage:
    - unlock returns True on first unlock, False on repeat
    - unlock is idempotent (no-op when already unlocked)
    - check_and_unlock_streak unlocks correct milestone keys
    - check_and_unlock_streak returns empty list below threshold
    - get_all returns all registry entries with locked/unlocked state
    - get_all reflects state after unlock
"""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.models.achievement import Achievement
from app.services.achievement_tracker import ACHIEVEMENT_REGISTRY, AchievementTracker


# ---------------------------------------------------------------------------
# In-memory SQLite fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def db_session():
    """Provide a fresh async SQLite session with only the achievement table."""
    from sqlalchemy import MetaData, Table, String, DateTime, Column, UniqueConstraint

    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)

    # Create only the achievements table using plain SQLAlchemy types.
    # Using Base.metadata.create_all would fail because other models use
    # Postgres-specific types (JSONB) that SQLite does not support.
    meta = MetaData()
    Table(
        "achievements",
        meta,
        Column("id", String, primary_key=True),
        Column("user_id", String, nullable=False, index=True),
        Column("achievement_key", String, nullable=False),
        Column("unlocked_at", DateTime(timezone=True), nullable=True),
        Column("created_at", DateTime(timezone=True), nullable=True),
        UniqueConstraint("user_id", "achievement_key", name="uq_achievement_user_key"),
    )

    async with engine.begin() as conn:
        await conn.run_sync(meta.create_all)

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture
async def tracker():
    """Provide an AchievementTracker (stateless service)."""
    return AchievementTracker()


# ---------------------------------------------------------------------------
# Tests: unlock
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_unlock_returns_true_on_first_unlock(tracker, db_session):
    """unlock returns True when achievement is newly unlocked."""
    result = await tracker.unlock("user-1", "first_chat", db_session)
    assert result is True


@pytest.mark.asyncio
async def test_unlock_is_idempotent(tracker, db_session):
    """unlock returns False when achievement is already unlocked."""
    await tracker.unlock("user-2", "first_chat", db_session)
    second = await tracker.unlock("user-2", "first_chat", db_session)
    assert second is False


@pytest.mark.asyncio
async def test_unlock_unknown_key_returns_false(tracker, db_session):
    """unlock returns False for keys not in the registry."""
    result = await tracker.unlock("user-3", "nonexistent_achievement_key", db_session)
    assert result is False


@pytest.mark.asyncio
async def test_unlock_persists_achievement(tracker, db_session):
    """After unlock, get_all reflects the achievement as unlocked."""
    await tracker.unlock("user-4", "first_insight", db_session)
    all_achievements = await tracker.get_all("user-4", db_session)
    insight_entry = next(a for a in all_achievements if a["key"] == "first_insight")
    assert insight_entry["is_unlocked"] is True
    assert insight_entry["unlocked_at"] is not None


# ---------------------------------------------------------------------------
# Tests: check_and_unlock_streak
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_streak_7_unlocks_streak_7_key(tracker, db_session):
    """streak_count=7 unlocks the streak_7 achievement."""
    newly_unlocked = await tracker.check_and_unlock_streak("user-10", 7, db_session)
    assert "streak_7" in newly_unlocked


@pytest.mark.asyncio
async def test_streak_30_unlocks_both_milestones(tracker, db_session):
    """streak_count=30 unlocks streak_7 and streak_30 simultaneously."""
    newly_unlocked = await tracker.check_and_unlock_streak("user-11", 30, db_session)
    assert "streak_7" in newly_unlocked
    assert "streak_30" in newly_unlocked
    assert "streak_90" not in newly_unlocked


@pytest.mark.asyncio
async def test_streak_6_unlocks_nothing(tracker, db_session):
    """streak_count=6 does not reach any milestone."""
    newly_unlocked = await tracker.check_and_unlock_streak("user-12", 6, db_session)
    assert newly_unlocked == []


@pytest.mark.asyncio
async def test_streak_idempotent_on_second_call(tracker, db_session):
    """Second call with same streak count does not re-unlock."""
    first = await tracker.check_and_unlock_streak("user-13", 7, db_session)
    assert "streak_7" in first

    second = await tracker.check_and_unlock_streak("user-13", 7, db_session)
    assert "streak_7" not in second  # already unlocked


@pytest.mark.asyncio
async def test_streak_90_unlocks_three_milestones(tracker, db_session):
    """streak_count=90 unlocks streak_7, streak_30, and streak_90."""
    newly_unlocked = await tracker.check_and_unlock_streak("user-14", 90, db_session)
    assert "streak_7" in newly_unlocked
    assert "streak_30" in newly_unlocked
    assert "streak_90" in newly_unlocked


# ---------------------------------------------------------------------------
# Tests: get_all
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_all_returns_all_registry_entries(tracker, db_session):
    """get_all returns one entry per achievement key in the registry."""
    all_achievements = await tracker.get_all("user-20", db_session)

    returned_keys = {a["key"] for a in all_achievements}
    # Collect all keys from the nested registry structure
    registry_keys = {entry["key"] for entries in ACHIEVEMENT_REGISTRY.values() for entry in entries}

    assert returned_keys == registry_keys


@pytest.mark.asyncio
async def test_get_all_all_locked_by_default(tracker, db_session):
    """All achievements are locked for a user with no activity."""
    all_achievements = await tracker.get_all("user-21", db_session)

    assert all(not a["is_unlocked"] for a in all_achievements)
    assert all(a["unlocked_at"] is None for a in all_achievements)


@pytest.mark.asyncio
async def test_get_all_shows_unlocked_state_after_unlock(tracker, db_session):
    """After unlocking, get_all reflects the updated state."""
    await tracker.unlock("user-22", "first_chat", db_session)

    all_achievements = await tracker.get_all("user-22", db_session)
    first_chat_entry = next(a for a in all_achievements if a["key"] == "first_chat")

    assert first_chat_entry["is_unlocked"] is True
    assert first_chat_entry["unlocked_at"] is not None


@pytest.mark.asyncio
async def test_get_all_has_required_metadata_fields(tracker, db_session):
    """Each achievement dict includes name, description, and category."""
    all_achievements = await tracker.get_all("user-23", db_session)

    for a in all_achievements:
        assert "name" in a
        assert "description" in a
        assert "category" in a
        assert "key" in a
        assert "is_unlocked" in a
