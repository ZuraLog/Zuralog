"""Post-processing hooks called after a successful ingest write.

Triggers streak updates for the appropriate streak types given a
metric_type. Isolated here so ingest_routes stays focused on ingestion
and so this logic is unit-testable independently.

Streak type mapping:
  steps / step_count          → steps + engagement
  workout_duration/count/etc  → workouts + engagement
  run_distance / run_duration → workouts + engagement
  everything else             → engagement only
"""

from __future__ import annotations

import logging
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.streak_tracker import StreakTracker

logger = logging.getLogger(__name__)

_METRIC_TO_STREAK_TYPES: dict[str, list[str]] = {
    "steps": ["steps", "engagement"],
    "step_count": ["steps", "engagement"],
    "workout_duration": ["workouts", "engagement"],
    "workout_count": ["workouts", "engagement"],
    "run_distance": ["workouts", "engagement"],
    "run_duration": ["workouts", "engagement"],
    "workouts": ["workouts", "engagement"],
    "active_calories": ["workouts", "engagement"],
}


async def trigger_streaks_for_metric(
    db: AsyncSession,
    user_id: str,
    metric_type: str,
    activity_date: date,
) -> None:
    """Record activity for all streak types associated with this metric.

    Never raises — streak failures must never block an ingest response.

    Args:
        db: Async database session (already in a transaction).
        user_id: Authenticated user ID.
        metric_type: The metric type just ingested (e.g. "steps").
        activity_date: The local calendar date of the event.
    """
    streak_types = _METRIC_TO_STREAK_TYPES.get(metric_type, ["engagement"])
    tracker = StreakTracker()
    for streak_type in streak_types:
        try:
            await tracker.record_activity(
                user_id=user_id,
                streak_type=streak_type,
                activity_date=activity_date,
                db=db,
            )
            logger.debug(
                "trigger_streaks: user=%s metric=%s streak=%s date=%s",
                user_id[:8], metric_type, streak_type, activity_date,
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "trigger_streaks: non-fatal error for user=%s streak=%s: %s",
                user_id[:8], streak_type, exc,
            )
