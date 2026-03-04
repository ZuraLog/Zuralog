"""
Zuralog Cloud Brain — Correlation Suggester Service.

Suggests which data categories a user should start tracking based on their
stated goals and the integrations they have currently connected.

The service maps each goal type to the data categories that correlate most
strongly with progress, then checks which of those categories are missing
or sparsely covered by the user's connected integrations.
"""

import logging
import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Goal → data-category correlation map
# ---------------------------------------------------------------------------

GOAL_TO_GAP_MAP: dict[str, list[str]] = {
    "weight_loss": ["nutrition", "activity", "sleep"],
    "improve_sleep": ["sleep", "stress", "activity"],
    "build_muscle": ["activity", "nutrition", "body"],
    "reduce_stress": ["stress", "sleep", "hrv"],
    "improve_endurance": ["activity", "heart_rate", "sleep"],
    "increase_energy": ["sleep", "nutrition", "activity"],
}

# Integration provider → data categories it can supply
_PROVIDER_CATEGORIES: dict[str, list[str]] = {
    "apple_health": ["activity", "sleep", "heart_rate", "hrv", "body", "nutrition"],
    "health_connect": ["activity", "sleep", "heart_rate", "body"],
    "strava": ["activity"],
    "fitbit": ["activity", "sleep", "heart_rate", "hrv"],
    "oura": ["sleep", "heart_rate", "hrv", "stress"],
    "withings": ["body", "sleep", "heart_rate"],
    "polar": ["activity", "heart_rate", "hrv"],
    "myfitnesspal": ["nutrition"],
    "cronometer": ["nutrition"],
}

# Category → human-readable suggestion text + recommended action
_CATEGORY_SUGGESTIONS: dict[str, dict[str, str]] = {
    "nutrition": {
        "suggestion": "Track your nutrition to optimise your diet for your goal.",
        "action": "Connect MyFitnessPal or log meals manually.",
    },
    "sleep": {
        "suggestion": "Sleep data is crucial for this goal but isn't being tracked.",
        "action": "Connect Oura Ring, Fitbit, or Apple Health for sleep tracking.",
    },
    "activity": {
        "suggestion": "Activity tracking will help measure your progress toward this goal.",
        "action": "Connect Strava, Apple Health, or a fitness tracker.",
    },
    "heart_rate": {
        "suggestion": "Heart rate data can help gauge exertion and recovery.",
        "action": "Connect a heart rate monitor via Polar, Fitbit, or Apple Health.",
    },
    "hrv": {
        "suggestion": "HRV (heart rate variability) is a key recovery and stress indicator.",
        "action": "Connect Oura Ring or a Polar device for HRV tracking.",
    },
    "stress": {
        "suggestion": "Stress tracking provides crucial context for recovery and wellness.",
        "action": "Connect Oura Ring for stress and readiness scoring.",
    },
    "body": {
        "suggestion": "Body composition metrics (weight, body fat) help track progress.",
        "action": "Connect Withings smart scale or log manually.",
    },
}

# ---------------------------------------------------------------------------
# In-memory dismissal cache
# Key: "{user_id}:{suggestion_id}"
# Value: True (dismissed)
# This is intentionally ephemeral for the MVP — a DB-backed table will
# replace this in a later phase.
# ---------------------------------------------------------------------------
_dismissal_cache: dict[str, bool] = {}
_DISMISSAL_CACHE_MAX_SIZE: int = 10_000  # prevent unbounded growth


