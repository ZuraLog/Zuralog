"""
Zuralog Cloud Brain — Health Score Calculator Service.

Computes a composite 0-100 health score for a user from the last 30 days
of data stored in ``daily_health_metrics`` and ``sleep_records``.

Sub-scores are derived from percentile-based normalisation against the
user's own data window (self-relative) for metrics like HRV and resting HR,
and from absolute thresholds for step counts and sleep duration.

If a sub-score has fewer than 3 data points it is excluded and the
remaining weights are redistributed proportionally.  The score is
``None`` if there are no sleep *or* activity data points at all.
"""

import logging
import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import SleepRecord

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Minimum data requirements
# ---------------------------------------------------------------------------

# Need at least this many data points to include a sub-score.
_MIN_DATA_POINTS: int = 3

# The look-back window in calendar days.
_WINDOW_DAYS: int = 30

# ---------------------------------------------------------------------------
# Absolute benchmark constants
# ---------------------------------------------------------------------------

# Step counts below / above these thresholds map to 0 / 100.
_STEPS_GOAL: int = 10_000
_STEPS_ZERO: int = 0

# Ideal sleep band (hours).
_SLEEP_IDEAL_MIN: float = 7.0
_SLEEP_IDEAL_MAX: float = 9.0
_SLEEP_ZERO: float = 0.0
_SLEEP_MAX: float = 12.0  # anything ≥ this scores 100 before quality blend.

# ---------------------------------------------------------------------------
# AI commentary bands
# ---------------------------------------------------------------------------

_COMMENTARY: dict[tuple[int, int], str] = {
    (0, 39): "Critical — your body needs rest and recovery.",
    (40, 59): "Fair — there's room for improvement across key metrics.",
    (60, 74): "Good — you're building healthy patterns.",
    (75, 89): "Great — you're performing above average.",
    (90, 100): "Excellent — you're firing on all cylinders.",
}


def _get_commentary(score: int) -> str:
    """Return the AI commentary string for the given composite score.

    Args:
        score: Integer composite score in the range 0-100.

    Returns:
        Human-readable commentary matching the score band.
    """
    for (lo, hi), text in _COMMENTARY.items():
        if lo <= score <= hi:
            return text
    return _COMMENTARY[(90, 100)]


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class HealthSubScore:
    """Score and metadata for a single health metric dimension.

    Attributes:
        name: Human-readable metric name.
        score: 0-100 float score for this dimension.
        weight: Normalised weight applied in the composite score.
        available: Whether this sub-score has sufficient data.
    """

    name: str
    score: float
    weight: float
    available: bool


@dataclass
class HealthScoreResult:
    """Complete health score result returned by the calculator.

    Attributes:
        composite_score: 0-100 integer overall health score.
        sub_scores: Mapping of dimension key → HealthSubScore.
        ai_commentary: Short textual summary of the score band.
        calculated_at: UTC timestamp of the calculation.
        data_days: Number of distinct calendar days with data in the window.
    """

    composite_score: int
    sub_scores: dict[str, HealthSubScore]
    ai_commentary: str
    calculated_at: datetime
    data_days: int


# ---------------------------------------------------------------------------
# Pure scoring functions
# ---------------------------------------------------------------------------


def _clamp(value: float, lo: float = 0.0, hi: float = 100.0) -> float:
    """Clamp *value* to [lo, hi].

    Args:
        value: The value to clamp.
        lo: Lower bound. Defaults to 0.0.
        hi: Upper bound. Defaults to 100.0.

    Returns:
        The clamped float.
    """
    return max(lo, min(hi, value))


def _percentile_score(values: list[float], target: float, lower_is_better: bool = False) -> float:
    """Compute a 0-100 percentile score for *target* within *values*.

    Counts how many elements in *values* the target is better than.
    When ``lower_is_better`` is True a lower target beats higher elements.

    Args:
        values: The comparison set of values.
        target: The value being scored.
        lower_is_better: Reverse the direction of "better".

    Returns:
        Percentile score in 0-100.
    """
    if not values:
        return 50.0
    if lower_is_better:
        beaten = sum(1 for v in values if target <= v)
    else:
        beaten = sum(1 for v in values if target >= v)
    return _clamp(100.0 * beaten / len(values))


