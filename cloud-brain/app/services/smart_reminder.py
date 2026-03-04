"""
Zuralog Cloud Brain — Smart Reminder Engine.

Generates contextually relevant reminders for users based on:
- Behavioral patterns (missing expected data)
- Goal proximity (close to daily/weekly goal)
- Celebration milestones (streaks)

Enforces per-user frequency caps and deduplication via Redis, and
respects quiet hours from user preferences.

Redis key conventions:
  reminder_count:{user_id}:{YYYY-MM-DD}    — daily reminder counter (TTL 24h)
  reminder_dedup:{user_id}:{topic_key}      — dedup set member (TTL 48h)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import date, datetime, time, timezone
from enum import Enum

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics
from app.models.user_preferences import UserPreferences

logger = logging.getLogger(__name__)


class ReminderType(str, Enum):
    """Semantic category of a smart reminder.

    Attributes:
        PATTERN: Based on behavioural history (e.g. usual run time).
        GAP: Missing expected data today.
        GOAL: User is close to hitting a daily or weekly goal.
        CELEBRATION: Positive milestone reached (streak etc.).
    """

    PATTERN = "pattern"
    GAP = "gap"
    GOAL = "goal"
    CELEBRATION = "celebration"


@dataclass
class Reminder:
    """A single generated reminder for a user.

    Attributes:
        reminder_type: Semantic category.
        title: Short notification title.
        body: Notification body text.
        user_id: Target user.
        deep_link: Optional client-side navigation URI.
        priority: 1 = highest urgency, 10 = lowest urgency.
        topic_key: Deduplication key (e.g. "steps_gap_2026-03-04").
    """

    reminder_type: ReminderType
    title: str
    body: str
    user_id: str
    deep_link: str | None = None
    priority: int = 5
    topic_key: str = field(default="")


class SmartReminderEngine:
    """Generate and deduplicate smart reminders for a user.

    Class Constants:
        MAX_REMINDERS_PER_DAY: Maximum reminders per proactivity level.
        DEDUP_WINDOW_HOURS: Hours before the same topic can be re-sent.
        STEP_GAP_THRESHOLD: Minimum steps to avoid a step-gap reminder.
        GOAL_PROXIMITY_PCT: Progress % at which a goal proximity reminder fires.
    """

    MAX_REMINDERS_PER_DAY: dict[str, int] = {
        "low": 1,
        "medium": 2,
        "high": 3,
    }
    DEDUP_WINDOW_HOURS = 48
    STEP_GAP_THRESHOLD = 500
    GOAL_PROXIMITY_PCT = 80.0

    def __init__(self, redis_client=None) -> None:
        """Initialise the engine with an optional Redis client.

        Args:
            redis_client: An aioredis (or compatible) async Redis client.
                If None, deduplication and cap checking are skipped
                (useful for testing without Redis).
        """
        self._redis = redis_client

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def generate_reminders(self, user_id: str, session: AsyncSession) -> list[Reminder]:
        """Generate a capped, deduplicated list of reminders for a user.

        Steps:
        1. Load user preferences.
        2. Check quiet hours — return empty list if in quiet window.
        3. Check daily frequency cap.
        4. Generate candidate reminders (gap, goal, celebration).
        5. Deduplicate against Redis 48h window.
        6. Sort by priority and cap to max for proactivity level.

        Args:
            user_id: Zuralog user ID.
            session: Open async DB session.

        Returns:
            List of Reminder objects (may be empty).
        """
        prefs = await self._get_preferences(user_id, session)
        proactivity = prefs.proactivity_level if prefs else "medium"

        # Quiet hours check
        if prefs and await self._is_quiet_hours(prefs):
            logger.debug("Quiet hours active for user %s — skipping reminders", user_id)
            return []

        # Daily frequency cap check
        max_for_user = self.MAX_REMINDERS_PER_DAY.get(proactivity, 2)
        already_sent = await self._get_daily_count(user_id)
        if already_sent >= max_for_user:
            logger.debug(
                "Frequency cap hit for user %s (%d/%d sent today)",
                user_id,
                already_sent,
                max_for_user,
            )
            return []

        remaining_slots = max_for_user - already_sent
        candidates: list[Reminder] = []

        # Generate candidates
        today_str = date.today().isoformat()
        metrics = await self._get_today_metrics(user_id, today_str, session)

        candidates.extend(await self._gap_reminders(user_id, today_str, metrics, prefs))
        candidates.extend(await self._goal_reminders(user_id, metrics, prefs))
        candidates.extend(await self._celebration_reminders(user_id, session))

        # Deduplicate
        deduplicated = await self._deduplicate(user_id, candidates)

        # Sort by priority (1 = highest) and cap.
        deduplicated.sort(key=lambda r: r.priority)
        return deduplicated[:remaining_slots]

    async def mark_sent(self, user_id: str, reminder_key: str) -> None:
        """Record a reminder as sent for deduplication and cap tracking.

        Sets a Redis key that expires after DEDUP_WINDOW_HOURS and
        increments the daily counter (expires after 24h).

        Args:
            user_id: Zuralog user ID.
            reminder_key: Unique topic key for this reminder.
        """
        if self._redis is None:
            return

        today_str = date.today().isoformat()
        dedup_key = f"reminder_dedup:{user_id}:{reminder_key}"
        count_key = f"reminder_count:{user_id}:{today_str}"

        try:
            pipe = self._redis.pipeline()
            pipe.set(dedup_key, "1", ex=self.DEDUP_WINDOW_HOURS * 3600)
            pipe.incr(count_key)
            pipe.expire(count_key, 86400)  # expire daily counter at 24h
            await pipe.execute()
        except Exception:  # noqa: BLE001
            logger.exception("Redis mark_sent failed for user %s key %s", user_id, reminder_key)

    # ------------------------------------------------------------------
    # Private: candidate generators
    # ------------------------------------------------------------------

    async def _gap_reminders(
        self,
        user_id: str,
        today_str: str,
        metrics: DailyHealthMetrics | None,
        prefs: UserPreferences | None,
    ) -> list[Reminder]:
        """Generate gap reminders for missing expected data.

        Args:
            user_id: Zuralog user ID.
            today_str: Today's ISO date string.
            metrics: Today's DailyHealthMetrics or None.
            prefs: User preferences or None.

        Returns:
            List of gap Reminder objects.
        """
        reminders: list[Reminder] = []

        # Steps gap: no steps or below threshold
        steps = metrics.steps if metrics else None
        if steps is None or steps < self.STEP_GAP_THRESHOLD:
            reminders.append(
                Reminder(
                    reminder_type=ReminderType.GAP,
                    title="Time to move!",
                    body="You haven't logged any steps today. A short walk can make a big difference.",
                    user_id=user_id,
                    deep_link="zuralog://metrics/steps",
                    priority=4,
                    topic_key=f"steps_gap_{today_str}",
                )
            )

        # Check-in gap: no resting HR or HRV today
        has_hr = metrics is not None and (metrics.resting_heart_rate is not None or metrics.hrv_ms is not None)
        if not has_hr:
            reminders.append(
                Reminder(
                    reminder_type=ReminderType.GAP,
                    title="Daily check-in",
                    body="Log a quick wellness check-in to track your stress and energy levels.",
                    user_id=user_id,
                    deep_link="zuralog://checkin",
                    priority=6,
                    topic_key=f"checkin_gap_{today_str}",
                )
            )

        return reminders

    async def _goal_reminders(
        self,
        user_id: str,
        metrics: DailyHealthMetrics | None,
        prefs: UserPreferences | None,
    ) -> list[Reminder]:
        """Generate goal-proximity reminders.

        Fires when the user is >= GOAL_PROXIMITY_PCT toward a step goal
        but hasn't completed it yet.

        Args:
            user_id: Zuralog user ID.
            metrics: Today's DailyHealthMetrics or None.
            prefs: User preferences with goals.

        Returns:
            List of goal Reminder objects.
        """
        reminders: list[Reminder] = []

        if prefs is None or not prefs.goals or metrics is None:
            return reminders

        for goal in prefs.goals:
            metric = goal.get("metric")
            target = goal.get("target", 0)

            if metric == "daily_steps" and metrics.steps is not None and target > 0:
                pct = (metrics.steps / target) * 100
                if self.GOAL_PROXIMITY_PCT <= pct < 100:
                    remaining = target - metrics.steps
                    reminders.append(
                        Reminder(
                            reminder_type=ReminderType.GOAL,
                            title="So close!",
                            body=f"Just {remaining:,} more steps to hit your goal today!",
                            user_id=user_id,
                            deep_link="zuralog://metrics/steps",
                            priority=2,
                            topic_key=f"steps_goal_{date.today().isoformat()}",
                        )
                    )

        return reminders

    async def _celebration_reminders(
        self,
        user_id: str,
        session: AsyncSession,
    ) -> list[Reminder]:
        """Generate streak-milestone celebration reminders.

        Currently checks for step streaks (consecutive days with steps > 500).
        Returns a celebration reminder on 7, 14, 30-day milestones.

        Args:
            user_id: Zuralog user ID.
            session: Open async DB session.

        Returns:
            List of celebration Reminder objects (0 or 1).
        """
        # Get recent daily metrics to count streak
        stmt = (
            select(DailyHealthMetrics)
            .where(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.steps.isnot(None),
                DailyHealthMetrics.steps > self.STEP_GAP_THRESHOLD,
            )
            .order_by(DailyHealthMetrics.date.desc())
            .limit(31)
        )
        result = await session.execute(stmt)
        rows = result.scalars().all()

        if not rows:
            return []

        # Count consecutive days
        streak = 0
        prev_date = None
        for row in rows:
            try:
                row_date = date.fromisoformat(row.date)
            except (ValueError, TypeError):
                break

            if prev_date is None:
                prev_date = row_date
                streak = 1
            elif (prev_date - row_date).days == 1:
                streak += 1
                prev_date = row_date
            else:
                break

        milestone_messages = {
            7: ("7-day streak! Keep going!", "You've moved every day for a week. That's real consistency."),
            14: ("14 days strong!", "Two weeks of daily activity. You're building a habit that sticks."),
            30: ("30-day champion!", "A full month of daily movement. You should be proud!"),
        }

        if streak in milestone_messages:
            title, body = milestone_messages[streak]
            return [
                Reminder(
                    reminder_type=ReminderType.CELEBRATION,
                    title=title,
                    body=body,
                    user_id=user_id,
                    deep_link="zuralog://streak",
                    priority=1,
                    topic_key=f"streak_{streak}day_{date.today().isoformat()}",
                )
            ]

        return []

    # ------------------------------------------------------------------
    # Private: Redis helpers
    # ------------------------------------------------------------------

    async def _is_quiet_hours(self, prefs: UserPreferences) -> bool:
        """Check whether the current UTC time falls within the user's quiet hours.

        Args:
            prefs: User preferences with quiet_hours_* fields.

        Returns:
            True if quiet hours are enabled and the current time is inside the window.
        """
        if not prefs.quiet_hours_enabled:
            return False
        start: time | None = prefs.quiet_hours_start
        end: time | None = prefs.quiet_hours_end
        if start is None or end is None:
            return False

        now_time = datetime.now(timezone.utc).time().replace(tzinfo=None)

        # Handle overnight window (e.g. 22:00 → 07:00)
        if start <= end:
            return start <= now_time < end
        else:
            return now_time >= start or now_time < end

    async def _get_daily_count(self, user_id: str) -> int:
        """Return the number of reminders already sent today.

        Args:
            user_id: Zuralog user ID.

        Returns:
            Integer count. Returns 0 if Redis is unavailable.
        """
        if self._redis is None:
            return 0
        today_str = date.today().isoformat()
        key = f"reminder_count:{user_id}:{today_str}"
        try:
            val = await self._redis.get(key)
            return int(val) if val else 0
        except Exception:  # noqa: BLE001
            logger.exception("Redis get_daily_count failed for user %s", user_id)
            return 0

    async def _deduplicate(self, user_id: str, candidates: list[Reminder]) -> list[Reminder]:
        """Filter out reminders whose topic_key was sent in the last 48h.

        Args:
            user_id: Zuralog user ID.
            candidates: List of candidate Reminder objects.

        Returns:
            Filtered list with already-sent topics removed.
        """
        if self._redis is None or not candidates:
            return candidates

        result: list[Reminder] = []
        for reminder in candidates:
            if not reminder.topic_key:
                result.append(reminder)
                continue
            dedup_key = f"reminder_dedup:{user_id}:{reminder.topic_key}"
            try:
                exists = await self._redis.exists(dedup_key)
                if not exists:
                    result.append(reminder)
                else:
                    logger.debug(
                        "Reminder deduplicated: user=%s key=%s",
                        user_id,
                        reminder.topic_key,
                    )
            except Exception:  # noqa: BLE001
                result.append(reminder)  # Fail open

        return result

    # ------------------------------------------------------------------
    # Private: DB helpers
    # ------------------------------------------------------------------

    @staticmethod
    async def _get_preferences(user_id: str, session: AsyncSession) -> UserPreferences | None:
        stmt = select(UserPreferences).where(UserPreferences.user_id == user_id)
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    @staticmethod
    async def _get_today_metrics(user_id: str, today_str: str, session: AsyncSession) -> DailyHealthMetrics | None:
        stmt = (
            select(DailyHealthMetrics)
            .where(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.date == today_str,
            )
            .limit(1)
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()
