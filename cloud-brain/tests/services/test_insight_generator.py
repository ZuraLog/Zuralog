"""
Tests for the Insight Task Pipeline.

Covers the end-to-end flow from health data → Celery task → DB row,
distinct from ``tests/test_insight_generator.py`` which tests the
analytics.InsightGenerator logic in isolation.

Test matrix:
    - Insight is saved to DB after successful generation.
    - Morning time slot generates a MORNING_BRIEFING insight.
    - Evening time slot does NOT generate a morning insight.
    - Anomaly insight is created when an anomaly is detected.
    - Complex insights are skipped when data is < 7 days old.
    - Duplicate prevention: same type + same day is not inserted twice.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.insight import Insight, InsightType
from app.tasks.insight_tasks import (
    _DATA_MATURITY_DAYS,
    _detect_anomalies,
    _generate_for_user,
    _insight_exists_today,
    _save_insight,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_insight(
    user_id: str = "user-abc",
    insight_type: InsightType = InsightType.ACTIVITY_PROGRESS,
    today: date | None = None,
) -> Insight:
    """Build a minimal in-memory Insight row (not DB-backed)."""
    today = today or date.today()
    return Insight(
        id=str(uuid.uuid4()),
        user_id=user_id,
        type=insight_type.value,
        title="Test title",
        body="Test body",
        priority=5,
        created_at=datetime(today.year, today.month, today.day, 9, 0, tzinfo=timezone.utc),
    )


def _mock_db_returning(rows: list) -> AsyncMock:
    """Create an AsyncMock session that returns rows from execute()."""
    db = AsyncMock()
    scalar_result = MagicMock()
    scalar_result.scalars.return_value.all.return_value = rows
    scalar_result.scalar_one.return_value = len(rows)
    scalar_result.scalar_one_or_none.return_value = rows[0] if rows else None
    db.execute.return_value = scalar_result
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


# ---------------------------------------------------------------------------
# Test: insight saved to DB after generation
# ---------------------------------------------------------------------------


class TestInsightSavedToDb:
    """_save_insight should persist an Insight row and return it."""

    @pytest.mark.asyncio
    async def test_save_insight_calls_db_add_and_commit(self):
        """A new insight should be added and committed once."""
        saved_insight = _make_insight()

        async def _fake_exists(user_id, insight_type, today):
            return False  # no duplicate

        with (
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                side_effect=_fake_exists,
            ),
            patch("app.tasks.insight_tasks.async_session") as mock_session_ctx,
        ):
            mock_db = AsyncMock()
            mock_db.__aenter__ = AsyncMock(return_value=mock_db)
            mock_db.__aexit__ = AsyncMock(return_value=False)
            mock_db.add = MagicMock()
            mock_db.commit = AsyncMock()
            mock_db.refresh = AsyncMock(side_effect=lambda obj: setattr(obj, "id", saved_insight.id))
            mock_session_ctx.return_value = mock_db

            result = await _save_insight(
                user_id="user-1",
                insight_type=InsightType.ACTIVITY_PROGRESS,
                title="Steps update",
                body="You walked 8 000 steps today.",
                priority=5,
            )

        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited_once()
        assert isinstance(result, Insight)

    @pytest.mark.asyncio
    async def test_save_insight_skips_duplicate(self):
        """If an insight already exists today, _save_insight should skip DB write."""

        async def _fake_exists(user_id, insight_type, today):
            return True  # already exists

        with patch(
            "app.tasks.insight_tasks._insight_exists_today",
            side_effect=_fake_exists,
        ):
            result = await _save_insight(
                user_id="user-1",
                insight_type=InsightType.ACTIVITY_PROGRESS,
                title="Steps update",
                body="You walked 8 000 steps today.",
            )

        # Returns a stub with sentinel id
        assert result.id == "duplicate-skipped"


# ---------------------------------------------------------------------------
# Test: time-of-day awareness
# ---------------------------------------------------------------------------


class TestTimeOfDayAwareness:
    """Morning slot should produce MORNING_BRIEFING; other slots should not."""

    @pytest.mark.asyncio
    async def test_morning_generates_morning_briefing(self):
        """hour=7 → time_slot='morning' → MORNING_BRIEFING insight written."""
        morning_dt = datetime(2026, 1, 15, 7, 0, tzinfo=timezone.utc)

        calls: list[InsightType] = []

        async def _spy_save(user_id, insight_type, **kwargs):
            calls.append(insight_type)
            stub = Insight(
                id="stub",
                user_id=user_id,
                type=insight_type.value,
                title="",
                body="",
            )
            return stub

        with (
            patch(
                "app.tasks.insight_tasks._count_user_data_days",
                AsyncMock(return_value=10),
            ),
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                AsyncMock(return_value=False),
            ),
            patch(
                "app.tasks.insight_tasks._fetch_goal_status_and_trends",
                AsyncMock(return_value=([], {})),
            ),
            patch(
                "app.tasks.insight_tasks._detect_anomalies",
                AsyncMock(return_value=[]),
            ),
            patch(
                "app.tasks.insight_tasks._save_insight",
                side_effect=_spy_save,
            ),
            patch("app.tasks.insight_tasks.datetime") as mock_dt,
        ):
            mock_dt.now.return_value = morning_dt
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await _generate_for_user("user-morning")

        assert InsightType.MORNING_BRIEFING in calls

    @pytest.mark.asyncio
    async def test_evening_does_not_generate_morning_briefing(self):
        """hour=19 → time_slot='evening' → no MORNING_BRIEFING card."""
        evening_dt = datetime(2026, 1, 15, 19, 0, tzinfo=timezone.utc)

        calls: list[InsightType] = []

        async def _spy_save(user_id, insight_type, **kwargs):
            calls.append(insight_type)
            stub = Insight(
                id="stub",
                user_id=user_id,
                type=insight_type.value,
                title="",
                body="",
            )
            return stub

        with (
            patch(
                "app.tasks.insight_tasks._count_user_data_days",
                AsyncMock(return_value=10),
            ),
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                AsyncMock(return_value=False),
            ),
            patch(
                "app.tasks.insight_tasks._fetch_goal_status_and_trends",
                AsyncMock(return_value=([], {})),
            ),
            patch(
                "app.tasks.insight_tasks._detect_anomalies",
                AsyncMock(return_value=[]),
            ),
            patch(
                "app.tasks.insight_tasks._save_insight",
                side_effect=_spy_save,
            ),
            patch("app.tasks.insight_tasks.datetime") as mock_dt,
        ):
            mock_dt.now.return_value = evening_dt
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await _generate_for_user("user-evening")

        assert InsightType.MORNING_BRIEFING not in calls


# ---------------------------------------------------------------------------
# Test: anomaly insight created when anomaly detected
# ---------------------------------------------------------------------------


class TestAnomalyInsightCreated:
    """An ANOMALY_ALERT card should be saved when _detect_anomalies returns hits."""

    @pytest.mark.asyncio
    async def test_anomaly_insight_saved_when_anomaly_detected(self):
        """If _detect_anomalies returns an anomaly, an ANOMALY_ALERT is saved."""
        calls: list[InsightType] = []

        async def _spy_save(user_id, insight_type, **kwargs):
            calls.append(insight_type)
            return Insight(
                id="stub",
                user_id=user_id,
                type=insight_type.value,
                title="",
                body="",
            )

        fake_anomaly = {
            "metric": "resting_heart_rate",
            "value": 95.0,
            "mean": 62.0,
            "z_score": 3.1,
            "message": "Your resting heart rate today (95) is unusually high.",
        }

        with (
            patch(
                "app.tasks.insight_tasks._count_user_data_days",
                AsyncMock(return_value=15),
            ),
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                AsyncMock(return_value=False),
            ),
            patch(
                "app.tasks.insight_tasks._fetch_goal_status_and_trends",
                AsyncMock(return_value=([], {})),
            ),
            patch(
                "app.tasks.insight_tasks._detect_anomalies",
                AsyncMock(return_value=[fake_anomaly]),
            ),
            patch(
                "app.tasks.insight_tasks._save_insight",
                side_effect=_spy_save,
            ),
            patch("app.tasks.insight_tasks.datetime") as mock_dt,
        ):
            mock_dt.now.return_value = datetime(2026, 1, 15, 14, 0, tzinfo=timezone.utc)
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await _generate_for_user("user-anomaly")

        assert InsightType.ANOMALY_ALERT in calls


# ---------------------------------------------------------------------------
# Test: skip complex insights when data < 7 days
# ---------------------------------------------------------------------------


class TestDataMaturityGating:
    """Complex analytical insights should not be generated with < 7 days data."""

    @pytest.mark.asyncio
    async def test_complex_insights_skipped_with_insufficient_data(self):
        """data_days=3 → only MORNING_BRIEFING may be written; no goals/trends."""
        calls: list[InsightType] = []

        async def _spy_save(user_id, insight_type, **kwargs):
            calls.append(insight_type)
            return Insight(
                id="stub",
                user_id=user_id,
                type=insight_type.value,
                title="",
                body="",
            )

        with (
            patch(
                "app.tasks.insight_tasks._count_user_data_days",
                AsyncMock(return_value=3),  # < _DATA_MATURITY_DAYS
            ),
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                AsyncMock(return_value=False),
            ),
            patch(
                "app.tasks.insight_tasks._fetch_goal_status_and_trends",
                AsyncMock(return_value=([], {})),
            ) as mock_fetch,
            patch(
                "app.tasks.insight_tasks._detect_anomalies",
                AsyncMock(return_value=[]),
            ) as mock_anomaly,
            patch(
                "app.tasks.insight_tasks._save_insight",
                side_effect=_spy_save,
            ),
            patch("app.tasks.insight_tasks.datetime") as mock_dt,
        ):
            mock_dt.now.return_value = datetime(2026, 1, 15, 7, 0, tzinfo=timezone.utc)
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await _generate_for_user("user-new")

        # Trend/goal fetching should NOT be called
        mock_fetch.assert_not_awaited()
        mock_anomaly.assert_not_awaited()

        # Must not have GOAL_NUDGE or ACTIVITY_PROGRESS
        assert InsightType.GOAL_NUDGE not in calls
        assert InsightType.ACTIVITY_PROGRESS not in calls

    @pytest.mark.asyncio
    async def test_boundary_exactly_7_days_enables_complex_insights(self):
        """data_days=7 (boundary) → complex insights SHOULD be generated."""
        calls: list[InsightType] = []

        async def _spy_save(user_id, insight_type, **kwargs):
            calls.append(insight_type)
            return Insight(
                id="stub",
                user_id=user_id,
                type=insight_type.value,
                title="",
                body="",
            )

        assert _DATA_MATURITY_DAYS == 7

        with (
            patch(
                "app.tasks.insight_tasks._count_user_data_days",
                AsyncMock(return_value=7),
            ),
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                AsyncMock(return_value=False),
            ),
            patch(
                "app.tasks.insight_tasks._fetch_goal_status_and_trends",
                AsyncMock(return_value=([], {})),
            ) as mock_fetch,
            patch(
                "app.tasks.insight_tasks._detect_anomalies",
                AsyncMock(return_value=[]),
            ),
            patch(
                "app.tasks.insight_tasks._save_insight",
                side_effect=_spy_save,
            ),
            patch("app.tasks.insight_tasks.datetime") as mock_dt,
        ):
            mock_dt.now.return_value = datetime(2026, 1, 15, 14, 0, tzinfo=timezone.utc)
            mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)

            await _generate_for_user("user-mature")

        mock_fetch.assert_awaited_once()


# ---------------------------------------------------------------------------
# Test: duplicate prevention
# ---------------------------------------------------------------------------


class TestDuplicatePrevention:
    """The same type + same day should never produce two DB rows."""

    @pytest.mark.asyncio
    async def test_duplicate_skipped_same_type_same_day(self):
        """_save_insight returns stub without DB write when duplicate exists."""

        async def _exists(user_id, insight_type, today):
            return True

        with patch(
            "app.tasks.insight_tasks._insight_exists_today",
            side_effect=_exists,
        ):
            result = await _save_insight(
                user_id="user-dup",
                insight_type=InsightType.MORNING_BRIEFING,
                title="Morning",
                body="Good morning!",
            )

        assert result.id == "duplicate-skipped"

    @pytest.mark.asyncio
    async def test_different_type_same_day_is_not_skipped(self):
        """Different type on the same day should still be written."""
        existing_types: set[InsightType] = {InsightType.MORNING_BRIEFING}

        async def _exists(user_id, insight_type, today):
            return insight_type in existing_types

        saved: list[Insight] = []

        async def _fake_session_save(user_id, insight_type, **kwargs):
            row = Insight(
                id=str(uuid.uuid4()),
                user_id=user_id,
                type=insight_type.value,
                title=kwargs.get("title", ""),
                body=kwargs.get("body", ""),
            )
            saved.append(row)
            return row

        # Patch both duplicate check and the actual save
        with (
            patch(
                "app.tasks.insight_tasks._insight_exists_today",
                side_effect=_exists,
            ),
            patch("app.tasks.insight_tasks.async_session") as mock_session_ctx,
        ):
            mock_db = AsyncMock()
            mock_db.__aenter__ = AsyncMock(return_value=mock_db)
            mock_db.__aexit__ = AsyncMock(return_value=False)
            mock_db.add = MagicMock(side_effect=lambda obj: saved.append(obj))
            mock_db.commit = AsyncMock()
            mock_db.refresh = AsyncMock()
            mock_session_ctx.return_value = mock_db

            result = await _save_insight(
                user_id="user-dup",
                insight_type=InsightType.ACTIVITY_PROGRESS,  # different type
                title="Activity",
                body="8000 steps today!",
            )

        # Should NOT be the duplicate-skipped stub
        assert result.id != "duplicate-skipped"
