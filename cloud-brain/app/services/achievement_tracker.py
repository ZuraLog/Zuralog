"""
Zuralog Cloud Brain — Achievement Tracker Service.

Hard-coded achievement registry with unlock logic. Achievements are
grouped into categories; each has a display name and description.

Unlock rules:
- ``unlock()`` is idempotent — calling it twice has no effect.
- ``check_and_unlock_streak()`` maps streak milestones to achievement keys.
- Push notifications are sent on unlock via a soft import of PushService
  to avoid circular imports and to degrade gracefully when FCM is absent.

Classes:
    - AchievementTracker: Stateless service for achievement management.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.achievement import Achievement

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Achievement registry
# ---------------------------------------------------------------------------

# Maps category name → list of (key, display_name, description) tuples.
ACHIEVEMENT_REGISTRY: dict[str, list[dict[str, str]]] = {
    "Getting Started": [
        {
            "key": "first_integration",
            "name": "First Integration",
            "description": "Connect your first health data source.",
        },
        {
            "key": "first_chat",
            "name": "First Chat",
            "description": "Have your first conversation with your AI coach.",
        },
        {
            "key": "first_insight",
            "name": "First Insight",
            "description": "Receive your first personalized health insight.",
        },
    ],
    "Consistency": [
        {
            "key": "streak_7",
            "name": "One Week Warrior",
            "description": "Maintain a 7-day activity streak.",
        },
        {
            "key": "streak_30",
            "name": "Monthly Champion",
            "description": "Maintain a 30-day activity streak.",
        },
        {
            "key": "streak_90",
            "name": "Quarterly Commitment",
            "description": "Maintain a 90-day activity streak.",
        },
        {
            "key": "streak_365",
            "name": "Year of Excellence",
            "description": "Maintain a 365-day activity streak.",
        },
    ],
    "Goals": [
        {
            "key": "first_goal",
            "name": "Goal Setter",
            "description": "Set your first health goal.",
        },
        {
            "key": "goals_5_complete",
            "name": "Goal Crusher",
            "description": "Complete 5 health goals.",
        },
        {
            "key": "overachiever",
            "name": "Overachiever",
            "description": "Exceed a goal by 25% or more.",
        },
    ],
    "Data": [
        {
            "key": "connected_3",
            "name": "Data Hub",
            "description": "Connect 3 or more health data sources.",
        },
        {
            "key": "data_rich_30",
            "name": "Data Rich",
            "description": "Log health data every day for 30 days.",
        },
        {
            "key": "full_picture_5_categories",
            "name": "Full Picture",
            "description": "Have data in 5 or more health categories.",
        },
    ],
    "Coach": [
        {
            "key": "conversations_50",
            "name": "Regular Talker",
            "description": "Have 50 conversations with your AI coach.",
        },
        {
            "key": "insights_100",
            "name": "Insight Collector",
            "description": "Receive 100 personalized health insights.",
        },
        {
            "key": "memories_20",
            "name": "Long-Term Thinker",
            "description": "Build 20 coach memories.",
        },
    ],
    "Health": [
        {
            "key": "improved_bedtime",
            "name": "Better Bedtime",
            "description": "Improve your average bedtime by 30 minutes.",
        },
        {
            "key": "personal_best",
            "name": "Personal Best",
            "description": "Set a new personal best in any tracked metric.",
        },
        {
            "key": "anomaly_aware_10",
            "name": "Anomaly Aware",
            "description": "Discover 10 health anomalies through the coach.",
        },
    ],
}

# Flat map: key → (category, definition dict) for O(1) lookups.
_KEY_INDEX: dict[str, dict[str, Any]] = {
    entry["key"]: {"category": category, **entry}
    for category, entries in ACHIEVEMENT_REGISTRY.items()
    for entry in entries
}

# Streak milestones that unlock achievements, in ascending order.
_STREAK_MILESTONES: list[tuple[int, str]] = [
    (7, "streak_7"),
    (30, "streak_30"),
    (90, "streak_90"),
    (365, "streak_365"),
]


class AchievementTracker:
    """Stateless service for achievement unlock logic and queries.

    All methods accept an ``AsyncSession`` for database access — the
    tracker itself holds no state. Instantiate once and reuse freely.
    """

    async def unlock(
        self,
        user_id: str,
        achievement_key: str,
        db: AsyncSession,
    ) -> bool:
        """Unlock an achievement for a user if not already unlocked.

        Creates the achievement row if it does not exist, then sets
        ``unlocked_at`` to the current UTC time. No-ops if the
        achievement is already unlocked.

        On success, attempts to send a push notification to the user via
        PushService; failure is logged and swallowed.

        Args:
            user_id: The authenticated user's ID.
            achievement_key: Stable key from the achievement registry.
            db: Async database session.

        Returns:
            ``True`` if the achievement was newly unlocked, ``False``
            if it was already unlocked or the key is unknown.
        """
        if achievement_key not in _KEY_INDEX:
            logger.warning(
                "unlock: unknown achievement_key='%s' for user '%s'",
                achievement_key,
                user_id,
            )
            return False

        # Fetch existing row (if any).
        result = await db.execute(
            select(Achievement).where(
                Achievement.user_id == user_id,
                Achievement.achievement_key == achievement_key,
            )
        )
        existing = result.scalar_one_or_none()

        if existing is not None and existing.unlocked_at is not None:
            logger.debug(
                "unlock: achievement '%s' already unlocked for user '%s'",
                achievement_key,
                user_id,
            )
            return False

        now = datetime.now(timezone.utc)

        if existing is None:
            # Create a new row in the unlocked state.
            new_achievement = Achievement(
                id=str(uuid.uuid4()),
                user_id=user_id,
                achievement_key=achievement_key,
                unlocked_at=now,
            )
            db.add(new_achievement)
            try:
                await db.commit()
            except IntegrityError:
                # Race condition: another request unlocked simultaneously.
                await db.rollback()
                logger.debug(
                    "unlock: race condition on '%s' for user '%s' — already exists",
                    achievement_key,
                    user_id,
                )
                return False
        else:
            # Existing locked row — set unlock timestamp.
            existing.unlocked_at = now
            await db.commit()

        logger.info(
            "unlock: achievement '%s' unlocked for user '%s'",
            achievement_key,
            user_id,
        )

        # Soft push notification — non-critical; never raises.
        self._send_unlock_notification(user_id, achievement_key)

        return True

    async def check_and_unlock_streak(
        self,
        user_id: str,
        streak_count: int,
        db: AsyncSession,
    ) -> list[str]:
        """Unlock any streak achievements earned by reaching ``streak_count``.

        Checks each milestone (7, 30, 90, 365 days) against the provided
        count and calls ``unlock()`` for each qualifying milestone.

        Args:
            user_id: The authenticated user's ID.
            streak_count: Current streak length in days.
            db: Async database session.

        Returns:
            A list of achievement keys that were newly unlocked (may be
            empty if none qualify or all were already unlocked).
        """
        newly_unlocked: list[str] = []

        for threshold, key in _STREAK_MILESTONES:
            if streak_count >= threshold:
                was_unlocked = await self.unlock(user_id, key, db)
                if was_unlocked:
                    newly_unlocked.append(key)

        return newly_unlocked

    async def get_all(
        self,
        user_id: str,
        db: AsyncSession,
    ) -> list[dict[str, Any]]:
        """Return all achievement definitions with locked/unlocked state.

        Fetches the user's unlocked achievements from the database and
        merges them with the full registry so locked achievements are
        also returned.

        Args:
            user_id: The authenticated user's ID.
            db: Async database session.

        Returns:
            A list of dicts, each containing:
                - ``key``: achievement key
                - ``name``: display name
                - ``description``: achievement description
                - ``category``: category name
                - ``unlocked_at``: ISO 8601 string or ``None``
                - ``is_unlocked``: bool
        """
        result = await db.execute(
            select(Achievement).where(Achievement.user_id == user_id)
        )
        rows = result.scalars().all()

        unlocked_map: dict[str, datetime | None] = {
            row.achievement_key: row.unlocked_at
            for row in rows
        }

        achievements: list[dict[str, Any]] = []
        for category, entries in ACHIEVEMENT_REGISTRY.items():
            for entry in entries:
                key = entry["key"]
                unlocked_at = unlocked_map.get(key)
                achievements.append(
                    {
                        "key": key,
                        "name": entry["name"],
                        "description": entry["description"],
                        "category": category,
                        "unlocked_at": unlocked_at.isoformat() if unlocked_at else None,
                        "is_unlocked": unlocked_at is not None,
                    }
                )

        return achievements

    # ---------------------------------------------------------------------------
    # Internal helpers
    # ---------------------------------------------------------------------------

    def _send_unlock_notification(self, user_id: str, achievement_key: str) -> None:
        """Send a push notification for an unlocked achievement.

        Soft import of PushService — gracefully skipped if FCM is not
        configured or an error occurs.

        Args:
            user_id: The user to notify.
            achievement_key: The achievement that was unlocked.
        """
        try:
            from app.services.push_service import PushService  # noqa: PLC0415

            definition = _KEY_INDEX.get(achievement_key, {})
            name = definition.get("name", achievement_key)

            push = PushService()
            if not push.is_available:
                return

            # PushService.send_notification requires a device token; in
            # production the token is fetched from the user's device record.
            # We log the intent here — a future task will wire up token lookup.
            logger.info(
                "_send_unlock_notification: achievement '%s' ('%s') unlocked for user '%s' — "
                "push token lookup not yet wired; notification skipped",
                achievement_key,
                name,
                user_id,
            )
        except Exception:  # noqa: BLE001
            logger.debug(
                "_send_unlock_notification: push skipped for user '%s' achievement '%s'",
                user_id,
                achievement_key,
            )
