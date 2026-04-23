"""
Tests for nutrition_streak_task — evaluate_nutrition_streak_for_user.

Tests verify:
1. When all nutrition goals are met → streak is incremented (or created at 1).
2. When a calorie goal (max type) is exceeded → None is returned.
3. When a protein goal (min type) is not met → None is returned.
4. When no goals exist → None is returned.
5. When no daily summary exists → None is returned.
6. Mixed goals: all met → streak returned.
7. Mixed goals: one failed → None returned.

All tests are pure unit tests using AsyncMock — no HTTP client, no real DB.
"""

from __future__ import annotations

import uuid
from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# Helpers to build lightweight mock objects
# ---------------------------------------------------------------------------


def _goal(metric: str, target_value: float, is_active: bool = True) -> MagicMock:
    g = MagicMock()
    g.metric = metric
    g.target_value = target_value
    g.is_active = is_active
    return g


def _summary(
    total_calories: float = 0.0,
    total_protein_g: float = 0.0,
    total_carbs_g: float = 0.0,
    total_fat_g: float = 0.0,
    total_fiber_g: float = 0.0,
    total_sodium_mg: float = 0.0,
    total_sugar_g: float = 0.0,
) -> MagicMock:
    s = MagicMock()
    s.total_calories = total_calories
    s.total_protein_g = total_protein_g
    s.total_carbs_g = total_carbs_g
    s.total_fat_g = total_fat_g
    s.total_fiber_g = total_fiber_g
    s.total_sodium_mg = total_sodium_mg
    s.total_sugar_g = total_sugar_g
    return s


def _streak(current_count: int = 1) -> MagicMock:
    s = MagicMock()
    s.current_count = current_count
    s.longest_count = current_count
    s.last_activity_date = None
    s.is_frozen = False
    s.freeze_count = 0
    s.freeze_used_this_week = False
    return s


# ---------------------------------------------------------------------------
# Async helpers
# ---------------------------------------------------------------------------


def _async_return(value):
    """Wrap a value in a coroutine that returns it, for AsyncMock.return_value."""
    async def _coro(*args, **kwargs):
        return value
    return _coro


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestEvaluateNutritionStreakForUser:
    """Unit tests for evaluate_nutrition_streak_for_user."""

    @pytest.mark.asyncio
    async def test_all_goals_met_creates_streak(self):
        """When all goals are satisfied, the function returns a streak object."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        # One protein goal (min) — met: actual 50g >= target 30g
        goals = [_goal("nutrition.daily_protein_g", 30.0)]
        summary = _summary(total_protein_g=50.0)
        streak = _streak(current_count=1)

        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=summary),
            ),
            patch(
                "app.tasks.nutrition_streak_task._upsert_streak",
                new=AsyncMock(return_value=streak),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is streak

    @pytest.mark.asyncio
    async def test_calorie_max_goal_exceeded_returns_none(self):
        """Calorie is a max goal — exceeding target means goals NOT met → None."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        # Max calorie goal of 2000 — actual is 2500 (over limit)
        goals = [_goal("nutrition.daily_calorie_limit", 2000.0)]
        summary = _summary(total_calories=2500.0)

        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=summary),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is None

    @pytest.mark.asyncio
    async def test_protein_min_goal_not_met_returns_none(self):
        """Protein is a min goal — falling short means goals NOT met → None."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        # Min protein goal of 150g — actual is 80g (below target)
        goals = [_goal("nutrition.daily_protein_g", 150.0)]
        summary = _summary(total_protein_g=80.0)

        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=summary),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is None

    @pytest.mark.asyncio
    async def test_no_active_goals_returns_none(self):
        """When there are no active nutrition goals, return None."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)
        mock_db = AsyncMock()

        with patch(
            "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
            new=AsyncMock(return_value=[]),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is None

    @pytest.mark.asyncio
    async def test_no_summary_returns_none(self):
        """When there is no daily nutrition summary, return None."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        goals = [_goal("nutrition.daily_protein_g", 30.0)]
        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=None),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is None

    @pytest.mark.asyncio
    async def test_all_goal_types_met_returns_streak(self):
        """All goal types (min protein/fiber, max calorie/fat/carbs/sodium/sugar) met → streak."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        goals = [
            _goal("nutrition.daily_calorie_limit", 2000.0),   # max — actual 1800 ✓
            _goal("nutrition.daily_protein_g", 100.0),        # min — actual 120 ✓
            _goal("nutrition.daily_carbs_g", 250.0),          # max — actual 200 ✓
            _goal("nutrition.daily_fat_g", 65.0),             # max — actual 60 ✓
            _goal("nutrition.daily_fiber_g", 25.0),           # min — actual 30 ✓
            _goal("nutrition.daily_sodium_mg", 2300.0),       # max — actual 1800 ✓
            _goal("nutrition.daily_sugar_g", 50.0),           # max — actual 40 ✓
        ]
        summary = _summary(
            total_calories=1800.0,
            total_protein_g=120.0,
            total_carbs_g=200.0,
            total_fat_g=60.0,
            total_fiber_g=30.0,
            total_sodium_mg=1800.0,
            total_sugar_g=40.0,
        )
        streak = _streak(current_count=5)

        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=summary),
            ),
            patch(
                "app.tasks.nutrition_streak_task._upsert_streak",
                new=AsyncMock(return_value=streak),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is streak
        assert result.current_count == 5

    @pytest.mark.asyncio
    async def test_one_goal_failed_among_many_returns_none(self):
        """Even if all but one goal is met, missing one returns None."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        goals = [
            _goal("nutrition.daily_calorie_limit", 2000.0),  # max — actual 2500 ✗
            _goal("nutrition.daily_protein_g", 100.0),       # min — actual 120 ✓
        ]
        summary = _summary(total_calories=2500.0, total_protein_g=120.0)

        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=summary),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is None

    @pytest.mark.asyncio
    async def test_unknown_metric_is_ignored(self):
        """An unrecognised metric key is safely ignored; other goals still evaluated."""
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        user_id = str(uuid.uuid4())
        today = date(2026, 4, 23)

        # One recognised min-goal (met) + one unknown metric (should be skipped)
        goals = [
            _goal("nutrition.daily_protein_g", 30.0),       # min — actual 50 ✓
            _goal("nutrition.daily_mystery_vitamin", 99.0),  # unknown — ignored
        ]
        summary = _summary(total_protein_g=50.0)
        streak = _streak(current_count=2)

        mock_db = AsyncMock()

        with (
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_goals",
                new=AsyncMock(return_value=goals),
            ),
            patch(
                "app.tasks.nutrition_streak_task._fetch_nutrition_summary",
                new=AsyncMock(return_value=summary),
            ),
            patch(
                "app.tasks.nutrition_streak_task._upsert_streak",
                new=AsyncMock(return_value=streak),
            ),
        ):
            result = await evaluate_nutrition_streak_for_user(
                db=mock_db, user_id=user_id, activity_date=today
            )

        assert result is streak


# ---------------------------------------------------------------------------
# Smoke test — task module is importable and callable
# ---------------------------------------------------------------------------


class TestNutritionStreakTaskSmoke:
    def test_module_is_importable(self):
        """The task module can be imported without errors."""
        import app.tasks.nutrition_streak_task  # noqa: F401

    def test_evaluate_function_is_callable(self):
        """evaluate_nutrition_streak_for_user is an async function."""
        import inspect
        from app.tasks.nutrition_streak_task import evaluate_nutrition_streak_for_user

        assert callable(evaluate_nutrition_streak_for_user)
        assert inspect.iscoroutinefunction(evaluate_nutrition_streak_for_user)
