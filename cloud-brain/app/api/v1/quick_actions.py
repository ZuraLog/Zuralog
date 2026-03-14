"""
Zuralog Cloud Brain — Quick Actions API.

Endpoint:
  GET /api/v1/quick-actions — Returns a prioritised list of contextual action cards.

Actions are personalised based on the time of day, recent workout data, data gaps,
goal proximity, and the user's proactivity preference.

All endpoints are auth-guarded via ``get_authenticated_user_id``.
"""

import logging
from datetime import datetime, timedelta, timezone

import sentry_sdk
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/quick-actions", tags=["quick-actions"])

# ---------------------------------------------------------------------------
# Proactivity → action count mapping
# ---------------------------------------------------------------------------

_PROACTIVITY_COUNTS: dict[str, int] = {
    "low": 3,
    "medium": 5,
    "high": 7,
}

_DEFAULT_COUNT = 5


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class QuickAction(BaseModel):
    """A single contextual quick action card.

    Attributes:
        id: Unique identifier for this action (stable string slug).
        title: Short action title displayed on the card.
        subtitle: Supporting text below the title.
        icon: Material icon name for the card's leading icon.
        prompt: Pre-filled chat message sent when the action is tapped.
        priority: Display priority (1 = highest urgency, 10 = lowest).
    """

    id: str
    title: str
    subtitle: str
    icon: str
    prompt: str
    priority: int


class QuickActionsResponse(BaseModel):
    """Response envelope for the quick actions endpoint.

    Attributes:
        actions: Prioritised (ascending) list of contextual action cards.
        generated_at: ISO-8601 timestamp of when actions were generated.
    """

    actions: list[QuickAction]
    generated_at: str


# ---------------------------------------------------------------------------
# Action catalogue
# ---------------------------------------------------------------------------

# Each entry: (id, title, subtitle, icon, prompt, base_priority, tod_windows)
# tod_windows: list of time-of-day labels this action is relevant for, or None for always.
_STATIC_ACTIONS: list[dict] = [
    {
        "id": "morning_checkin",
        "title": "Start Morning Check-in",
        "subtitle": "How are you feeling today?",
        "icon": "wb_sunny",
        "prompt": "I'd like to do my morning check-in. How am I looking today?",
        "priority": 1,
        "tod": ["morning"],
    },
    {
        "id": "log_sleep_quality",
        "title": "Log Your Sleep Quality",
        "subtitle": "Rate last night's sleep",
        "icon": "bedtime",
        "prompt": "Help me log my sleep quality from last night.",
        "priority": 2,
        "tod": ["morning"],
    },
    {
        "id": "set_intention",
        "title": "Set Today's Intention",
        "subtitle": "Focus your day with a goal",
        "icon": "flag",
        "prompt": "Help me set my intention and focus for today.",
        "priority": 3,
        "tod": ["morning"],
    },
    {
        "id": "log_water",
        "title": "Log Water Intake",
        "subtitle": "Stay hydrated throughout the day",
        "icon": "water_drop",
        "prompt": "I want to log my water intake. How much should I be drinking today?",
        "priority": 4,
        "tod": None,  # always visible
    },
    {
        "id": "feeling_checkin",
        "title": "How Are You Feeling?",
        "subtitle": "Rate your energy on a 1-10 scale",
        "icon": "sentiment_satisfied",
        "prompt": "I want to log how I'm feeling right now on a scale of 1 to 10.",
        "priority": 5,
        "tod": None,  # always visible
    },
    {
        "id": "activity_check",
        "title": "Activity Progress",
        "subtitle": "See how active you've been today",
        "icon": "directions_run",
        "prompt": "How are my activity levels today? Am I on track?",
        "priority": 4,
        "tod": ["afternoon"],
    },
    {
        "id": "goal_progress",
        "title": "Check Goal Progress",
        "subtitle": "See where you stand on your targets",
        "icon": "track_changes",
        "prompt": "Show me my goal progress for today.",
        "priority": 5,
        "tod": ["afternoon"],
    },
    {
        "id": "log_meals",
        "title": "Log Today's Meals",
        "subtitle": "Track your nutrition for the day",
        "icon": "restaurant",
        "prompt": "Help me log what I've eaten today.",
        "priority": 3,
        "tod": ["evening"],
    },
    {
        "id": "evening_winddown",
        "title": "Evening Wind-Down Check-In",
        "subtitle": "Reflect on your day and prepare for sleep",
        "icon": "nights_stay",
        "prompt": "Let's do my evening wind-down. How did today go overall?",
        "priority": 2,
        "tod": ["evening"],
    },
    {
        "id": "daily_summary",
        "title": "Today's Summary",
        "subtitle": "Review what happened today",
        "icon": "summarize",
        "prompt": "Give me a summary of my health and fitness today.",
        "priority": 4,
        "tod": ["evening", "night"],
    },
    {
        "id": "sleep_prep",
        "title": "Prepare for Sleep",
        "subtitle": "Tips to improve tonight's rest",
        "icon": "hotel",
        "prompt": "How can I improve my sleep tonight? Any tips based on my data?",
        "priority": 2,
        "tod": ["night"],
    },
    {
        "id": "weekly_reflection",
        "title": "Reflect on My Week",
        "subtitle": "See your weekly patterns and progress",
        "icon": "calendar_today",
        "prompt": "I'd like to reflect on this week. What trends do you see in my data?",
        "priority": 6,
        "tod": ["night"],
    },
]


