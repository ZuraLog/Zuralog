"""
Zuralog Cloud Brain — Prompt Suggestions Router.

GET /prompts/suggestions

Returns 3–5 contextual prompt suggestions tailored to:
  - Time of day (morning / afternoon / evening / night)
  - Recent health data from the last 7 days (``daily_health_metrics``)
  - User's active goals (``user_goals``)

Fallback suggestions are returned when the user has no health data yet
(onboarding state).

Each suggestion is: {id, text, category, icon}

Auth: Bearer JWT via Supabase (get_authenticated_user_id).
"""

import hashlib
import logging
from datetime import date, datetime, timedelta, timezone

import sentry_sdk
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.daily_metrics import DailyHealthMetrics
from app.models.user_goal import UserGoal

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Response schema
# ---------------------------------------------------------------------------


class PromptSuggestion(BaseModel):
    """A single contextual prompt suggestion.

    Attributes:
        id: Stable deterministic ID for this suggestion text.
        text: The pre-filled chat message text.
        category: Semantic category (e.g. 'sleep', 'activity', 'nutrition').
        icon: SF Symbol / Material icon name for the mobile UI.
    """

    id: str
    text: str
    category: str
    icon: str


# ---------------------------------------------------------------------------
# Suggestion library
# ---------------------------------------------------------------------------

# Each suggestion dict: text, category, icon, time_slots (list of applicable
# time buckets), requires_data (bool — False for onboarding fallbacks).
_SUGGESTION_LIBRARY: list[dict] = [
    # Morning (5–11)
    {
        "text": "How did I sleep last night?",
        "category": "sleep",
        "icon": "moon.stars",
        "time_slots": ["morning"],
        "requires_data": True,
    },
    {
        "text": "What's my energy level looking like today?",
        "category": "energy",
        "icon": "bolt.fill",
        "time_slots": ["morning"],
        "requires_data": True,
    },
    {
        "text": "Help me plan a healthy day based on my current stats.",
        "category": "planning",
        "icon": "calendar",
        "time_slots": ["morning"],
        "requires_data": True,
    },
    {
        "text": "What does my resting heart rate trend look like this week?",
        "category": "heart",
        "icon": "heart.fill",
        "time_slots": ["morning"],
        "requires_data": True,
    },
    # Afternoon (11–17)
    {
        "text": "How am I tracking against my step goal today?",
        "category": "activity",
        "icon": "figure.walk",
        "time_slots": ["afternoon"],
        "requires_data": True,
    },
    {
        "text": "Give me a nutrition check — am I on track with calories?",
        "category": "nutrition",
        "icon": "fork.knife",
        "time_slots": ["afternoon"],
        "requires_data": True,
    },
    {
        "text": "Should I drink more water? What does my hydration history say?",
        "category": "hydration",
        "icon": "drop.fill",
        "time_slots": ["afternoon"],
        "requires_data": False,
    },
    {
        "text": "What's the best workout I could do this afternoon?",
        "category": "activity",
        "icon": "figure.strengthtraining.traditional",
        "time_slots": ["afternoon"],
        "requires_data": False,
    },
    # Evening (17–22)
    {
        "text": "Summarise today's workout and tell me how it compared to last week.",
        "category": "activity",
        "icon": "figure.run",
        "time_slots": ["evening"],
        "requires_data": True,
    },
    {
        "text": "How are my stress and HRV levels trending this week?",
        "category": "stress",
        "icon": "brain.head.profile",
        "time_slots": ["evening"],
        "requires_data": True,
    },
    {
        "text": "What should I do tonight to set up a great night's sleep?",
        "category": "sleep",
        "icon": "moon.fill",
        "time_slots": ["evening"],
        "requires_data": False,
    },
    {
        "text": "Did I hit my active calorie goal today?",
        "category": "activity",
        "icon": "flame.fill",
        "time_slots": ["evening"],
        "requires_data": True,
    },
    # Night (22–5)
    {
        "text": "Reflect on this week — what went well for my health?",
        "category": "reflection",
        "icon": "sparkles",
        "time_slots": ["night"],
        "requires_data": True,
    },
    {
        "text": "Help me set tomorrow's health intentions.",
        "category": "planning",
        "icon": "target",
        "time_slots": ["night"],
        "requires_data": False,
    },
    {
        "text": "What's one thing I can improve for better sleep quality?",
        "category": "sleep",
        "icon": "zzz",
        "time_slots": ["night"],
        "requires_data": False,
    },
    # Onboarding fallbacks — shown when no health data available
    {
        "text": "I'm new here — how do I get started with Zuralog?",
        "category": "onboarding",
        "icon": "hand.wave.fill",
        "time_slots": ["morning", "afternoon", "evening", "night"],
        "requires_data": False,
        "is_fallback": True,
    },
    {
        "text": "What integrations should I connect first?",
        "category": "onboarding",
        "icon": "link",
        "time_slots": ["morning", "afternoon", "evening", "night"],
        "requires_data": False,
        "is_fallback": True,
    },
    {
        "text": "What health metrics can you track for me?",
        "category": "onboarding",
        "icon": "chart.bar.fill",
        "time_slots": ["morning", "afternoon", "evening", "night"],
        "requires_data": False,
        "is_fallback": True,
    },
    {
        "text": "Can you explain what insights you'll generate for me?",
        "category": "onboarding",
        "icon": "lightbulb.fill",
        "time_slots": ["morning", "afternoon", "evening", "night"],
        "requires_data": False,
        "is_fallback": True,
    },
    {
        "text": "Help me set my first health goal.",
        "category": "onboarding",
        "icon": "flag.fill",
        "time_slots": ["morning", "afternoon", "evening", "night"],
        "requires_data": False,
        "is_fallback": True,
    },
]

