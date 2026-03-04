"""
Zuralog Cloud Brain — Correlation Suggester.

Generates integration suggestions based on the gap between a user's
health goals and the data sources they currently have connected.

Goal → required data mappings:
  lose_weight       → nutrition + activity
  better_sleep      → sleep + stress (check-in)
  reduce_stress     → HRV + check-in + activity
  build_fitness     → activity + heart_rate + VO2max
  improve_nutrition → nutrition tracking
  increase_energy   → sleep + check-in + activity

Dismissed suggestions are stored in Redis with a 30-day TTL.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.integration import Integration
from app.models.user_preferences import UserPreferences

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Goal → data requirements mapping
# ---------------------------------------------------------------------------

_GOAL_REQUIREMENTS: dict[str, list[str]] = {
    "lose_weight": ["nutrition", "activity"],
    "better_sleep": ["sleep", "checkin"],
    "reduce_stress": ["hrv", "checkin", "activity"],
    "build_fitness": ["activity", "heart_rate", "vo2max"],
    "improve_nutrition": ["nutrition"],
    "increase_energy": ["sleep", "checkin", "activity"],
}

# Map data requirements to the integrations that satisfy them.
_DATA_TO_INTEGRATION: dict[str, list[str]] = {
    "nutrition": ["fitbit", "apple_health", "health_connect"],
    "activity": ["strava", "fitbit", "apple_health", "health_connect", "polar"],
    "sleep": ["oura", "fitbit", "apple_health", "health_connect", "withings"],
    "checkin": ["checkin"],  # Built-in Zuralog check-in feature
    "hrv": ["oura", "fitbit", "apple_health", "polar"],
    "heart_rate": ["fitbit", "polar", "oura", "apple_health", "health_connect"],
    "vo2max": ["fitbit", "polar", "apple_health"],
}

# Human-readable display names for integrations.
_INTEGRATION_DISPLAY: dict[str, str] = {
    "fitbit": "Fitbit",
    "oura": "Oura Ring",
    "strava": "Strava",
    "apple_health": "Apple Health",
    "health_connect": "Health Connect",
    "polar": "Polar",
    "withings": "Withings",
    "checkin": "Daily Wellness Check-In",
}

_GOAL_DISPLAY: dict[str, str] = {
    "lose_weight": "losing weight",
    "better_sleep": "improving sleep",
    "reduce_stress": "reducing stress",
    "build_fitness": "building fitness",
    "improve_nutrition": "improving nutrition",
    "increase_energy": "increasing energy",
}

_REDIS_DISMISS_TTL = 30 * 86400  # 30 days


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class CorrelationSuggestion:
    """A suggestion for the user to connect a missing integration.

    Attributes:
        id: UUID string for client-side dismissal reference.
        title: Short suggestion headline.
        description: Why this integration helps the user's goal.
        missing_integration: Integration slug (e.g. ``"fitbit"``).
        goal_context: Human-readable goal name.
        dismissed_until: When this suggestion becomes visible again.
            None if not dismissed.
    """

    id: str
    title: str
    description: str
    missing_integration: str
    goal_context: str
    dismissed_until: datetime | None = field(default=None)


# ---------------------------------------------------------------------------
# CorrelationSuggester
# ---------------------------------------------------------------------------


class CorrelationSuggester:
    """Generate and manage integration suggestions based on goal gaps.

    Methods:
        get_suggestions: Generate ranked suggestions for a user.
        dismiss_suggestion: Mark a suggestion as dismissed for 30 days.
    """

    async def get_suggestions(
        self,
        user_id: str,
        session: AsyncSession,
        dismissed_cache: dict,
    ) -> list[CorrelationSuggestion]:
        """Generate suggestions based on the user's goals vs connected integrations.

        Steps:
        1. Load user preferences to get current goals.
        2. Load connected integrations.
        3. For each goal, identify which required data types are missing.
        4. Map missing data → integration suggestions.
        5. Filter out dismissed suggestions and already-connected integrations.
        6. Deduplicate (one suggestion per missing integration).

        Args:
            user_id: Zuralog user ID.
            session: Open async DB session.
            dismissed_cache: Dict of ``{suggestion_id: True}`` for dismissed
                suggestions. The caller populates this from Redis.

        Returns:
            List of CorrelationSuggestion objects, ordered by relevance.
        """
        prefs = await self._get_preferences(user_id, session)
        if prefs is None or not prefs.goals:
            return []

        connected = await self._get_connected_integrations(user_id, session)

        suggestions: list[CorrelationSuggestion] = []
        seen_integrations: set[str] = set()

        for goal in prefs.goals:
            goal_metric = goal.get("metric", "")
            if goal_metric not in _GOAL_REQUIREMENTS:
                continue

            goal_display = _GOAL_DISPLAY.get(goal_metric, goal_metric)
            required_data = _GOAL_REQUIREMENTS[goal_metric]

            for data_type in required_data:
                integrations_for_type = _DATA_TO_INTEGRATION.get(data_type, [])
                # Check if any integration satisfying this data type is connected.
                covered = any(intg in connected for intg in integrations_for_type)
                if covered:
                    continue

                # Find the best missing integration to suggest.
                candidate = integrations_for_type[0] if integrations_for_type else None
                if candidate is None or candidate in seen_integrations:
                    continue

                suggestion_id = str(
                    uuid.uuid5(
                        uuid.NAMESPACE_URL,
                        f"{user_id}:{goal_metric}:{candidate}",
                    )
                )

                # Skip dismissed suggestions.
                if suggestion_id in dismissed_cache:
                    continue

                display_name = _INTEGRATION_DISPLAY.get(candidate, candidate.title())

                suggestions.append(
                    CorrelationSuggestion(
                        id=suggestion_id,
                        title=f"Connect {display_name} to unlock {goal_display} insights",
                        description=(
                            f"Your goal of {goal_display} requires {data_type.replace('_', ' ')} data. "
                            f"Connecting {display_name} will give your AI coach the full picture."
                        ),
                        missing_integration=candidate,
                        goal_context=goal_display,
                    )
                )
                seen_integrations.add(candidate)

        return suggestions

    async def dismiss_suggestion(
        self,
        user_id: str,
        suggestion_id: str,
        redis_client,
    ) -> None:
        """Mark a suggestion as dismissed for 30 days via Redis.

        Args:
            user_id: Zuralog user ID.
            suggestion_id: UUID of the suggestion to dismiss.
            redis_client: Async Redis client (aioredis or compatible).
        """
        key = f"dismissed_suggestion:{user_id}:{suggestion_id}"
        try:
            await redis_client.set(key, "1", ex=_REDIS_DISMISS_TTL)
            logger.debug(
                "Suggestion %s dismissed for user %s for 30 days",
                suggestion_id,
                user_id,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Failed to dismiss suggestion %s for user %s",
                suggestion_id,
                user_id,
            )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    async def _get_preferences(user_id: str, session: AsyncSession) -> UserPreferences | None:
        stmt = select(UserPreferences).where(UserPreferences.user_id == user_id)
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    @staticmethod
    async def _get_connected_integrations(user_id: str, session: AsyncSession) -> set[str]:
        """Return the set of active integration provider slugs for the user.

        Args:
            user_id: Zuralog user ID.
            session: Open async DB session.

        Returns:
            Set of provider strings (e.g. ``{"strava", "fitbit"}``).
        """
        stmt = select(Integration.provider).where(
            Integration.user_id == user_id,
            Integration.is_active.is_(True),
        )
        result = await session.execute(stmt)
        return {row[0] for row in result.all()}
