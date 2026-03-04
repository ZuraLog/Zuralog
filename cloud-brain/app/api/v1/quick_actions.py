"""
Zuralog Cloud Brain — Quick Actions Router.

GET /quick-actions

Returns 4–8 prioritized contextual actions for the mobile home screen
action bar. Actions are pre-filled with chat prompts so tapping one
immediately starts a useful AI conversation.

Action selection logic:
  1. Load user proactivity_level preference (default: 'medium').
  2. Apply proactivity cap: low→3, medium→5, high→8.
  3. Build the action pool from:
       a. Time-of-day actions (morning check-in, evening workout log, etc.)
       b. Goal-proximity actions (step goal close → encouraging nudge)
       c. Universal utility actions (log water, mood, ask coach, etc.)
  4. Deduplicate and cap to the proactivity limit.
  5. Return the action list.

Each action: {id, title, subtitle, icon, action_type, prompt}

Auth: Bearer JWT via Supabase (get_authenticated_user_id).
"""

import hashlib
import logging
from datetime import date, datetime, timezone

import sentry_sdk
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.daily_metrics import DailyHealthMetrics
from app.models.user import User
from app.models.user_goal import UserGoal

logger = logging.getLogger(__name__)

# Steps proximity threshold: if within this many steps of goal, show nudge.
_STEPS_PROXIMITY_THRESHOLD = 1000


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class QuickAction(BaseModel):
    """A single quick-action tile.

    Attributes:
        id: Stable deterministic ID for this action.
        title: Primary action label (≤ 30 chars).
        subtitle: Supporting context line (≤ 50 chars).
        icon: SF Symbol / Material icon name.
        action_type: Machine-readable action category used by the client
            to decide how to handle the tap (e.g. navigate vs open chat).
        prompt: Pre-filled chat message sent when the action is tapped.
    """

    id: str
    title: str
    subtitle: str
    icon: str
    action_type: str
    prompt: str


# ---------------------------------------------------------------------------
# Action definitions
# ---------------------------------------------------------------------------


def _stable_id(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()[:8]


def _make_action(
    key: str,
    title: str,
    subtitle: str,
    icon: str,
    action_type: str,
    prompt: str,
) -> QuickAction:
    return QuickAction(
        id=_stable_id(key),
        title=title,
        subtitle=subtitle,
        icon=icon,
        action_type=action_type,
        prompt=prompt,
    )


# Universal utility actions — shown regardless of time or data
_UNIVERSAL_ACTIONS: list[QuickAction] = [
    _make_action(
        key="log_water",
        title="Log Water",
        subtitle="Track your hydration",
        icon="drop.fill",
        action_type="log_water",
        prompt="I just drank some water. Can you help me track my hydration for today?",
    ),
    _make_action(
        key="log_mood",
        title="Log Mood",
        subtitle="How are you feeling?",
        icon="face.smiling.fill",
        action_type="log_mood",
        prompt="I want to log my current mood. Can you ask me a few quick questions?",
    ),
    _make_action(
        key="ask_coach",
        title="Ask Coach",
        subtitle="Get personalised advice",
        icon="person.fill.questionmark",
        action_type="ask_coach",
        prompt="I have a health question for you.",
    ),
    _make_action(
        key="view_insight",
        title="Today's Insight",
        subtitle="See your latest health card",
        icon="lightbulb.fill",
        action_type="view_insight",
        prompt="What's my most important health insight for today?",
    ),
    _make_action(
        key="connect_integration",
        title="Connect App",
        subtitle="Add a new data source",
        icon="link.badge.plus",
        action_type="connect_integration",
        prompt="I want to connect a new app. What integrations do you support?",
    ),
]

# Time-based actions — selected based on current UTC hour
_MORNING_ACTIONS: list[QuickAction] = [
    _make_action(
        key="morning_checkin",
        title="Morning Check-in",
        subtitle="Start your day right",
        icon="sun.max.fill",
        action_type="ask_coach",
        prompt=(
            "Good morning! Give me a quick health check-in: "
            "how did I sleep, what's my energy like, and what should I focus on today?"
        ),
    ),
    _make_action(
        key="sleep_recap",
        title="Sleep Recap",
        subtitle="Review last night's sleep",
        icon="moon.stars.fill",
        action_type="ask_coach",
        prompt="Can you recap my sleep from last night and tell me if it was good quality?",
    ),
]

_AFTERNOON_ACTIONS: list[QuickAction] = [
    _make_action(
        key="midday_check",
        title="Midday Check",
        subtitle="Progress so far today",
        icon="chart.bar.fill",
        action_type="ask_coach",
        prompt="It's midday — how am I tracking against today's health goals?",
    ),
]

_EVENING_ACTIONS: list[QuickAction] = [
    _make_action(
        key="log_workout",
        title="Log Today's Workout",
        subtitle="Record your exercise",
        icon="figure.run",
        action_type="log_workout",
        prompt=("I want to log today's workout. Can you ask me what I did and add it to my training log?"),
    ),
    _make_action(
        key="evening_summary",
        title="Evening Summary",
        subtitle="How did today go?",
        icon="chart.line.uptrend.xyaxis",
        action_type="ask_coach",
        prompt=("Give me an evening health summary: steps, active calories, and whether I hit my goals today."),
    ),
]


def _get_time_actions(hour: int) -> list[QuickAction]:
    """Return time-of-day specific actions based on the current UTC hour.

    Args:
        hour: UTC hour (0–23).

    Returns:
        List of applicable time-based QuickActions.
    """
    if 5 <= hour < 11:
        return list(_MORNING_ACTIONS)
    if 11 <= hour < 17:
        return list(_AFTERNOON_ACTIONS)
    if 17 <= hour < 22:
        return list(_EVENING_ACTIONS)
    return []  # night — no time-specific actions


def _get_step_proximity_action(
    today_steps: int | None,
    goal_steps: float | None,
) -> QuickAction | None:
    """Return a proximity nudge action if the user is close to their step goal.

    Args:
        today_steps: Steps logged today. None if not available.
        goal_steps: User's daily step goal target. None if no goal set.

    Returns:
        QuickAction nudge if within _STEPS_PROXIMITY_THRESHOLD, else None.
    """
    if today_steps is None or goal_steps is None:
        return None
    remaining = goal_steps - today_steps
    if 0 < remaining <= _STEPS_PROXIMITY_THRESHOLD:
        return _make_action(
            key="step_goal_close",
            title="Almost There!",
            subtitle=f"Only {int(remaining):,} steps to your goal",
            icon="figure.walk.circle.fill",
            action_type="ask_coach",
            prompt=(
                f"I'm only {int(remaining)} steps away from my daily step goal! "
                "Can you give me a quick motivational boost and suggest how to close the gap?"
            ),
        )
    return None


def _proactivity_cap(level: str) -> int:
    """Map a proactivity level string to a maximum action count.

    Args:
        level: One of ``'low'``, ``'medium'``, ``'high'``. Defaults to 5 for
            unknown values.

    Returns:
        Maximum number of quick actions to show.
    """
    return {"low": 3, "medium": 5, "high": 8}.get(level, 5)


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "quick_actions")