# Goal-aware contextual suggestions injected when the user has active goals
_GOAL_SUGGESTION_MAP: dict[str, dict] = {
    "steps": {
        "text": "How close am I to my step goal today?",
        "category": "activity",
        "icon": "figure.walk",
    },
    "calories_consumed": {
        "text": "Am I within my calorie target today?",
        "category": "nutrition",
        "icon": "fork.knife",
    },
    "weight_kg": {
        "text": "How is my weight trending toward my goal?",
        "category": "body",
        "icon": "scalemass.fill",
    },
    "workouts": {
        "text": "How many workouts have I logged this week?",
        "category": "activity",
        "icon": "figure.strengthtraining.traditional",
    },
    "active_calories": {
        "text": "Did I hit my active calorie burn today?",
        "category": "activity",
        "icon": "flame.fill",
    },
    "sleep_hours": {
        "text": "Am I getting enough sleep to meet my sleep goal?",
        "category": "sleep",
        "icon": "moon.stars.fill",
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _stable_id(text: str) -> str:
    """Generate a stable short ID from suggestion text.

    Args:
        text: Suggestion text to hash.

    Returns:
        First 8 hex characters of the SHA-256 of the text.
    """
    return hashlib.sha256(text.encode()).hexdigest()[:8]


def _time_slot(hour: int) -> str:
    """Map an hour (0–23) to a named time-of-day slot.

    Args:
        hour: UTC hour integer.

    Returns:
        One of ``"morning"``, ``"afternoon"``, ``"evening"``, ``"night"``.
    """
    if 5 <= hour < 11:
        return "morning"
    if 11 <= hour < 17:
        return "afternoon"
    if 17 <= hour < 22:
        return "evening"
    return "night"


def _to_suggestion(s: dict) -> PromptSuggestion:
    return PromptSuggestion(
        id=_stable_id(s["text"]),
        text=s["text"],
        category=s["category"],
        icon=s["icon"],
    )


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "prompt_suggestions")


router = APIRouter(
    prefix="/prompts",
    tags=["prompts"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.get(
    "/suggestions",
    response_model=list[PromptSuggestion],
    summary="Get contextual prompt suggestions",
)
async def get_prompt_suggestions(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[PromptSuggestion]:
    """Return 3–5 contextual prompt suggestions for the AI chat input.

    Selection logic:
    1. Determine time-of-day slot from UTC hour.
    2. Check whether the user has health data in the last 7 days.
    3. If no data → return onboarding fallbacks (3–5 items).
    4. If data exists → select time-slot-relevant suggestions, inject up to
       2 goal-specific prompts based on active goals, cap at 5 total.

    Args:
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        List of 3–5 PromptSuggestion items.
    """
    now_utc = datetime.now(tz=timezone.utc)
    slot = _time_slot(now_utc.hour)
    seven_days_ago = (date.today() - timedelta(days=7)).isoformat()

    # ------------------------------------------------------------------
    # Check data availability
    # ------------------------------------------------------------------
    data_check_stmt = (
        select(DailyHealthMetrics.id)
        .where(
            DailyHealthMetrics.user_id == user_id,
            DailyHealthMetrics.date >= seven_days_ago,
        )
        .limit(1)
    )
    has_data = (await db.execute(data_check_stmt)).scalar_one_or_none() is not None

    # ------------------------------------------------------------------
    # No data → onboarding fallbacks
    # ------------------------------------------------------------------
    if not has_data:
        fallbacks = [s for s in _SUGGESTION_LIBRARY if s.get("is_fallback") and slot in s["time_slots"]][:5]
        # If still not 3, top up from all fallbacks
        if len(fallbacks) < 3:
            all_fallbacks = [s for s in _SUGGESTION_LIBRARY if s.get("is_fallback")]
            fallbacks = all_fallbacks[:5]
        return [_to_suggestion(s) for s in fallbacks[:5]]

    # ------------------------------------------------------------------
    # Data available → time-of-day suggestions
    # ------------------------------------------------------------------
    time_suggestions = [s for s in _SUGGESTION_LIBRARY if slot in s["time_slots"] and not s.get("is_fallback")]

    # ------------------------------------------------------------------
    # Inject goal-specific suggestions (max 2)
    # ------------------------------------------------------------------
    goals_stmt = (
        select(UserGoal.metric)
        .where(
            UserGoal.user_id == user_id,
            UserGoal.is_active.is_(True),
        )
        .limit(5)
    )
    active_metrics = list((await db.execute(goals_stmt)).scalars().all())

    goal_suggestions: list[dict] = []
    for metric in active_metrics:
        if metric in _GOAL_SUGGESTION_MAP:
            goal_suggestions.append(_GOAL_SUGGESTION_MAP[metric])
        if len(goal_suggestions) >= 2:
            break

    # ------------------------------------------------------------------
    # Merge and cap at 5, min 3
    # ------------------------------------------------------------------
    # Goal suggestions go first so they feel personalised
    combined = goal_suggestions + time_suggestions
    # De-duplicate by text (goal suggestions might overlap with time suggestions)
    seen: set[str] = set()
    deduped: list[dict] = []
    for s in combined:
        if s["text"] not in seen:
            seen.add(s["text"])
            deduped.append(s)

    # Ensure minimum of 3 — top up from any-slot no-data suggestions if needed
    if len(deduped) < 3:
        extras = [s for s in _SUGGESTION_LIBRARY if not s.get("is_fallback") and s["text"] not in seen]
        deduped.extend(extras[: 3 - len(deduped)])

    return [_to_suggestion(s) for s in deduped[:5]]
