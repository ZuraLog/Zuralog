"""
Zuralog Cloud Brain — Progress API Router.

Provides the aggregated Progress Home endpoint consumed by the Flutter
Progress tab (Tab 3). Returns goals, streaks, week-over-week summary,
and recent achievements.

The ``/home`` endpoint queries the database for the user's active goals
and streaks and returns them in the shape that Flutter's
``ProgressHomeData.fromJson`` and ``UserStreak.fromJson`` expect.
Week-over-week comparison and achievements are empty scaffolds —
they will be wired in a future phase when the analytics engine is live.
"""

import logging
from datetime import date as _date, datetime as _datetime, timedelta as _timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import sentry_sdk
from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.achievement import Achievement as AchievementModel
from app.models.user_goal import UserGoal
from app.models.user_streak import UserStreak

logger = logging.getLogger(__name__)


def _resolve_local_date(request: Request) -> _date:
    """Resolve today's date in the user's local timezone."""
    tz_header = request.headers.get("X-User-Timezone", "UTC")
    try:
        tz = ZoneInfo(tz_header)
    except (ZoneInfoNotFoundError, KeyError):
        tz = ZoneInfo("UTC")
    return _datetime.now(ZoneInfo("UTC")).astimezone(tz).date()


def _compute_14day_history(streak, local_date: _date) -> list[bool]:
    """Return list of 14 booleans: index 0 = 14 days ago, index 13 = today.

    # TODO(activity-log): This approximation infers daily active/inactive
    # status from (last_activity_date, current_count). It is inaccurate
    # for days where a freeze was active (they appear as "missed" even
    # though the streak was preserved). The correct fix requires an
    # activity_log table with one row per active day.
    """
    today = local_date
    if not streak.last_activity_date:
        return [False] * 14
    try:
        last_active = _date.fromisoformat(str(streak.last_activity_date))
    except ValueError:
        return [False] * 14
    result = []
    for i in range(13, -1, -1):
        day = today - _timedelta(days=i)
        days_since_last = (last_active - day).days
        active = 0 <= days_since_last < streak.current_count
        result.append(active)
    return result


def _compute_week_hits(streak, local_date: _date) -> list[bool]:
    """Return list of 7 booleans for current week Mon-Sun."""
    today = local_date
    monday = today - _timedelta(days=today.weekday())
    if not streak.last_activity_date:
        return [False] * 7
    try:
        last_active = _date.fromisoformat(str(streak.last_activity_date))
    except ValueError:
        return [False] * 7
    result = []
    for i in range(7):
        day = monday + _timedelta(days=i)
        if day > today:
            result.append(False)
        else:
            days_since_last = (last_active - day).days
            active = 0 <= days_since_last < streak.current_count
            result.append(active)
    return result


def _compute_trend_direction(goal, local_date: _date) -> str:
    if goal.is_completed:
        return "completed"
    target = float(goal.target_value or 0)
    current = float(goal.current_value or 0)
    if target <= 0:
        return "on_track"
    if goal.start_date and goal.deadline:
        try:
            start_d = _date.fromisoformat(str(goal.start_date))
            end_d = _date.fromisoformat(str(goal.deadline))
            today = local_date
            total_days = max((end_d - start_d).days, 1)
            elapsed_days = (today - start_d).days
            expected_fraction = elapsed_days / total_days
            actual_fraction = current / target
            return "on_track" if actual_fraction >= expected_fraction else "behind"
        except (ValueError, TypeError):
            pass
    # No deadline — open-ended goal, never show as "behind"
    return "on_track"


_ACHIEVEMENT_ICONS = {
    "streak_7": "flame", "streak_14": "flame", "streak_30": "zap",
    "streak_60": "gem", "streak_90": "gem", "streak_180": "crown",
    "streak_365": "trophy", "first_sync": "link", "first_goal": "flag",
    "goals_5_complete": "star", "data_rich_30": "bar_chart",
}