def _score_sleep_duration(hours: float) -> float:
    """Score sleep duration on a 0-100 scale.

    - 0 hours → 0
    - Linearly scales from 0 → 100 between 0 and 7 hours.
    - Stays 100 in the 7–9 hour ideal band.
    - Linearly decreases back toward 80 from 9 to 12 hours (oversleeping).

    Args:
        hours: Total sleep hours.

    Returns:
        0-100 duration score.
    """
    if hours <= 0.0:
        return 0.0
    if hours <= _SLEEP_IDEAL_MIN:
        return _clamp(100.0 * hours / _SLEEP_IDEAL_MIN)
    if hours <= _SLEEP_IDEAL_MAX:
        return 100.0
    # Gentle penalty for oversleeping.
    overshoot = (hours - _SLEEP_IDEAL_MAX) / (_SLEEP_MAX - _SLEEP_IDEAL_MAX)
    return _clamp(100.0 - 20.0 * overshoot)


def _score_sleep(sleep_rows: list[SleepRecord]) -> float:
    """Compute a blended sleep sub-score from duration and quality.

    - 70 % weight on duration score.
    - 30 % weight on normalised quality_score (0-100), only when available.
    - If no quality_scores are present, full weight on duration.

    Args:
        sleep_rows: List of SleepRecord ORM objects for the window.

    Returns:
        Blended 0-100 sleep score.
    """
    if not sleep_rows:
        return 0.0

    duration_scores = [_score_sleep_duration(r.hours) for r in sleep_rows]
    avg_duration_score = sum(duration_scores) / len(duration_scores)

    quality_scores = [r.quality_score for r in sleep_rows if r.quality_score is not None]
    if quality_scores:
        avg_quality = sum(quality_scores) / len(quality_scores)
        return _clamp(0.7 * avg_duration_score + 0.3 * avg_quality)
    return avg_duration_score


def _score_hrv(hrv_values: list[float]) -> float:
    """Score HRV as a percentile within the user's own 30-day window.

    Higher HRV is better.

    Args:
        hrv_values: List of daily HRV (ms) readings.

    Returns:
        0-100 percentile score.
    """
    if not hrv_values:
        return 0.0
    latest = hrv_values[-1]
    return _percentile_score(hrv_values, latest, lower_is_better=False)


def _score_resting_hr(rhr_values: list[float]) -> float:
    """Score resting heart rate as a percentile (lower is better).

    Args:
        rhr_values: List of daily resting HR (bpm) readings.

    Returns:
        0-100 percentile score.
    """
    if not rhr_values:
        return 0.0
    latest = rhr_values[-1]
    return _percentile_score(rhr_values, latest, lower_is_better=True)


def _score_activity_vs_baseline(step_values: list[int]) -> float:
    """Score today's steps versus the user's own 30-day average.

    A ratio ≥ 1.0 (at or above average) → 100.
    A ratio of 0 → 0. Linearly interpolated between.

    Args:
        step_values: Daily step counts in ascending date order.

    Returns:
        0-100 activity baseline score.
    """
    if len(step_values) < 2:
        return 50.0
    baseline = sum(step_values[:-1]) / len(step_values[:-1])
    if baseline <= 0:
        return 100.0 if step_values[-1] > 0 else 0.0
    ratio = step_values[-1] / baseline
    return _clamp(100.0 * ratio)


def _score_steps_vs_goal(steps: int) -> float:
    """Score today's steps against the absolute 10,000-step goal.

    Args:
        steps: Today's step count.

    Returns:
        0-100 score (100 at or above goal, 0 at zero steps).
    """
    if steps <= 0:
        return 0.0
    return _clamp(100.0 * steps / _STEPS_GOAL)


