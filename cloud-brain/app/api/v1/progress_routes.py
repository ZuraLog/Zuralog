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
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.analytics_service import AnalyticsService
from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.achievement import Achievement as AchievementModel
from app.models.daily_summary import DailySummary
from app.models.user_goal import UserGoal
from app.models.user_streak import UserStreak
from app.services.goal_history_service import get_goal_history

_analytics = AnalyticsService()

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
# Analytics helpers
# ---------------------------------------------------------------------------


async def _compute_wow(db: AsyncSession, user_id: str, local_date: _date) -> dict:
    """Compare this week's vs last week's key metrics from daily_summaries."""
    monday = local_date - _timedelta(days=local_date.weekday())
    last_monday = monday - _timedelta(days=7)
    last_sunday = monday - _timedelta(days=1)

    _metric_meta: dict[str, tuple[str, str]] = {
        "steps": ("Steps", "steps/day"),
        "sleep_hours": ("Sleep", "hrs/night"),
        "calories_consumed": ("Calories", "kcal/day"),
        "weight_kg": ("Weight", "kg"),
    }
    key_metrics = list(_metric_meta.keys())
    metrics_out = []

    for metric in key_metrics:
        # this week: monday..today
        this_result = await db.execute(
            select(func.avg(DailySummary.value))
            .where(
                DailySummary.user_id == user_id,
                DailySummary.metric_type == metric,
                DailySummary.date >= monday,
                DailySummary.date <= local_date,
            )
        )
        this_avg = this_result.scalar_one_or_none()

        # last week: last_monday..last_sunday
        last_result = await db.execute(
            select(func.avg(DailySummary.value))
            .where(
                DailySummary.user_id == user_id,
                DailySummary.metric_type == metric,
                DailySummary.date >= last_monday,
                DailySummary.date <= last_sunday,
            )
        )
        last_avg = last_result.scalar_one_or_none()

        if this_avg is None and last_avg is None:
            continue

        label, unit = _metric_meta[metric]
        metrics_out.append({
            "label": label,
            "current_value": round(this_avg or 0, 2),
            "previous_value": round(last_avg or 0, 2),
            "unit": unit,
        })

    return {
        "week_label": f"Week of {monday.isoformat()}",
        "metrics": metrics_out,
    }


# ---------------------------------------------------------------------------
# Serialization helpers
# ---------------------------------------------------------------------------


def _goal_to_dict_with_date(
    goal: UserGoal,
    local_date: _date,
    live_current_value: float | None = None,
    progress_history: list[dict] | None = None,
) -> dict:
    """Serialise a UserGoal ORM instance using the provided local date for trend computation.

    Args:
        goal: The ORM instance to serialise.
        local_date: The user's local date for trend direction computation.
        live_current_value: If provided, overrides goal.current_value in the output.
        progress_history: If provided, populates the progress_history field.
    """
    type_str = goal.type.value if hasattr(goal.type, "value") else str(goal.type)  # type: ignore[union-attr]
    period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)  # type: ignore[union-attr]
    current_val = live_current_value if live_current_value is not None else float(goal.current_value or 0.0)
    return {
        "id": str(goal.id),
        "user_id": str(goal.user_id),
        "type": type_str,
        "period": period_str,
        "title": goal.title,
        "target_value": float(goal.target_value or 0.0),
        "current_value": current_val,
        "unit": goal.unit or "",
        "start_date": str(goal.start_date) if goal.start_date else "",
        "deadline": str(goal.deadline) if goal.deadline else None,
        "is_completed": goal.is_completed,
        "ai_commentary": goal.ai_commentary,
        "progress_history": progress_history if progress_history is not None else [],
        "trend_direction": _compute_trend_direction(goal, local_date),
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

    # Enrich each goal with live current_value and progress_history.
    enriched_goals = []
    for goal in goals:
        period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)
        live_value = await _analytics._get_current_metric_value(db, user_id, goal.metric, period_str)
        goal.current_value = live_value
        history = await get_goal_history(db, user_id, goal.metric, days=30)
        enriched_goals.append((goal, live_value, history))

    await db.commit()

    # Recent achievements — last 5 unlocked.
    recent_ach_result = await db.execute(
        select(AchievementModel)
        .where(
            AchievementModel.user_id == user_id,
            AchievementModel.unlocked_at.is_not(None),
        )
        .order_by(AchievementModel.unlocked_at.desc())
        .limit(5)
    )
    recent_achievements = [
        {
            "id": str(a.id),
            "key": a.achievement_key,
            "title": a.achievement_key.replace("_", " ").title(),
            "description": "",
            "category": "consistency",
            "icon_name": _achievement_icon(a.achievement_key),
            "unlocked_at": str(a.unlocked_at),
        }
        for a in recent_ach_result.scalars().all()
    ]

    # Week-over-week metrics.
    wow = await _compute_wow(db, user_id, local_date)

    logger.info(
        "progress_home: user='%s' goals=%d streaks=%d",
        user_id,
        len(goals),
        len(streaks),
    )

    return {
        "goals": [
            _goal_to_dict_with_date(g, local_date, live_val, history)
            for g, live_val, history in enriched_goals
        ],
        "streaks": [_streak_to_dict(s) for s in streaks],
        "streak_history": {s.streak_type: _compute_14day_history(s, local_date) for s in streaks},
        "week_hits": {s.streak_type: _compute_week_hits(s, local_date) for s in streaks},
        "next_achievement": next_ach,
        "history_start_date": min(
            (s.created_at.isoformat()[:10] for s in streaks),
            default=None,
        ) if streaks else None,
        "wow": wow,
        "recent_achievements": recent_achievements,
    }