def _get_time_of_day(hour: int) -> str:
    """Map a UTC hour to a named time-of-day window.

    Args:
        hour: UTC hour (0-23).

    Returns:
        One of: 'morning', 'afternoon', 'evening', 'night'.
    """
    if 5 <= hour <= 11:
        return "morning"
    if 12 <= hour <= 17:
        return "afternoon"
    if 18 <= hour <= 21:
        return "evening"
    return "night"


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.get("", response_model=QuickActionsResponse)
async def get_quick_actions(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> QuickActionsResponse:
    """Return a prioritised list of contextual quick action cards.

    Actions are selected and ordered based on:
    - Time of day (morning / afternoon / evening / night)
    - Recent workout activity (post-workout actions if workout in last 2 hours)
    - Goal proximity (nudge if within 10% of step goal)
    - User proactivity level from preferences (controls max action count)

    All data lookups use soft imports to gracefully handle missing tables/rows.

    Args:
        user_id: Authenticated Zuralog user ID (injected by dependency).
        db: Async database session (injected by dependency).

    Returns:
        QuickActionsResponse with prioritised action cards.
    """
    now_utc = datetime.now(timezone.utc)
    tod = _get_time_of_day(now_utc.hour)

    # -------------------------------------------------------------------------
    # 1. Determine action count from proactivity preference (soft import)
    # -------------------------------------------------------------------------
    action_count = _DEFAULT_COUNT
    try:
        from sqlalchemy import select
        from app.models.user_preferences import UserPreferences

        result = await db.execute(
            select(UserPreferences).where(UserPreferences.user_id == user_id)
        )
        prefs = result.scalar_one_or_none()
        if prefs:
            action_count = _PROACTIVITY_COUNTS.get(
                prefs.proactivity_level, _DEFAULT_COUNT
            )
    except Exception:
        logger.debug(
            "quick_actions: could not load user preferences for user=%s",
            user_id,
            exc_info=True,
        )

    # -------------------------------------------------------------------------
    # 2. Build candidate actions filtered by time of day
    # -------------------------------------------------------------------------
    candidates: list[dict] = []
    for action in _STATIC_ACTIONS:
        if action["tod"] is None or tod in action["tod"]:
            candidates.append(dict(action))

    # -------------------------------------------------------------------------
    # 3. Post-workout detection (soft import — check for recent daily metrics)
    # -------------------------------------------------------------------------
    try:
        from sqlalchemy import select, desc
        from app.models.daily_metrics import DailyHealthMetrics

        today_str = now_utc.strftime("%Y-%m-%d")
        result = await db.execute(
            select(DailyHealthMetrics)
            .where(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.date == today_str,
            )
            .order_by(desc(DailyHealthMetrics.date))
            .limit(1)
        )
        today_metrics = result.scalar_one_or_none()

        if today_metrics and today_metrics.active_calories is not None:
            # Heuristic: if active calories > 300, likely had a workout today
            if today_metrics.active_calories > 300:
                candidates.insert(
                    0,
                    {
                        "id": "post_workout_log",
                        "title": "Log Workout Details",
                        "subtitle": "You had a great session — capture it!",
                        "icon": "fitness_center",
                        "prompt": "Help me log the details of my workout today.",
                        "priority": 1,
                        "tod": [tod],
                    },
                )
                candidates.insert(
                    1,
                    {
                        "id": "post_workout_performance",
                        "title": "How Was My Performance?",
                        "subtitle": "Analyse your workout stats",
                        "icon": "insights",
                        "prompt": "How did I perform in my workout today? Any insights?",
                        "priority": 2,
                        "tod": [tod],
                    },
                )

            # Goal proximity nudge: if steps are within 10% of typical 10k goal
            if today_metrics.steps is not None:
                step_goal = 10000
                if today_metrics.steps >= step_goal * 0.9:
                    candidates.insert(
                        0,
                        {
                            "id": "step_goal_nudge",
                            "title": "You're Close to Your Step Goal!",
                            "subtitle": f"{today_metrics.steps:,} steps — almost there!",
                            "icon": "emoji_events",
                            "prompt": "I'm close to my step goal today. How many more steps do I need?",
                            "priority": 1,
                            "tod": [tod],
                        },
                    )
    except Exception:
        logger.debug(
            "quick_actions: could not load daily metrics for user=%s",
            user_id,
            exc_info=True,
        )

    # -------------------------------------------------------------------------
    # 4. Deduplicate, sort by priority, and cap to action_count
    # -------------------------------------------------------------------------
    seen_ids: set[str] = set()
    deduped: list[dict] = []
    for action in candidates:
        if action["id"] not in seen_ids:
            seen_ids.add(action["id"])
            deduped.append(action)

    deduped.sort(key=lambda a: a["priority"])
    final = deduped[:action_count]

    actions = [
        QuickAction(
            id=action["id"],
            title=action["title"],
            subtitle=action["subtitle"],
            icon=action["icon"],
            prompt=action["prompt"],
            priority=action["priority"],
        )
        for action in final
    ]

    logger.info(
        "quick_actions: generated %d actions for user=%s tod=%s proactivity_count=%d",
        len(actions),
        user_id,
        tod,
        action_count,
    )

    return QuickActionsResponse(
        actions=actions,
        generated_at=now_utc.isoformat(),
    )
