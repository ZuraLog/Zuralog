"""HealthScoreCalculator — composite daily health score (0-100).

Computes a weighted, percentile-ranked health score from up to six
metrics sourced from ``DailyHealthMetrics`` and ``SleepRecord``.
Each sub-score is the user's percentile rank within their own 30-day
history so the score is personal and improves as more data accumulates.
"""

import logging
import math
import statistics
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import SleepRecord, UnifiedActivity

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Weight map — must sum to 1.0
_WEIGHTS: dict[str, float] = {
    "sleep": 0.30,
    "hrv": 0.20,
    "resting_hr": 0.15,
    "activity": 0.15,
    "sleep_consistency": 0.10,
    "steps": 0.10,
}

# Metric labels for commentary.
_METRIC_LABELS: dict[str, str] = {
    "sleep": "sleep duration",
    "hrv": "HRV",
    "resting_hr": "resting heart rate",
    "activity": "active calories",
    "sleep_consistency": "sleep consistency",
    "steps": "step count",
}


# ---------------------------------------------------------------------------
# Result dataclass
# ---------------------------------------------------------------------------


@dataclass
class HealthScoreResult:
    """The computed daily health score and its supporting data.

    Attributes:
        score: Composite score from 0 to 100.
        sub_scores: Per-metric percentile scores (0-100 each).
        commentary: Rule-based one-sentence interpretation.
        contributing_metrics: Metric keys that had sufficient data.
        data_days: Number of history days available for ranking.
    """

    score: int
    sub_scores: dict[str, int]
    commentary: str
    contributing_metrics: list[str]
    data_days: int


# ---------------------------------------------------------------------------
# Calculator
# ---------------------------------------------------------------------------


