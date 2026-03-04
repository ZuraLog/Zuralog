"""
Zuralog Cloud Brain — Achievement Tracker Service.

Handles unlocking achievements based on application events, persisting
unlock state to the database, and sending push notifications when a new
achievement is earned.

Usage:
    tracker = AchievementTracker(session=db, push_service=push_svc)
    unlocked = await tracker.check_and_unlock(user_id, "first_chat")
"""

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.achievement import ACHIEVEMENT_REGISTRY, Achievement
from app.services.push_service import PushService

logger = logging.getLogger(__name__)


class AchievementTracker:
    """Service for evaluating and persisting achievement unlocks.

    Attributes:
        _session: Async SQLAlchemy session for DB operations.
        _push_service: Optional push notification service. When ``None``
            (or unavailable), notifications are silently skipped.
    """

    def __init__(
        self,
        session: AsyncSession,
        push_service: PushService | None = None,
    ) -> None:
        self._session = session
        self._push_service = push_service

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def check_and_unlock(
        self,
        user_id: str,
        event: str,
        context: dict | None = None,
    ) -> list[Achievement]:
        """Evaluate an event and unlock any newly earned achievements.

        Args:
            user_id: The user who triggered the event.
            event: Event name. Supported values:
                ``"integration_connected"``, ``"chat_started"``,
                ``"insight_received"``, ``"streak_updated"``,
                ``"goal_created"``, ``"goal_completed"``.
            context: Optional event-specific data (e.g.
                ``{"streak_count": 7}`` for streak events,
                ``{"connected_count": 3}`` for integration events,
                ``{"completed_count": 5}`` for goal events,
                ``{"exceeded_by_pct": 25}`` for overachiever).

        Returns:
            List of newly unlocked :class:`Achievement` instances.
            Returns an empty list when no new achievements are earned.
        """
        if context is None:
            context = {}

        candidates: list[str] = self._candidates_for_event(event, context)
        if not candidates:
            return []

        newly_unlocked: list[Achievement] = []
        for key in candidates:
            achievement = await self._unlock(user_id, key)
            if achievement is not None:
                newly_unlocked.append(achievement)

        return newly_unlocked

    async def get_all_achievements(self, user_id: str) -> list[dict]:
        """Return all achievements with their locked/unlocked state.

        Every key in ``ACHIEVEMENT_REGISTRY`` is represented in the
        response, whether locked or not.

        Args:
            user_id: The user whose achievements to fetch.

        Returns:
            List of dicts, each containing registry metadata plus
            ``unlocked``, ``unlocked_at``, and ``achievement_key`` fields.
        """
        result = await self._session.execute(select(Achievement).where(Achievement.user_id == user_id))
        existing: dict[str, Achievement] = {row.achievement_key: row for row in result.scalars().all()}

        achievements: list[dict] = []
        for key, meta in ACHIEVEMENT_REGISTRY.items():
            row = existing.get(key)
            achievements.append(
                {
                    "achievement_key": key,
                    "title": meta["title"],
                    "description": meta["description"],
                    "category": meta["category"],
                    "icon": meta["icon"],
                    "unlocked": row is not None and row.unlocked_at is not None,
                    "unlocked_at": row.unlocked_at if row else None,
                }
            )

        return achievements

    async def get_recent_achievements(self, user_id: str, limit: int = 5) -> list[Achievement]:
        """Return the most recently unlocked achievements.

        Args:
            user_id: The user whose achievements to fetch.
            limit: Maximum number of results to return. Defaults to 5.

        Returns:
            List of :class:`Achievement` rows ordered by ``unlocked_at``
            descending (most recent first). Locked rows are excluded.
        """
        result = await self._session.execute(
            select(Achievement)
            .where(
                Achievement.user_id == user_id,
                Achievement.unlocked_at.is_not(None),
            )
            .order_by(Achievement.unlocked_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _candidates_for_event(self, event: str, context: dict) -> list[str]:
        """Map an event name to a list of candidate achievement keys.

        Args:
            event: The event identifier.
            context: Event-specific payload.

        Returns:
            List of achievement keys to attempt to unlock.
        """
        candidates: list[str] = []

        if event == "integration_connected":
            # Always check first integration
            candidates.append("first_integration")
            # Check if user now has 3+ integrations
            if context.get("connected_count", 0) >= 3:
                candidates.append("connected_3")

        elif event == "chat_started":
            candidates.append("first_chat")

        elif event == "insight_received":
            candidates.append("first_insight")

        elif event == "streak_updated":
            streak_count = context.get("streak_count", 0)
            for days, key in [
                (7, "streak_7"),
                (30, "streak_30"),
                (90, "streak_90"),
                (365, "streak_365"),
            ]:
                if streak_count >= days:
                    candidates.append(key)

        elif event == "goal_created":
            candidates.append("first_goal")

        elif event == "goal_completed":
            if context.get("completed_count", 0) >= 5:
                candidates.append("goals_5_complete")
            # Overachiever: exceeded goal by 20%+
            if context.get("exceeded_by_pct", 0) >= 20:
                candidates.append("overachiever")

        return candidates

    async def _get_existing(self, user_id: str, key: str) -> Achievement | None:
        """Fetch an existing achievement row if present.

        Args:
            user_id: The user ID.
            key: The achievement key.

        Returns:
            Existing :class:`Achievement` row, or ``None``.
        """
        result = await self._session.execute(
            select(Achievement).where(
                Achievement.user_id == user_id,
                Achievement.achievement_key == key,
            )
        )
        return result.scalars().first()

    async def _unlock(self, user_id: str, key: str) -> Achievement | None:
        """Unlock a specific achievement for a user if not already unlocked.

        Guards against duplicates: if the row already exists with a non-null
        ``unlocked_at``, this is a no-op and returns ``None``.

        Args:
            user_id: The user ID.
            key: The achievement key from ``ACHIEVEMENT_REGISTRY``.

        Returns:
            The newly created/updated :class:`Achievement`, or ``None`` if
            the achievement was already unlocked (idempotent guard).
        """
        if key not in ACHIEVEMENT_REGISTRY:
            logger.warning("Attempted to unlock unknown achievement key: %s", key)
            return None

        existing = await self._get_existing(user_id, key)
        if existing is not None and existing.unlocked_at is not None:
            # Already unlocked — idempotent, do nothing.
            return None

        now = datetime.now(tz=timezone.utc)

        if existing is not None:
            # Row exists but was locked (unlocked_at=None) — update in place.
            existing.unlocked_at = now
            await self._session.flush()
            achievement = existing
        else:
            # New row.
            achievement = Achievement(
                user_id=user_id,
                achievement_key=key,
                unlocked_at=now,
            )
            self._session.add(achievement)
            await self._session.flush()

        await self._session.commit()

        logger.info("Achievement unlocked: user=%s key=%s", user_id, key)
        self._send_push_notification(user_id, key)

        return achievement

    def _send_push_notification(self, user_id: str, key: str) -> None:
        """Send a push notification for a newly unlocked achievement.

        No-op when push_service is not configured or FCM is unavailable.
        Push tokens are fetched from the DB only if the service is available —
        this is a best-effort notification, never blocking the unlock flow.

        Args:
            user_id: The user who earned the achievement.
            key: The achievement key.
        """
        if self._push_service is None or not self._push_service.is_available:
            return

        meta = ACHIEVEMENT_REGISTRY.get(key, {})
        title = f"Achievement Unlocked: {meta.get('title', key)}"
        body = meta.get("description", "")

        # NOTE: Sending to a specific device token requires the user's FCM
        # token, which is stored in a device registration table. Since that
        # model is managed by the devices module, we log and skip here to
        # avoid a cross-service dependency. A production implementation
        # would look up the device token and call send_notification().
        logger.info(
            "Push notification ready for achievement %s (user=%s): %s — %s",
            key,
            user_id,
            title,
            body,
        )
