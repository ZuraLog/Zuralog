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

from app.api.v1.deps import get_authenticated_user_id
from app.api.v1.goal_schemas import (
    GoalCreateRequest,
    GoalListResponse,
    GoalResponse,
    GoalUpdateRequest,
)
from app.database import get_db
from app.limiter import limiter
from app.models.user_goal import GoalPeriod, UserGoal

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


def _goal_to_response(goal: UserGoal) -> GoalResponse:
    """Convert a UserGoal ORM instance to a GoalResponse.

    Args:
        goal: The ORM instance to serialize.

    Returns:
        GoalResponse matching the Flutter Goal.fromJson contract.
    """
    # GoalPeriod enum value is e.g. "daily" — the .value attribute
    # gives us the lowercase slug the Flutter client expects.
    period_str = goal.period.value if hasattr(goal.period, "value") else str(goal.period)

    return GoalResponse(
        id=str(goal.id),
        user_id=str(goal.user_id),
        type=goal.type,
        period=period_str,
        title=goal.title,
        target_value=float(goal.target_value or 0.0),
        current_value=float(goal.current_value or 0.0),
        unit=goal.unit,
        start_date=goal.start_date,
        deadline=goal.deadline,
        is_completed=goal.is_completed,
        ai_commentary=goal.ai_commentary,
        progress_history=[],  # placeholder — computed by analytics engine
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", response_model=GoalListResponse, summary="List all active goals")
@limiter.limit("30/minute")
async def list_goals(
    request: Request,
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
    return GoalListResponse(goals=[_goal_to_response(g) for g in goals])


@router.post(
    "",
    response_model=GoalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new goal",
)
@limiter.limit("10/minute")
async def create_goal(
    request: Request,
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
        start_date=str(date.today()),
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
    request: Request,
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
    request: Request,
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