def _dismissal_cache_set(key: str, value: bool) -> None:
    """Set a key in the dismissal cache with a max-size guard.

    Evicts the oldest 20% of entries when the cache reaches
    ``_DISMISSAL_CACHE_MAX_SIZE`` to keep memory bounded.

    Args:
        key: Cache key to set.
        value: Cache value.
    """
    if len(_dismissal_cache) >= _DISMISSAL_CACHE_MAX_SIZE:
        evict_count = max(1, _DISMISSAL_CACHE_MAX_SIZE // 5)
        keys_to_evict = list(_dismissal_cache.keys())[:evict_count]
        for k in keys_to_evict:
            _dismissal_cache.pop(k, None)
    _dismissal_cache[key] = value


class CorrelationSuggester:
    """Suggests data tracking categories based on user goals and connected integrations.

    Uses the GOAL_TO_GAP_MAP to identify which data categories are required
    for each goal, then checks the user's connected integrations to determine
    which categories are not yet being captured. Missing categories become
    actionable tracking suggestions.

    Dismissals are stored in an in-memory cache (ephemeral for MVP).
    """

    async def get_suggestions(
        self,
        user_id: str,
        db: AsyncSession,
    ) -> list[dict[str, Any]]:
        """Generate tracking gap suggestions for the user.

        Loads the user's goals and connected integrations, then returns
        suggestions for data categories that are missing but relevant
        to at least one active goal.

        Args:
            user_id: Zuralog user ID to generate suggestions for.
            db: Async database session.

        Returns:
            List of suggestion dicts, each with keys:
            ``id``, ``goal``, ``suggestion``, ``missing_category``, ``action``.
            Returns an empty list if preferences or integrations cannot be loaded.
        """
        # -------------------------------------------------------------------------
        # 1. Load user goals from preferences (soft import)
        # -------------------------------------------------------------------------
        user_goals: list[str] = []
        try:
            from sqlalchemy import select
            from app.models.user_preferences import UserPreferences

            result = await db.execute(
                select(UserPreferences).where(UserPreferences.user_id == user_id)
            )
            prefs = result.scalar_one_or_none()
            if prefs and prefs.goals:
                user_goals = list(prefs.goals)
        except Exception:
            logger.warning(
                "correlation_suggester: could not load user preferences for user=%s",
                user_id,
                exc_info=True,
            )
            return []

        if not user_goals:
            logger.debug(
                "correlation_suggester: no goals set for user=%s, skipping suggestions",
                user_id,
            )
            return []

        # -------------------------------------------------------------------------
        # 2. Load connected integrations (soft import)
        # -------------------------------------------------------------------------
        connected_providers: list[str] = []
        try:
            from sqlalchemy import select
            from app.models.integration import Integration

            result = await db.execute(
                select(Integration.provider).where(
                    Integration.user_id == user_id,
                    Integration.is_active == True,  # noqa: E712
                )
            )
            connected_providers = [row[0] for row in result.fetchall()]
        except Exception:
            logger.warning(
                "correlation_suggester: could not load integrations for user=%s",
                user_id,
                exc_info=True,
            )
            # Proceed with no connected providers — all categories will appear as gaps

        # -------------------------------------------------------------------------
        # 3. Determine covered categories from connected integrations
        # -------------------------------------------------------------------------
        covered_categories: set[str] = set()
        for provider in connected_providers:
            covered_categories.update(_PROVIDER_CATEGORIES.get(provider, []))

        # -------------------------------------------------------------------------
        # 4. Generate suggestions for missing categories per goal
        # -------------------------------------------------------------------------
        suggestions: list[dict[str, Any]] = []
        seen_categories: set[str] = set()  # avoid duplicate category suggestions

        for goal in user_goals:
            required_categories = GOAL_TO_GAP_MAP.get(goal, [])
            for category in required_categories:
                if category in covered_categories:
                    continue  # already being tracked
                if category in seen_categories:
                    continue  # already suggested for another goal

                seen_categories.add(category)

                category_info = _CATEGORY_SUGGESTIONS.get(
                    category,
                    {
                        "suggestion": f"Tracking {category} data will help with your goals.",
                        "action": f"Find an integration that captures {category} data.",
                    },
                )

                suggestion_id = str(uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"{user_id}:{goal}:{category}",
                ))

                # -------------------------------------------------------------------------
                # 5. Filter dismissed suggestions
                # -------------------------------------------------------------------------
                cache_key = f"{user_id}:{suggestion_id}"
                if _dismissal_cache.get(cache_key):
                    logger.debug(
                        "correlation_suggester: skipping dismissed suggestion=%s for user=%s",
                        suggestion_id,
                        user_id,
                    )
                    continue

                suggestions.append({
                    "id": suggestion_id,
                    "goal": goal,
                    "suggestion": category_info["suggestion"],
                    "missing_category": category,
                    "action": category_info["action"],
                })

        logger.info(
            "correlation_suggester: generated %d suggestions for user=%s goals=%s",
            len(suggestions),
            user_id,
            user_goals,
        )
        return suggestions

    async def dismiss_suggestion(
        self,
        suggestion_id: str,
        user_id: str,
    ) -> None:
        """Mark a suggestion as dismissed so it is excluded from future results.

        Stores the dismissal in the in-memory cache. This is intentionally
        ephemeral for the MVP — a persistent ``dismissed_suggestions`` DB table
        will replace this in a later phase.

        Args:
            suggestion_id: The suggestion UUID to dismiss.
            user_id: The user performing the dismissal.
        """
        cache_key = f"{user_id}:{suggestion_id}"
        _dismissal_cache_set(cache_key, True)
        logger.info(
            "correlation_suggester: user=%s dismissed suggestion=%s",
            user_id,
            suggestion_id,
        )
