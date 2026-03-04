"""
Zuralog Cloud Brain — Prompt Suggestions API.

Endpoint:
  GET /api/v1/prompts/suggestions — Returns 3-5 personalised AI prompt suggestions
      based on the time of day, user preferences, goals, and recent data anomalies.

All endpoints are auth-guarded via ``get_authenticated_user_id``.
"""

import logging
import uuid
from datetime import datetime, timezone

import sentry_sdk
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/prompts", tags=["prompts"])

# ---------------------------------------------------------------------------
# Time-of-day windows
# ---------------------------------------------------------------------------

_TOD_MORNING = "morning"    # 05–11
_TOD_AFTERNOON = "afternoon"  # 12–17
_TOD_EVENING = "evening"    # 18–21
_TOD_NIGHT = "night"        # 22–04


def _get_time_of_day(hour: int) -> str:
    """Map a UTC hour (0-23) to a named time-of-day window.

    Args:
        hour: UTC hour integer (0–23).

    Returns:
        One of: 'morning', 'afternoon', 'evening', 'night'.
    """
    if 5 <= hour <= 11:
        return _TOD_MORNING
    if 12 <= hour <= 17:
        return _TOD_AFTERNOON
    if 18 <= hour <= 21:
        return _TOD_EVENING
    return _TOD_NIGHT


# Base prompts per time-of-day window
_BASE_PROMPTS: dict[str, list[dict]] = {
    _TOD_MORNING: [
        {"text": "How did I sleep?", "category": "sleep"},
        {"text": "What's my health score today?", "category": "health_score"},
        {"text": "What should I focus on today?", "category": "coaching"},
    ],
    _TOD_AFTERNOON: [
        {"text": "How are my activity levels today?", "category": "activity"},
        {"text": "Am I on track for my goals?", "category": "goals"},
        {"text": "What's my energy like compared to yesterday?", "category": "wellness"},
    ],
    _TOD_EVENING: [
        {"text": "How did I do today?", "category": "summary"},
        {"text": "What's my nutrition summary?", "category": "nutrition"},
        {"text": "How's my recovery looking?", "category": "recovery"},
    ],
    _TOD_NIGHT: [
        {"text": "How can I improve my sleep tonight?", "category": "sleep"},
        {"text": "Reflect on my week", "category": "reflection"},
        {"text": "What's my HRV trend this week?", "category": "hrv"},
    ],
}


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class PromptSuggestion(BaseModel):
    """A single contextual prompt suggestion.

    Attributes:
        id: Unique identifier for this suggestion (UUID).
        text: The pre-filled prompt text for the chat interface.
        category: Broad category for grouping/theming (e.g. 'sleep', 'activity').
    """

    id: str
    text: str
    category: str


class PromptSuggestionsResponse(BaseModel):
    """Response envelope for the prompt suggestions endpoint.

    Attributes:
        suggestions: Ordered list of 3-5 contextual prompts.
        generated_at: ISO-8601 timestamp of when suggestions were generated.
    """

    suggestions: list[PromptSuggestion]
    generated_at: str


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.get("/suggestions", response_model=PromptSuggestionsResponse)
async def get_prompt_suggestions(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> PromptSuggestionsResponse:
    """Return 3-5 contextual AI prompt suggestions for the current user.

    Suggestions are personalised based on:
    - Time of day (morning / afternoon / evening / night)
    - User goals from preferences (appended if available)
    - Recent data anomalies (appended if available)

    All data lookups are soft — the endpoint degrades gracefully if
    the relevant tables/rows do not yet exist.

    Args:
        user_id: Authenticated Zuralog user ID (injected by dependency).
        db: Async database session (injected by dependency).

    Returns:
        PromptSuggestionsResponse with 3-5 ranked prompt suggestions.
    """
    now_utc = datetime.now(timezone.utc)
    tod = _get_time_of_day(now_utc.hour)

    # Start from time-of-day base prompts (copy so we don't mutate the module constant)
    candidates: list[dict] = list(_BASE_PROMPTS[tod])

    # -------------------------------------------------------------------------
    # 1. Append goal-based prompts from user preferences (soft import)
    # -------------------------------------------------------------------------
    try:
        from sqlalchemy import select
        from app.models.user_preferences import UserPreferences

        result = await db.execute(
            select(UserPreferences).where(UserPreferences.user_id == user_id)
        )
        prefs = result.scalar_one_or_none()
        if prefs and prefs.goals:
            for goal in prefs.goals[:2]:  # cap to 2 goal prompts
                goal_label = goal.replace("_", " ").title()
                candidates.append({
                    "text": f"How am I progressing on {goal_label}?",
                    "category": "goals",
                })
    except Exception:
        logger.debug(
            "prompt_suggestions: could not load user preferences for user=%s",
            user_id,
            exc_info=True,
        )

    # -------------------------------------------------------------------------
    # 2. Append anomaly-based prompts (soft import, skip if table missing)
    # -------------------------------------------------------------------------
    try:
        from sqlalchemy import select, desc
        from app.models.daily_metrics import DailyHealthMetrics

        result = await db.execute(
            select(DailyHealthMetrics)
            .where(DailyHealthMetrics.user_id == user_id)
            .order_by(desc(DailyHealthMetrics.date))
            .limit(1)
        )
        latest_metrics = result.scalar_one_or_none()

        if latest_metrics:
            # Simple anomaly heuristics: low HRV or elevated resting HR
            if latest_metrics.hrv_ms is not None and latest_metrics.hrv_ms < 25:
                candidates.append({
                    "text": "Tell me about my HRV anomaly",
                    "category": "anomaly",
                })
            if (
                latest_metrics.resting_heart_rate is not None
                and latest_metrics.resting_heart_rate > 80
            ):
                candidates.append({
                    "text": "Tell me about my resting heart rate anomaly",
                    "category": "anomaly",
                })
    except Exception:
        logger.debug(
            "prompt_suggestions: could not load daily metrics for user=%s",
            user_id,
            exc_info=True,
        )

    # -------------------------------------------------------------------------
    # 3. Build final suggestion list (cap at 5, ensure at least 3)
    # -------------------------------------------------------------------------
    # Deduplicate by text while preserving order
    seen_texts: set[str] = set()
    deduped: list[dict] = []
    for item in candidates:
        if item["text"] not in seen_texts:
            seen_texts.add(item["text"])
            deduped.append(item)

    # Clamp to [3, 5]
    final = deduped[:5]
    while len(final) < 3 and len(_BASE_PROMPTS[tod]) > len(final):
        extra = _BASE_PROMPTS[tod][len(final)]
        if extra["text"] not in seen_texts:
            final.append(extra)

    suggestions = [
        PromptSuggestion(id=str(uuid.uuid4()), text=item["text"], category=item["category"])
        for item in final
    ]

    logger.info(
        "prompt_suggestions: generated %d suggestions for user=%s tod=%s",
        len(suggestions),
        user_id,
        tod,
    )

    return PromptSuggestionsResponse(
        suggestions=suggestions,
        generated_at=now_utc.isoformat(),
    )
