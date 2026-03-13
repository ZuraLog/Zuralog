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

import sentry_sdk
from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.user_goal import UserGoal
from app.models.user_streak import UserStreak

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
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


def _goal_to_dict(goal: UserGoal) -> dict:
    """Serialise a UserGoal ORM instance to the Flutter Goal.fromJson shape.

    Returns a plain dict rather than a Pydantic model because this is used
    inside a nested list in the progress home response.

    Args:
        goal: The ORM instance to serialise.

    Returns:
        Dict matching the Flutter ``Goal.fromJson`` contract.
    """
    period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)
    return {
        "id": str(goal.id),
        "user_id": str(goal.user_id),
        "type": goal.type,
        "period": period_str,
        "title": goal.title,
        "target_value": float(goal.target_value or 0.0),
        "current_value": float(goal.current_value or 0.0),
        "unit": goal.unit,
        "start_date": goal.start_date,
        "deadline": goal.deadline,
        "is_completed": goal.is_completed,
        "ai_commentary": goal.ai_commentary,
        "progress_history": [],  # placeholder — analytics engine wired in a future phase
    }


def _streak_to_dict(streak: UserStreak) -> dict:
    """Serialise a UserStreak ORM instance to the Flutter UserStreak.fromJson shape.

    Key field mappings:
      - DB ``streak_type``         → Flutter ``type``
      - DB ``freeze_used_this_week`` → Flutter ``is_frozen``
      - DB ``last_activity_date`` None → Flutter ``""``

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
        "is_frozen": streak.freeze_used_this_week,
        "freeze_count": streak.freeze_count,
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

    logger.info(
        "progress_home: user='%s' goals=%d streaks=%d",
        user_id,
        len(goals),
        len(streaks),
    )

    return {
        "goals": [_goal_to_dict(g) for g in goals],
        "streaks": [_streak_to_dict(s) for s in streaks],
        "wow": {
            "week_label": "",
            "metrics": [],
        },
        "recent_achievements": [],
    }


@router.get("/weekly-report")
async def progress_weekly_report(
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return the latest weekly progress report.

    Currently returns an empty scaffold. Full report generation
    (driven by Celery weekly tasks) will be wired in a future phase.

    Args:
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