def _score_sleep_consistency(sleep_rows: list[SleepRecord]) -> float:
    """Score sleep schedule consistency via standard deviation of date strings.

    Uses the fractional hour of each ``date`` field to compute variation.
    Since we store date strings (YYYY-MM-DD) but not start times, we proxy
    consistency as the inverse-normalised spread of sleep durations:
    low variance → high consistency score.

    Args:
        sleep_rows: List of SleepRecord ORM objects for the window.

    Returns:
        0-100 consistency score (100 = very consistent, 0 = very erratic).
    """
    if len(sleep_rows) < 2:
        return 75.0  # Insufficient data — assume moderate consistency.

    hours = [r.hours for r in sleep_rows]
    mean = sum(hours) / len(hours)
    variance = sum((h - mean) ** 2 for h in hours) / len(hours)
    std_dev = math.sqrt(variance)

    # 0 std dev → 100 (perfect consistency), 3+ hours std dev → 0.
    max_std = 3.0
    return _clamp(100.0 * (1.0 - std_dev / max_std))


# ---------------------------------------------------------------------------
# Weight redistribution
# ---------------------------------------------------------------------------


def _redistribute_weights(
    sub_scores: dict[str, HealthSubScore],
) -> dict[str, HealthSubScore]:
    """Proportionally redistribute weights from unavailable sub-scores.

    Sub-scores marked ``available=False`` have their weight pooled and
    distributed proportionally to the remaining available sub-scores.

    Args:
        sub_scores: Mapping of dimension key → HealthSubScore.

    Returns:
        A new dict with updated ``weight`` values summing to 1.0.
    """
    available = {k: v for k, v in sub_scores.items() if v.available}
    unavailable = {k: v for k, v in sub_scores.items() if not v.available}

    if not available:
        return sub_scores

    total_available_weight = sum(v.weight for v in available.values())
    total_lost_weight = sum(v.weight for v in unavailable.values())

    if total_lost_weight == 0.0 or total_available_weight == 0.0:
        return sub_scores

    result: dict[str, HealthSubScore] = {}
    for key, ss in sub_scores.items():
        if not ss.available:
            result[key] = HealthSubScore(
                name=ss.name,
                score=ss.score,
                weight=0.0,
                available=False,
            )
        else:
            bonus = total_lost_weight * (ss.weight / total_available_weight)
            result[key] = HealthSubScore(
                name=ss.name,
                score=ss.score,
                weight=ss.weight + bonus,
                available=True,
            )
    return result


# ---------------------------------------------------------------------------
# Calculator
# ---------------------------------------------------------------------------