@router.get("/weekly-report")
@limiter.limit("10/minute")
async def progress_weekly_report(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the latest weekly progress report.

    Aggregates this week's daily_summaries into category cards for
    the Flutter Progress tab weekly report screen.

    Args:
        request: FastAPI request object (required by the rate limiter).
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        dict matching the WeeklyReport model shape.
    """
    local_date = _resolve_local_date(request)
    monday = local_date - _timedelta(days=local_date.weekday())
    sunday = monday + _timedelta(days=6)

    # Fetch this week's daily_summaries
    result = await db.execute(
        select(DailySummary)
        .where(
            DailySummary.user_id == user_id,
            DailySummary.date >= monday,
            DailySummary.date <= local_date,
        )
    )
    summaries = result.scalars().all()

    if not summaries:
        return {
            "id": "",
            "period_start": str(monday),
            "period_end": str(sunday),
            "cards": [],
        }

    # Group by metric_type
    by_metric: dict[str, list[float]] = {}
    for s in summaries:
        by_metric.setdefault(s.metric_type, []).append(s.value)

    def _card(category: str, metric_keys: list[str], label_map: dict[str, str]) -> dict | None:
        card_metrics = []
        for key in metric_keys:
            vals = by_metric.get(key, [])
            if not vals:
                continue
            avg_val = sum(vals) / len(vals)
            total_val = sum(vals)
            card_metrics.append({
                "label": label_map.get(key, key.replace("_", " ").title()),
                "value": round(avg_val, 1),
                "total": round(total_val, 1),
                "days_with_data": len(vals),
            })
        if not card_metrics:
            return None
        return {"category": category, "metrics": card_metrics}

    cards = []
    for card in [
        _card("Activity",   ["steps", "workouts", "active_calories"], {"steps": "Steps/day", "workouts": "Workouts", "active_calories": "Active cal/day"}),
        _card("Sleep",      ["sleep_hours", "sleep_duration"],        {"sleep_hours": "Hours/night", "sleep_duration": "Duration"}),
        _card("Nutrition",  ["calories_consumed", "water_intake"],    {"calories_consumed": "Calories/day", "water_intake": "Water (L)/day"}),
        _card("Body",       ["weight_kg", "body_fat_pct"],            {"weight_kg": "Weight (kg)", "body_fat_pct": "Body fat %"}),
        _card("Vitals",     ["heart_rate", "hrv", "spo2"],            {"heart_rate": "Resting HR", "hrv": "HRV", "spo2": "SpO\u2082"}),
    ]:
        if card:
            cards.append(card)

    return {
        "id": f"{user_id}-{monday.isoformat()}",
        "period_start": str(monday),
        "period_end": str(sunday),
        "cards": cards,
    }