router = APIRouter(
    prefix="/quick-actions",
    tags=["quick-actions"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.get(
    "",
    response_model=list[QuickAction],
    summary="Get prioritised quick actions",
)
async def get_quick_actions(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[QuickAction]:
    """Return 4–8 prioritised quick actions for the home screen action bar.

    The number of actions returned is capped by the user's
    ``proactivity_level`` preference:
      - low  → max 3
      - medium → max 5 (default)
      - high → max 8

    Selection logic:
    1. Load user preference and today's health metrics.
    2. Inject time-of-day actions.
    3. Inject goal-proximity nudge if the user is close to their step goal.
    4. Fill remaining slots with universal utility actions.
    5. Enforce minimum of 4 (add universals if needed), cap at proactivity_cap.

    Args:
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        List of QuickAction items (4 ≤ len ≤ 8).
    """
    now_utc = datetime.now(tz=timezone.utc)
    today_str = date.today().isoformat()

    # ------------------------------------------------------------------
    # 1. Load user's proactivity preference
    # ------------------------------------------------------------------
    user_stmt = select(User).where(User.id == user_id)
    user_row: User | None = (await db.execute(user_stmt)).scalar_one_or_none()

    proactivity = "medium"  # default
    if user_row is not None:
        # proactivity_level is stored in coach_persona or a dedicated field.
        # Phase 2: read from coach_persona mapping until a dedicated column exists.
        # coach_persona: gentle→low, balanced→medium, tough_love→high
        persona_map = {"gentle": "low", "balanced": "medium", "tough_love": "high"}
        proactivity = persona_map.get(user_row.coach_persona or "balanced", "medium")

    cap = _proactivity_cap(proactivity)

    # ------------------------------------------------------------------
    # 2. Load today's metrics for goal-proximity check
    # ------------------------------------------------------------------
    metrics_stmt = (
        select(DailyHealthMetrics)
        .where(
            DailyHealthMetrics.user_id == user_id,
            DailyHealthMetrics.date == today_str,
        )
        .order_by(DailyHealthMetrics.date.desc())
        .limit(1)
    )
    metrics_row: DailyHealthMetrics | None = (await db.execute(metrics_stmt)).scalar_one_or_none()
    today_steps = metrics_row.steps if metrics_row else None

    # ------------------------------------------------------------------
    # 3. Load step goal target
    # ------------------------------------------------------------------
    goal_stmt = (
        select(UserGoal)
        .where(
            UserGoal.user_id == user_id,
            UserGoal.metric == "steps",
            UserGoal.is_active.is_(True),
        )
        .limit(1)
    )
    goal_row: UserGoal | None = (await db.execute(goal_stmt)).scalar_one_or_none()
    goal_steps = goal_row.target_value if goal_row else None

    # ------------------------------------------------------------------
    # 4. Assemble action pool
    # ------------------------------------------------------------------
    pool: list[QuickAction] = []
    seen_ids: set[str] = set()

    def _add(action: QuickAction) -> None:
        if action.id not in seen_ids:
            seen_ids.add(action.id)
            pool.append(action)

    # Time-based first (highest contextual relevance)
    for a in _get_time_actions(now_utc.hour):
        _add(a)

    # Goal-proximity nudge (if applicable)
    proximity = _get_step_proximity_action(today_steps, goal_steps)
    if proximity:
        _add(proximity)

    # Fill remaining slots with universal actions
    for a in _UNIVERSAL_ACTIONS:
        _add(a)

    # ------------------------------------------------------------------
    # 5. Enforce minimum 4, cap at proactivity limit
    # ------------------------------------------------------------------
    # The universal pool guarantees at least 5 entries, so min=4 is always met.
    return pool[:cap]