class HealthScoreCalculator:
    """Calculates a composite 0-100 health score for a single user.

    Queries ``daily_health_metrics`` and ``sleep_records`` for the last
    ``_WINDOW_DAYS`` days and produces a weighted sub-score composite.

    Usage::

        calculator = HealthScoreCalculator()
        result = await calculator.calculate(user_id="abc", db=session)
        if result:
            print(result.composite_score)
    """

    async def calculate(
        self,
        user_id: str,
        db: AsyncSession,
    ) -> HealthScoreResult | None:
        """Compute the health score for *user_id*.

        Args:
            user_id: The user's unique identifier string.
            db: An active async SQLAlchemy session.

        Returns:
            A ``HealthScoreResult`` if enough data is available, else ``None``.
        """
        cutoff = datetime.now(tz=timezone.utc) - timedelta(days=_WINDOW_DAYS)
        cutoff_str = cutoff.date().isoformat()

        # ------------------------------------------------------------------
        # Query daily_health_metrics for the window.
        # ------------------------------------------------------------------
        dhm_result = await db.execute(
            select(DailyHealthMetrics)
            .where(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.date >= cutoff_str,
            )
            .order_by(DailyHealthMetrics.date.asc())
        )
        dhm_rows: list[DailyHealthMetrics] = list(dhm_result.scalars().all())

        # ------------------------------------------------------------------
        # Query sleep_records for the window.
        # ------------------------------------------------------------------
        sleep_result = await db.execute(
            select(SleepRecord)
            .where(
                SleepRecord.user_id == user_id,
                SleepRecord.date >= cutoff_str,
            )
            .order_by(SleepRecord.date.asc())
        )
        sleep_rows: list[SleepRecord] = list(sleep_result.scalars().all())

        # ------------------------------------------------------------------
        # Minimum viability check.
        # ------------------------------------------------------------------
        has_sleep = len(sleep_rows) >= 1
        has_activity = any(r.steps is not None and r.steps > 0 for r in dhm_rows)
        if not has_sleep and not has_activity:
            logger.debug(
                "health_score: insufficient data for user_id=%s (no sleep or activity)",
                user_id,
            )
            return None

        # ------------------------------------------------------------------
        # Collect metric arrays (filter out None values).
        # ------------------------------------------------------------------
        hrv_values: list[float] = [r.hrv_ms for r in dhm_rows if r.hrv_ms is not None]
        rhr_values: list[float] = [r.resting_heart_rate for r in dhm_rows if r.resting_heart_rate is not None]
        step_values: list[int] = [r.steps for r in dhm_rows if r.steps is not None]

        # ------------------------------------------------------------------
        # Compute raw sub-scores and mark availability.
        # ------------------------------------------------------------------
        sleep_available = len(sleep_rows) >= _MIN_DATA_POINTS
        hrv_available = len(hrv_values) >= _MIN_DATA_POINTS
        rhr_available = len(rhr_values) >= _MIN_DATA_POINTS
        activity_baseline_available = len(step_values) >= _MIN_DATA_POINTS
        steps_goal_available = len(step_values) >= _MIN_DATA_POINTS
        sleep_consistency_available = len(sleep_rows) >= _MIN_DATA_POINTS

        raw_sub_scores: dict[str, HealthSubScore] = {
            "sleep": HealthSubScore(
                name="Sleep",
                score=_score_sleep(sleep_rows) if sleep_available else 0.0,
                weight=0.30,
                available=sleep_available,
            ),
            "hrv": HealthSubScore(
                name="HRV",
                score=_score_hrv(hrv_values) if hrv_available else 0.0,
                weight=0.20,
                available=hrv_available,
            ),
            "resting_hr": HealthSubScore(
                name="Resting Heart Rate",
                score=_score_resting_hr(rhr_values) if rhr_available else 0.0,
                weight=0.15,
                available=rhr_available,
            ),
            "activity_baseline": HealthSubScore(
                name="Activity vs Baseline",
                score=(_score_activity_vs_baseline(step_values) if activity_baseline_available else 0.0),
                weight=0.15,
                available=activity_baseline_available,
            ),
            "steps_goal": HealthSubScore(
                name="Steps vs Goal",
                score=(_score_steps_vs_goal(step_values[-1]) if steps_goal_available else 0.0),
                weight=0.10,
                available=steps_goal_available,
            ),
            "sleep_consistency": HealthSubScore(
                name="Sleep Consistency",
                score=(_score_sleep_consistency(sleep_rows) if sleep_consistency_available else 0.0),
                weight=0.10,
                available=sleep_consistency_available,
            ),
        }

        # ------------------------------------------------------------------
        # Redistribute weights and compute composite.
        # ------------------------------------------------------------------
        sub_scores = _redistribute_weights(raw_sub_scores)

        composite = sum(ss.score * ss.weight for ss in sub_scores.values() if ss.available)
        composite_int = int(round(_clamp(composite)))

        # Count distinct days that have any data.
        days_with_data: set[str] = {r.date for r in dhm_rows} | {r.date for r in sleep_rows}

        return HealthScoreResult(
            composite_score=composite_int,
            sub_scores=sub_scores,
            ai_commentary=_get_commentary(composite_int),
            calculated_at=datetime.now(tz=timezone.utc),
            data_days=len(days_with_data),
        )