def _achievement_icon(key: str) -> str:
    return _ACHIEVEMENT_ICONS.get(key, "trophy")


def _estimate_achievement_progress(key: str, streaks, goals) -> tuple[int, int]:
    max_streak = max((s.current_count for s in streaks), default=0)
    completed_goals = sum(1 for g in goals if g.is_completed)
    if key.startswith("streak_"):
        try:
            target_days = int(key.split("_")[1])
            return (min(max_streak, target_days), target_days)
        except (ValueError, IndexError):
            pass
    if key == "first_goal":
        return (min(len(goals), 1), 1)
    if key == "goals_5_complete":
        return (min(completed_goals, 5), 5)
    return (0, 1)


def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the progress module name."""
    sentry_sdk.set_tag("api.module", "progress")


router = APIRouter(
    prefix="/progress",
    tags=["progress"],
    dependencies=[Depends(_set_sentry_module)],
)


# ---------------------------------------------------------------------------
# Serialization helpers
# ---------------------------------------------------------------------------


def _goal_to_dict_with_date(goal: UserGoal, local_date: _date) -> dict:
    """Serialise a UserGoal ORM instance using the provided local date for trend computation."""
    type_str = goal.type.value if hasattr(goal.type, "value") else str(goal.type)  # type: ignore[union-attr]
    period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)  # type: ignore[union-attr]
    return {
        "id": str(goal.id),
        "user_id": str(goal.user_id),
        "type": type_str,
        "period": period_str,
        "title": goal.title,
        "target_value": float(goal.target_value or 0.0),
        "current_value": float(goal.current_value or 0.0),
        "unit": goal.unit or "",
        "start_date": str(goal.start_date) if goal.start_date else "",
        "deadline": str(goal.deadline) if goal.deadline else None,
        "is_completed": goal.is_completed,
        "ai_commentary": goal.ai_commentary,
        "progress_history": [],  # placeholder — analytics engine wired in a future phase
        "trend_direction": _compute_trend_direction(goal, local_date),
    }


def _goal_to_dict(goal: UserGoal) -> dict:
    """Serialise a UserGoal ORM instance to the Flutter Goal.fromJson shape.

    Returns a plain dict rather than a Pydantic model because this is used
    inside a nested list in the progress home response.

    Both ``type`` and ``period`` use an ``.value`` guard so the correct
    string slug is returned regardless of whether SQLAlchemy materialises
    the column as a raw string or as the Python enum object (behaviour can
    differ between driver versions).

    Args:
        goal: The ORM instance to serialise.

    Returns:
        Dict matching the Flutter ``Goal.fromJson`` contract.
    """
    type_str = goal.type.value if hasattr(goal.type, "value") else str(goal.type)  # type: ignore[union-attr]
    period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)  # type: ignore[union-attr]
    return {
        "id": str(goal.id),
        "user_id": str(goal.user_id),
        "type": type_str,
        "period": period_str,
        "title": goal.title,
        "target_value": float(goal.target_value or 0.0),
        "current_value": float(goal.current_value or 0.0),
        "unit": goal.unit or "",
        "start_date": str(goal.start_date) if goal.start_date else "",
        "deadline": str(goal.deadline) if goal.deadline else None,
        "is_completed": goal.is_completed,
        "ai_commentary": goal.ai_commentary,
        "progress_history": [],  # placeholder — analytics engine wired in a future phase
        "trend_direction": _compute_trend_direction(goal, _date.today()),
    }


def _streak_to_dict(streak: UserStreak) -> dict:
    """Serialise a UserStreak ORM instance to the Flutter UserStreak.fromJson shape.

    Key field mappings:
      - DB ``streak_type``        → Flutter ``type``
      - DB ``last_activity_date`` → Flutter ``last_activity_date`` (None → "")
      - DB ``is_frozen``          → Flutter ``is_frozen``

    Read directly from the ``is_frozen`` column. The freeze endpoint sets
    this to True; it clears on the next successful activity or at the weekly
    Monday reset.

    Args:
        streak: The ORM instance to serialise.

    Returns:
        Dict matching the Flutter ``UserStreak.fromJson`` contract.
    """
    return {
        "type": streak.streak_type,
        "current_count": streak.current_count,
        "longest_count": streak.longest_count,
        "last_activity_date": streak.last_activity_date or "",
        "is_frozen": streak.is_frozen,
        "freeze_count": streak.freeze_count,
        "freeze_tokens_available": streak.freeze_count,
    }


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("/home")
@limiter.limit("30/minute")
async def progress_home(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return aggregated Progress Home data.

    Queries the user's active goals and streaks from the database and
    returns them shaped to match the Flutter ``ProgressHomeData.fromJson``
    contract. Week-over-week comparison and recent achievements remain
    empty scaffolds until the analytics engine is wired in a future phase.

    The goals list is capped at 20 for the home summary view. The full
    list is available via ``GET /api/v1/goals``.

    Args:
        request: FastAPI request object (required by the rate limiter).
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        dict matching the ProgressHomeData model shape.
    """
    local_date = _resolve_local_date(request)

    # Active goals, newest first, capped at 20 for the home summary.
    goals_result = await db.execute(
        select(UserGoal)
        .where(UserGoal.user_id == user_id, UserGoal.is_active.is_(True))
        .order_by(UserGoal.created_at.desc())
        .limit(20)
    )
    goals = goals_result.scalars().all()

    # All streaks for this user (at most 4 rows — one per type).
    streaks_result = await db.execute(select(UserStreak).where(UserStreak.user_id == user_id))
    streaks = streaks_result.scalars().all()

    # Locked achievements for next_achievement computation.
    ach_result = await db.execute(
        select(AchievementModel)
        .where(AchievementModel.user_id == user_id, AchievementModel.unlocked_at.is_(None))
    )
    locked_achievements = ach_result.scalars().all()

    next_ach = None
    best_ratio = -1.0
    for ach in locked_achievements:
        current, total = _estimate_achievement_progress(ach.achievement_key, streaks, goals)
        ratio = current / max(total, 1)
        if 0 <= ratio < 1.0 and ratio > best_ratio:
            best_ratio = ratio
            next_ach = {
                "id": str(ach.id),
                "key": ach.achievement_key,
                "title": ach.achievement_key.replace("_", " ").title(),
                "description": "Keep going to unlock this achievement",
                "category": "consistency",
                "icon_name": _achievement_icon(ach.achievement_key),
                "unlocked_at": None,
                "progress_current": current,
                "progress_total": total,
                "progress_label": f"{current} of {total}",
            }

    logger.info(
        "progress_home: user='%s' goals=%d streaks=%d",
        user_id,
        len(goals),
        len(streaks),
    )

    return {
        "goals": [_goal_to_dict_with_date(g, local_date) for g in goals],
        "streaks": [_streak_to_dict(s) for s in streaks],
        "streak_history": {s.streak_type: _compute_14day_history(s, local_date) for s in streaks},
        "week_hits": {s.streak_type: _compute_week_hits(s, local_date) for s in streaks},
        "next_achievement": next_ach,
        "history_start_date": min(
            (s.created_at.isoformat()[:10] for s in streaks),
            default=None,
        ) if streaks else None,
        "wow": {
            "week_label": "",
            "metrics": [],
        },
        "recent_achievements": [],
    }


@router.get("/weekly-report")
@limiter.limit("10/minute")
async def progress_weekly_report(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return the latest weekly progress report.

    Currently returns an empty scaffold. Full report generation
    (driven by Celery weekly tasks) will be wired in a future phase.

    Args:
        request: FastAPI request object (required by the rate limiter).
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the WeeklyReport model shape.
    """
    return {
        "id": "",
        "period_start": "",
        "period_end": "",
        "cards": [],
    }
