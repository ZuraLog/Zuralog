"""
Zuralog Cloud Brain — Goals CRUD API.

Endpoints:
    GET    /api/v1/goals              — List all active goals for the user.
    POST   /api/v1/goals              — Create a new goal.
    PATCH  /api/v1/goals/{goal_id}    — Update specific fields of a goal.
    DELETE /api/v1/goals/{goal_id}    — Delete a goal (hard delete).

All endpoints are auth-guarded; users can only access their own goals.
"""

import logging
import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.analytics_service import AnalyticsService
from app.api.deps import get_authenticated_user_id
from app.api.v1.goal_schemas import (
    GoalCreateRequest,
    GoalListResponse,
    GoalResponse,
    GoalUpdateRequest,
)
from app.database import get_db
from app.limiter import limiter
from app.models.user_goal import GoalPeriod, UserGoal
from app.services.goal_history_service import get_goal_history

_analytics = AnalyticsService()

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/goals", tags=["goals"])

# ---------------------------------------------------------------------------
# Mapping from Flutter type slugs → analytics engine metric names
# ---------------------------------------------------------------------------

_TYPE_TO_METRIC: dict[str, str] = {
    "step_count": "steps",
    "weight_target": "weight_kg",
    "daily_calorie_limit": "calories_consumed",
    "sleep_duration": "sleep_hours",
    "weekly_run_count": "workouts",
    "water_intake": "water_intake",
    "custom": "custom",
}

# Mapping from Flutter period slugs → GoalPeriod enum members
_SLUG_TO_PERIOD: dict[str, GoalPeriod] = {
    "daily": GoalPeriod.DAILY,
    "weekly": GoalPeriod.WEEKLY,
    "long_term": GoalPeriod.LONG_TERM,
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _goal_to_response(
    goal: UserGoal,
    live_current_value: float | None = None,
    progress_history: list[dict] | None = None,
) -> GoalResponse:
    """Convert a UserGoal ORM instance to a GoalResponse.

    Args:
        goal: The ORM instance to serialize.
        live_current_value: If provided, overrides goal.current_value.
        progress_history: If provided, populates the progress_history field.

    Returns:
        GoalResponse matching the Flutter Goal.fromJson contract.
    """
    # GoalPeriod enum value is e.g. "daily" — the .value attribute
    # gives us the lowercase slug the Flutter client expects.
    period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)
    current_val = live_current_value if live_current_value is not None else float(goal.current_value or 0.0)

    return GoalResponse(
        id=str(goal.id),
        user_id=str(goal.user_id),
        type=goal.type,
        period=period_str,
        title=goal.title,
        target_value=float(goal.target_value or 0.0),
        current_value=current_val,
        unit=goal.unit,
        start_date=goal.start_date,
        deadline=goal.deadline,
        is_completed=goal.is_completed,
        ai_commentary=goal.ai_commentary,
        progress_history=progress_history if progress_history is not None else [],
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", response_model=GoalListResponse, summary="List all active goals")
@limiter.limit("30/minute")
async def list_goals(
    request: Request,  # noqa: ARG001 — required by slowapi
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> GoalListResponse:
    """Return all active goals for the authenticated user, newest first.

    Returns an empty ``{"goals": []}`` when no goals exist — never a 404.

    Args:
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        GoalListResponse with a ``goals`` list.
    """
    result = await db.execute(
        select(UserGoal)
        .where(UserGoal.user_id == user_id, UserGoal.is_active.is_(True))
        .order_by(UserGoal.created_at.desc())
        .limit(100)
    )
    goals = result.scalars().all()

    # Enrich with live current_value and progress_history from daily_summaries.
    enriched: list[GoalResponse] = []
    for goal in goals:
        period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)
        live_value = await _analytics._get_current_metric_value(db, user_id, goal.metric, period_str)
        goal.current_value = live_value
        history = await get_goal_history(db, user_id, goal.metric, days=30)
        enriched.append(_goal_to_response(goal, live_current_value=live_value, progress_history=history))

    await db.commit()
    return GoalListResponse(goals=enriched)


@router.post(
    "",
    response_model=GoalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new goal",
)
@limiter.limit("10/minute")
async def create_goal(
    request: Request,  # noqa: ARG001 — required by slowapi
    body: GoalCreateRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> GoalResponse:
    """Create a new goal for the authenticated user.

    Args:
        body: Goal creation payload (type, period, title, target_value, unit, deadline).
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        The newly created GoalResponse (HTTP 201).
    """
    goal = UserGoal(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric=_TYPE_TO_METRIC.get(body.type, "custom"),
        target_value=body.target_value,
        period=_SLUG_TO_PERIOD[body.period],
        is_active=True,
        type=body.type,
        title=body.title,
        current_value=0.0,
        unit=body.unit,
        start_date=date.today(),
        deadline=body.deadline,
        is_completed=False,
        ai_commentary=None,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    logger.info("Created goal %s for user %s", goal.id, user_id)
    return _goal_to_response(goal)


@router.patch("/{goal_id}", response_model=GoalResponse, summary="Update a goal")
@limiter.limit("20/minute")
async def update_goal(
    request: Request,  # noqa: ARG001 — required by slowapi
    goal_id: str,
    body: GoalUpdateRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> GoalResponse:
    """Update specific fields of an existing goal.

    Only the fields provided in the request body are changed.
    Returns 404 if the goal doesn't exist or belongs to another user
    (no information leaked about other users' goals).

    Args:
        goal_id: UUID of the goal to update.
        body: Fields to update (all optional).
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        The updated GoalResponse.

    Raises:
        HTTPException: 404 if the goal is not found or belongs to another user.
    """
    result = await db.execute(
        select(UserGoal).where(
            UserGoal.id == goal_id,
            UserGoal.user_id == user_id,
        )
    )
    goal = result.scalar_one_or_none()

    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Goal '{goal_id}' not found.",
        )

    if body.title is not None:
        goal.title = body.title
    if body.target_value is not None:
        goal.target_value = body.target_value
    if body.unit is not None:
        goal.unit = body.unit
    # deadline uses model_fields_set so sending "deadline": null clears it
    if "deadline" in body.model_fields_set:
        goal.deadline = body.deadline
    if body.period is not None and body.period in _SLUG_TO_PERIOD:
        goal.period = _SLUG_TO_PERIOD[body.period]

    await db.commit()
    await db.refresh(goal)
    logger.info("Updated goal %s for user %s", goal_id, user_id)
    return _goal_to_response(goal)


@router.delete(
    "/{goal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a goal",
)
@limiter.limit("20/minute")
async def delete_goal(
    request: Request,  # noqa: ARG001 — required by slowapi
    goal_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Hard-delete a goal by ID.

    Returns 404 if the goal doesn't exist or belongs to another user.

    Args:
        goal_id: UUID of the goal to delete.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        204 No Content on success.

    Raises:
        HTTPException: 404 if the goal is not found or belongs to another user.
    """
    result = await db.execute(
        select(UserGoal).where(
            UserGoal.id == goal_id,
            UserGoal.user_id == user_id,
        )
    )
    goal = result.scalar_one_or_none()

    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Goal '{goal_id}' not found.",
        )

    await db.delete(goal)
    await db.commit()
    logger.info("Deleted goal %s for user %s", goal_id, user_id)