class HealthScoreCalculator:
    """Compute composite daily health scores from a user's health data.

    All scoring uses percentile rank within the user's own 30-day history
    so scores are self-referential and improve as more data accumulates.
    Metrics with insufficient history are skipped and their weights are
    redistributed proportionally among present metrics.
    """

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def calculate(
        self,
        user_id: str,
        db: AsyncSession,
        target_date: date | None = None,
    ) -> HealthScoreResult | None:
        """Calculate the composite health score for a single day.

        Args:
            user_id: The user to compute the score for.
            db: Async database session.
            target_date: The day to score.  Defaults to today (UTC).

        Returns:
            A ``HealthScoreResult`` when sufficient data is present,
            or ``None`` when neither sleep nor activity data exists.
        """
        if target_date is None:
            target_date = datetime.now(tz=timezone.utc).date()

        target_str = target_date.isoformat()
        window_start = (target_date - timedelta(days=30)).isoformat()

        # ------------------------------------------------------------------
        # Fetch 30-day history windows
        # ------------------------------------------------------------------
        daily_history = await self._fetch_daily_metrics_history(db, user_id, window_start, target_str)
        sleep_history = await self._fetch_sleep_history(db, user_id, window_start, target_str)
        activity_history = await self._fetch_activity_history(db, user_id, target_date)
        sleep_consistency_stddev = await self._compute_sleep_consistency(db, user_id, target_date)

        # ------------------------------------------------------------------
        # Locate today's values
        # ------------------------------------------------------------------
        today_daily = next((r for r in daily_history if r["date"] == target_str), None)
        today_sleep = next((r for r in sleep_history if r["date"] == target_str), None)

        # Minimum requirement: at least one sleep OR activity source
        has_sleep = today_sleep is not None
        has_activity = len(activity_history) > 0 or (
            today_daily is not None and today_daily.get("active_calories") is not None
        )

        if not has_sleep and not has_activity:
            logger.debug(
                "health_score: insufficient data for user '%s' on '%s' — no sleep or activity",
                user_id,
                target_str,
            )
            return None

        # ------------------------------------------------------------------
        # Compute per-metric sub-scores via percentile rank
        # ------------------------------------------------------------------
        sub_scores: dict[str, int] = {}
        contributing: list[str] = []

        # sleep — combine hours + quality into one sub-score
        sleep_score = self._score_sleep(today_sleep, sleep_history)
        if sleep_score is not None:
            sub_scores["sleep"] = sleep_score
            contributing.append("sleep")

        # hrv — higher is better
        if today_daily and today_daily.get("hrv_ms") is not None:
            hrv_values = [r["hrv_ms"] for r in daily_history if r.get("hrv_ms") is not None]
            if hrv_values:
                sub_scores["hrv"] = self._percentile_rank(today_daily["hrv_ms"], hrv_values)
                contributing.append("hrv")

        # resting_hr — lower is better (inverted)
        if today_daily and today_daily.get("resting_heart_rate") is not None:
            hr_values = [r["resting_heart_rate"] for r in daily_history if r.get("resting_heart_rate") is not None]
            if hr_values:
                sub_scores["resting_hr"] = self._percentile_rank_inverted(
                    today_daily["resting_heart_rate"], hr_values
                )
                contributing.append("resting_hr")

        # activity — active calories vs 30-day baseline
        today_calories = today_daily.get("active_calories") if today_daily else None
        if today_calories is None:
            # Fall back to summed UnifiedActivity calories for today
            today_calories = sum(a["calories"] for a in activity_history if a["date"] == target_str)
            today_calories = today_calories if today_calories > 0 else None

        if today_calories is not None:
            cal_history = [r["active_calories"] for r in daily_history if r.get("active_calories") is not None]
            if not cal_history:
                # Use activity table as fallback for history
                cal_history = [a["calories"] for a in activity_history if a["calories"] > 0]
            if cal_history:
                sub_scores["activity"] = self._percentile_rank(today_calories, cal_history)
                contributing.append("activity")

        # sleep_consistency — lower stddev is better (inverted)
        if sleep_consistency_stddev is not None:
            # Build stddev history over rolling 7-day windows for the past 30 days
            consistency_history = await self._build_consistency_history(db, user_id, target_date)
            if consistency_history:
                sub_scores["sleep_consistency"] = self._percentile_rank_inverted(
                    sleep_consistency_stddev, consistency_history
                )
                contributing.append("sleep_consistency")

        # steps — vs personal 30-day average, capped at 100
        if today_daily and today_daily.get("steps") is not None:
            steps_history = [r["steps"] for r in daily_history if r.get("steps") is not None]
            if steps_history:
                sub_scores["steps"] = min(100, self._percentile_rank(today_daily["steps"], steps_history))
                contributing.append("steps")

        if not contributing:
            logger.debug(
                "health_score: no contributing metrics for user '%s' on '%s'",
                user_id,
                target_str,
            )
            return None

        # ------------------------------------------------------------------
        # Weighted composite (redistribute missing-metric weights)
        # ------------------------------------------------------------------
        total_weight = sum(_WEIGHTS[m] for m in contributing)
        composite = 0.0
        for metric in contributing:
            relative_weight = _WEIGHTS[metric] / total_weight
            composite += sub_scores[metric] * relative_weight

        score = max(0, min(100, round(composite)))

        # ------------------------------------------------------------------
        # Commentary
        # ------------------------------------------------------------------
        commentary = self._generate_commentary(score, sub_scores)

        data_days = len({r["date"] for r in daily_history} | {r["date"] for r in sleep_history})

        return HealthScoreResult(
            score=score,
            sub_scores=sub_scores,
            commentary=commentary,
            contributing_metrics=contributing,
            data_days=data_days,
        )

    async def get_7_day_history(
        self,
        user_id: str,
        db: AsyncSession,
    ) -> list[dict]:
        """Return the health score for each of the last 7 days.

        Calculates the score for each day independently.  Days with
        insufficient data are included with ``score: None``.

        Args:
            user_id: The user to compute history for.
            db: Async database session.

        Returns:
            A list of dicts with ``date``, ``score``, and ``sub_scores``
            keys, ordered from oldest to most recent.
        """
        today = datetime.now(tz=timezone.utc).date()
        history: list[dict] = []

        for days_ago in range(6, -1, -1):
            target = today - timedelta(days=days_ago)
            result = await self.calculate(user_id, db, target_date=target)
            if result is not None:
                history.append(
                    {
                        "date": target.isoformat(),
                        "score": result.score,
                        "sub_scores": result.sub_scores,
                    }
                )
            else:
                history.append(
                    {
                        "date": target.isoformat(),
                        "score": None,
                        "sub_scores": {},
                    }
                )

        return history

    # ------------------------------------------------------------------
    # Private helpers — data fetching
    # ------------------------------------------------------------------

    async def _fetch_daily_metrics_history(
        self,
        db: AsyncSession,
        user_id: str,
        window_start: str,
        window_end: str,
    ) -> list[dict]:
        """Fetch DailyHealthMetrics rows within the given date window.

        Args:
            db: Async database session.
            user_id: User to query.
            window_start: Inclusive ISO date lower bound (YYYY-MM-DD).
            window_end: Inclusive ISO date upper bound (YYYY-MM-DD).

        Returns:
            List of dicts with metric fields keyed by name.
        """
        stmt = select(DailyHealthMetrics).where(
            and_(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.date >= window_start,
                DailyHealthMetrics.date <= window_end,
            )
        )
        result = await db.execute(stmt)
        rows = result.scalars().all()

        # Aggregate by date — take best non-null value per date across sources
        by_date: dict[str, dict] = {}
        for row in rows:
            d = row.date
            existing = by_date.get(d, {})
            by_date[d] = {
                "date": d,
                "steps": _coalesce(existing.get("steps"), row.steps),
                "active_calories": _coalesce(existing.get("active_calories"), row.active_calories),
                "resting_heart_rate": _coalesce(existing.get("resting_heart_rate"), row.resting_heart_rate),
                "hrv_ms": _coalesce(existing.get("hrv_ms"), row.hrv_ms),
            }

        return list(by_date.values())

    async def _fetch_sleep_history(
        self,
        db: AsyncSession,
        user_id: str,
        window_start: str,
        window_end: str,
    ) -> list[dict]:
        """Fetch SleepRecord rows within the given date window.

        Args:
            db: Async database session.
            user_id: User to query.
            window_start: Inclusive ISO date lower bound (YYYY-MM-DD).
            window_end: Inclusive ISO date upper bound (YYYY-MM-DD).

        Returns:
            List of dicts with ``date``, ``hours``, and ``quality_score``.
        """
        stmt = select(SleepRecord).where(
            and_(
                SleepRecord.user_id == user_id,
                SleepRecord.date >= window_start,
                SleepRecord.date <= window_end,
            )
        )
        result = await db.execute(stmt)
        rows = result.scalars().all()

        # Aggregate by date — prefer highest hours across sources
        by_date: dict[str, dict] = {}
        for row in rows:
            d = row.date
            existing = by_date.get(d)
            if existing is None or row.hours > existing["hours"]:
                by_date[d] = {
                    "date": d,
                    "hours": row.hours,
                    "quality_score": row.quality_score,
                }

        return list(by_date.values())

    async def _fetch_activity_history(
        self,
        db: AsyncSession,
        user_id: str,
        target_date: date,
    ) -> list[dict]:
        """Fetch UnifiedActivity rows for the 30-day window ending on target_date.

        Args:
            db: Async database session.
            user_id: User to query.
            target_date: The day to score (upper bound, inclusive).

        Returns:
            List of dicts with ``date``, ``calories``, and ``duration_seconds``.
        """
        window_start_dt = datetime(
            *(target_date - timedelta(days=30)).timetuple()[:3],
            tzinfo=timezone.utc,
        )
        window_end_dt = datetime(
            *target_date.timetuple()[:3],
            23,
            59,
            59,
            tzinfo=timezone.utc,
        )

        stmt = select(UnifiedActivity).where(
            and_(
                UnifiedActivity.user_id == user_id,
                UnifiedActivity.start_time >= window_start_dt,
                UnifiedActivity.start_time <= window_end_dt,
            )
        )
        result = await db.execute(stmt)
        rows = result.scalars().all()

        return [
            {
                "date": row.start_time.date().isoformat(),
                "calories": row.calories,
                "duration_seconds": row.duration_seconds,
            }
            for row in rows
        ]

    async def _compute_sleep_consistency(
        self,
        db: AsyncSession,
        user_id: str,
        target_date: date,
    ) -> float | None:
        """Compute stddev of sleep record dates over the 7 days ending on target_date.

        Uses the date string of each sleep record as a proxy for sleep timing
        (actual bedtime is not stored).  Lower stddev means more consistent sleep.

        Args:
            db: Async database session.
            user_id: User to query.
            target_date: The end of the 7-day window.

        Returns:
            Standard deviation in days, or ``None`` if fewer than 3 records.
        """
        window_start = (target_date - timedelta(days=6)).isoformat()
        window_end = target_date.isoformat()

        stmt = select(SleepRecord).where(
            and_(
                SleepRecord.user_id == user_id,
                SleepRecord.date >= window_start,
                SleepRecord.date <= window_end,
            )
        )
        result = await db.execute(stmt)
        rows = result.scalars().all()

        if len(rows) < 3:
            return None

        # Convert date strings to ordinal numbers for stddev computation
        ordinals = [date.fromisoformat(r.date).toordinal() for r in rows]
        try:
            return statistics.stdev(ordinals)
        except statistics.StatisticsError:
            return None

    async def _build_consistency_history(
        self,
        db: AsyncSession,
        user_id: str,
        target_date: date,
    ) -> list[float]:
        """Build a list of 7-day sleep consistency stddevs over the past 30 days.

        Used to rank today's consistency against recent history.

        Args:
            db: Async database session.
            user_id: User to query.
            target_date: The day being scored.

        Returns:
            List of stddev values (one per rolling window with ≥3 records).
        """
        stddevs: list[float] = []
        for offset in range(1, 31):
            past_date = target_date - timedelta(days=offset)
            stddev = await self._compute_sleep_consistency(db, user_id, past_date)
            if stddev is not None:
                stddevs.append(stddev)
        return stddevs

    # ------------------------------------------------------------------
    # Private helpers — scoring
    # ------------------------------------------------------------------

    @staticmethod
    def _percentile_rank(value: float, history: list[float]) -> int:
        """Compute percentile rank of ``value`` within ``history`` (higher = better).

        Args:
            value: Today's metric value.
            history: Historical values including today.

        Returns:
            Integer in [0, 100].
        """
        if not history:
            return 50
        below = sum(1 for h in history if h < value)
        return min(100, round((below / len(history)) * 100))

    @staticmethod
    def _percentile_rank_inverted(value: float, history: list[float]) -> int:
        """Percentile rank where *lower* values are *better* (e.g. resting HR, stddev).

        Args:
            value: Today's metric value.
            history: Historical values including today.

        Returns:
            Integer in [0, 100].
        """
        if not history:
            return 50
        above = sum(1 for h in history if h > value)
        return min(100, round((above / len(history)) * 100))

    @staticmethod
    def _score_sleep(
        today_sleep: dict | None,
        sleep_history: list[dict],
    ) -> int | None:
        """Combine sleep duration and quality into a single sub-score.

        Duration is ranked by percentile (higher hours = better).
        If a quality score exists, it is blended 70/30 with duration rank.

        Args:
            today_sleep: Today's sleep record dict (may be None).
            sleep_history: 30-day sleep history dicts.

        Returns:
            Sub-score 0-100, or ``None`` if no sleep data for today.
        """
        if today_sleep is None:
            return None

        hours_history = [r["hours"] for r in sleep_history if r.get("hours") is not None]
        if not hours_history:
            return None

        below = sum(1 for h in hours_history if h < today_sleep["hours"])
        duration_score = min(100, round((below / len(hours_history)) * 100))

        quality = today_sleep.get("quality_score")
        if quality is not None:
            # Blend: 70% duration rank, 30% raw quality (already 0-100)
            blended = 0.70 * duration_score + 0.30 * quality
            return min(100, round(blended))

        return duration_score

    @staticmethod
    def _generate_commentary(score: int, sub_scores: dict[str, int]) -> str:
        """Generate a rule-based one-sentence interpretation of the score.

        Args:
            score: Composite health score 0-100.
            sub_scores: Per-metric sub-scores used to find the weakest area.

        Returns:
            A short, human-readable sentence.
        """
        if not sub_scores:
            return "Not enough data to generate detailed commentary today."

        lowest_metric = min(sub_scores, key=sub_scores.__getitem__)
        lowest_label = _METRIC_LABELS.get(lowest_metric, lowest_metric)

        if score >= 80:
            return "Your body is in excellent shape today — keep it up."
        elif score >= 60:
            return f"A solid day overall, with room to improve {lowest_label}."
        elif score >= 40:
            return f"Your {lowest_label} is pulling your score down — worth focusing on."
        else:
            return "Today's data suggests your body needs recovery — prioritize rest and hydration."


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------


def _coalesce(*values):
    """Return the first non-None value, or None if all are None.

    Args:
        *values: Candidate values to check in order.

    Returns:
        First non-None value found, else None.
    """
    for v in values:
        if v is not None:
            return v
    return None
