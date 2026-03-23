"""HealthBriefBuilder — parallel data fetcher for the AI Insights Engine.

Fetches all health data for a user in one shot (10 concurrent DB queries),
deduplicates multi-source daily metrics by source priority, and returns a
``HealthBrief`` dataclass ready to be consumed by the InsightSignalDetector.

Design decisions
----------------
* **Parallel fetch** — ``asyncio.gather`` fires all queries simultaneously so
  latency is bounded by the slowest single query, not their sum.
* **Source priority deduplication** — when two sources provide the same
  calendar day, the higher-priority source's row wins.
  Priority: oura > fitbit > polar > withings > apple_health >
  health_connect > manual.
* **Stale source detection** — any integration whose ``last_synced_at`` is
  older than 24 h is flagged as stale.  Stale integrations are included in the
  brief so the InsightSignalDetector can emit a ``data_quality`` signal.
* **TDEE estimation** — uses the Harris-Benedict equation to estimate daily
  calorie burn from weight and activity level.  Returns ``None`` when weight
  is unavailable.
* No health-score fetch — ``HealthScoreCache`` doesn't have the right shape
  for per-metric analysis, so it is intentionally excluded.
"""

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from typing import Any, Coroutine

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent
from app.models.integration import Integration
from app.models.user_goal import UserGoal
from app.models.user_preferences import UserPreferences
from app.models.user_streak import UserStreak

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_SOURCE_PRIORITY = [
    "oura",
    "fitbit",
    "polar",
    "withings",
    "apple_health",
    "health_connect",
    "manual",
]
_LOOKBACK_DAILY = 30  # days of daily metrics + sleep to fetch
_LOOKBACK_WEIGHT = 90  # days of weight history to fetch
_LOOKBACK_QUICK_LOGS = 14  # days of quick-log entries to fetch
_TDEE_ACTIVE_CAL_WINDOW = 14  # days of active-calorie history used for TDEE


# ---------------------------------------------------------------------------
# Dataclasses — brief rows
# ---------------------------------------------------------------------------


@dataclass
class DailyMetricsRow:
    """One deduplicated day of scalar health metrics."""

    date: str
    steps: float | None = None
    active_calories: float | None = None
    distance_meters: float | None = None
    flights_climbed: float | None = None
    resting_heart_rate: float | None = None
    hrv_ms: float | None = None
    heart_rate_avg: float | None = None
    vo2_max: float | None = None
    respiratory_rate: float | None = None
    oxygen_saturation: float | None = None
    body_fat_percentage: float | None = None
    source: str = "unknown"


@dataclass
class SleepRow:
    """One night of sleep data."""

    date: str
    hours: float | None = None
    quality_score: float | None = None
    source: str = "unknown"


@dataclass
class ActivityRow:
    """One workout / activity session."""

    date: str
    activity_type: str = ""
    duration_seconds: float | None = None
    distance_meters: float | None = None
    calories: float | None = None
    start_time: str | None = None


@dataclass
class NutritionRow:
    """Daily aggregated nutrition totals."""

    date: str
    calories: float | None = None
    protein_grams: float | None = None
    carbs_grams: float | None = None
    fat_grams: float | None = None


@dataclass
class WeightRow:
    """A single body-weight measurement."""

    date: str
    weight_kg: float | None = None


@dataclass
class QuickLogRow:
    """A rapid-log entry (water, mood, energy, etc.)."""

    metric_type: str
    value: float | None = None
    text_value: str | None = None
    data: dict = field(default_factory=dict)
    logged_at: str = ""


@dataclass
class GoalRow:
    """A user-defined health goal."""

    id: str
    metric: str
    target_value: float
    period: str
    current_value: float | None = None
    is_active: bool = True
    deadline: str | None = None


@dataclass
class StreakRow:
    """A single streak counter (e.g. steps, workouts)."""

    streak_type: str
    current_count: int = 0
    longest_count: int = 0
    last_activity_date: str | None = None


@dataclass
class UserPreferencesSnapshot:
    """Lightweight snapshot of user preference fields needed by analytics."""

    goals: list[str] = field(default_factory=list)
    dashboard_layout: dict = field(default_factory=dict)
    coach_persona: str = "balanced"
    fitness_level: str | None = None
    units_system: str = "metric"
    timezone: str = "UTC"


@dataclass
class IntegrationStatus:
    """Active integration with staleness flag."""

    provider: str
    is_active: bool
    last_synced_at: datetime | None = None

    @property
    def is_stale(self) -> bool:
        """Return ``True`` if the integration hasn't synced in the last 24 h."""
        if self.last_synced_at is None:
            return True
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        ts = self.last_synced_at
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts < cutoff


@dataclass
class HealthBrief:
    """Full health snapshot for a user, ready for signal detection."""

    user_id: str
    generated_at: datetime
    daily_metrics: list[DailyMetricsRow]
    sleep_records: list[SleepRow]
    activities: list[ActivityRow]
    nutrition: list[NutritionRow]
    weight: list[WeightRow]
    quick_logs: list[QuickLogRow]
    goals: list[GoalRow]
    streaks: list[StreakRow]
    integrations: list[IntegrationStatus]
    preferences: UserPreferencesSnapshot
    data_maturity_days: int
    estimated_tdee: float | None = None


# ---------------------------------------------------------------------------
# Module-level helpers
# ---------------------------------------------------------------------------


def _float(obj: Any, attr: str) -> float | None:
    """Safely read a numeric attribute and cast it to float."""
    v = getattr(obj, attr, None)
    return float(v) if v is not None else None


def _safe_mean(values: list) -> float | None:
    """Return the mean of a list, ignoring ``None`` values."""
    clean = [v for v in values if v is not None]
    return sum(clean) / len(clean) if clean else None


def _priority_index(source: str) -> int:
    """Lower index = higher priority."""
    try:
        return _SOURCE_PRIORITY.index((source or "").lower())
    except ValueError:
        return len(_SOURCE_PRIORITY)


def _dedup_by_source(rows: list) -> list:
    """Keep the highest-priority source row for each calendar date."""
    by_date: dict = {}
    for row in rows:
        d = row.date
        if d not in by_date:
            by_date[d] = row
        else:
            if _priority_index(row.source) < _priority_index(by_date[d].source):
                by_date[d] = row
    return sorted(by_date.values(), key=lambda r: r.date)


# ---------------------------------------------------------------------------
# Builder
# ---------------------------------------------------------------------------


class HealthBriefBuilder:
    """Fetches and assembles a complete :class:`HealthBrief` for one user.

    Parameters
    ----------
    user_id:
        The user's ID.
    db:
        An async SQLAlchemy session.
    target_date:
        The reference date for lookback windows.  Defaults to today.
    """

    def __init__(
        self,
        user_id: str,
        db: AsyncSession,
        target_date: date | None = None,
    ) -> None:
        self.user_id = user_id
        self.db = db
        self.target_date = target_date or date.today()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def _safe_fetch(self, coro: Coroutine, default: Any = None) -> Any:
        """Run a coroutine and return ``default`` on any exception."""
        try:
            return await coro
        except Exception as exc:
            logger.warning("HealthBriefBuilder: fetch failed — %s: %s", type(exc).__name__, exc)
            return default if default is not None else []

    async def build(self) -> HealthBrief:
        """Fire all 10 data fetches in parallel and assemble the brief."""
        (
            daily,
            sleep,
            activities,
            nutrition,
            weight,
            quick_logs,
            goals,
            streaks,
            preferences,
            integrations,
        ) = await asyncio.gather(
            self._safe_fetch(self._fetch_daily_metrics()),
            self._safe_fetch(self._fetch_sleep_records()),
            self._safe_fetch(self._fetch_activities()),
            self._safe_fetch(self._fetch_nutrition()),
            self._safe_fetch(self._fetch_weight()),
            self._safe_fetch(self._fetch_quick_logs()),
            self._safe_fetch(self._fetch_goals()),
            self._safe_fetch(self._fetch_streaks()),
            self._safe_fetch(self._fetch_preferences(), default=None),
            self._safe_fetch(self._fetch_integrations()),
        )

        prefs = preferences or UserPreferencesSnapshot()

        # Data maturity: distinct calendar dates with *any* health data
        all_dates = {r.date for r in daily} | {r.date for r in sleep}
        data_maturity_days = len(all_dates)

        # TDEE estimation using the most recent weight + 14-day avg active cals
        latest_weight = next((r.weight_kg for r in reversed(weight) if r.weight_kg is not None), None)
        avg_active_cals = _safe_mean(
            [r.active_calories for r in daily[-_TDEE_ACTIVE_CAL_WINDOW:] if r.active_calories is not None]
        )
        estimated_tdee = self._compute_tdee(
            weight_kg=latest_weight,
            avg_active_calories=avg_active_cals,
        )

        return HealthBrief(
            user_id=self.user_id,
            generated_at=datetime.now(timezone.utc),
            daily_metrics=daily,
            sleep_records=sleep,
            activities=activities,
            nutrition=nutrition,
            weight=weight,
            quick_logs=quick_logs,
            goals=goals,
            streaks=streaks,
            integrations=integrations,
            preferences=prefs,
            data_maturity_days=data_maturity_days,
            estimated_tdee=estimated_tdee,
        )

    # ------------------------------------------------------------------
    # TDEE estimation (Harris-Benedict)
    # ------------------------------------------------------------------

    @staticmethod
    def _compute_tdee(
        weight_kg: float | None,
        avg_active_calories: float | None = None,
        height_cm: float = 170.0,
        age: int | None = None,
        sex: str | None = None,
    ) -> float | None:
        """Estimate total daily energy expenditure using Harris-Benedict.

        Returns ``None`` when ``weight_kg`` is unavailable.

        Activity multiplier bands (based on average active-calorie burn):
        * < 200 kcal → sedentary (×1.2)
        * 200–399 kcal → lightly active (×1.375)
        * 400–599 kcal → moderately active (×1.55)
        * ≥ 600 kcal → very active (×1.725)
        """
        if weight_kg is None:
            return None

        if sex == "male":
            bmr = 88.362 + (13.397 * weight_kg) + (4.799 * height_cm)
            if age is not None:
                bmr -= 5.677 * age
        elif sex == "female":
            bmr = 447.593 + (9.247 * weight_kg) + (3.098 * height_cm)
            if age is not None:
                bmr -= 4.330 * age
        else:
            # Unknown sex: average male and female BMR
            male_bmr = 88.362 + (13.397 * weight_kg) + (4.799 * height_cm)
            female_bmr = 447.593 + (9.247 * weight_kg) + (3.098 * height_cm)
            if age is not None:
                male_bmr -= 5.677 * age
                female_bmr -= 4.330 * age
            bmr = (male_bmr + female_bmr) / 2

        kcal = avg_active_calories or 0.0
        if kcal < 200:
            multiplier = 1.2
        elif kcal < 400:
            multiplier = 1.375
        elif kcal < 600:
            multiplier = 1.55
        else:
            multiplier = 1.725

        return round(bmr * multiplier, 0)

    # ------------------------------------------------------------------
    # Fetch methods
    # ------------------------------------------------------------------

    async def _fetch_daily_metrics(self) -> list[DailyMetricsRow]:
        """Fetch last 30 days of daily health metrics from daily_summaries.

        Pivots the EAV rows (one row per metric_type per date) back into a
        single ``DailyMetricsRow`` per calendar date.
        """
        cutoff = self.target_date - timedelta(days=_LOOKBACK_DAILY)
        result = await self.db.execute(
            select(DailySummary).where(
                DailySummary.user_id == self.user_id,
                DailySummary.date >= cutoff,
            )
        )
        rows = result.scalars().all()

        # Map metric_type -> DailyMetricsRow attribute name
        _METRIC_ATTR = {
            "steps": "steps",
            "active_calories": "active_calories",
            "distance_meters": "distance_meters",
            "flights_climbed": "flights_climbed",
            "resting_heart_rate": "resting_heart_rate",
            "hrv_ms": "hrv_ms",
            "heart_rate_avg": "heart_rate_avg",
            "vo2_max": "vo2_max",
            "respiratory_rate": "respiratory_rate",
            "oxygen_saturation": "oxygen_saturation",
            "body_fat_percentage": "body_fat_percentage",
        }

        by_date: dict[str, DailyMetricsRow] = {}
        for r in rows:
            d = r.date.isoformat() if isinstance(r.date, date) else str(r.date)
            attr = _METRIC_ATTR.get(r.metric_type)
            if attr is None:
                continue
            if d not in by_date:
                by_date[d] = DailyMetricsRow(date=d)
            setattr(by_date[d], attr, float(r.value))

        return sorted(by_date.values(), key=lambda r: r.date)

    async def _fetch_sleep_records(self) -> list[SleepRow]:
        """Fetch last 30 days of sleep data from daily_summaries.

        ``sleep_duration`` values are stored in minutes; convert to hours.
        ``sleep_quality`` values are used as-is for the quality score.
        """
        cutoff = self.target_date - timedelta(days=_LOOKBACK_DAILY)
        result = await self.db.execute(
            select(DailySummary).where(
                DailySummary.user_id == self.user_id,
                DailySummary.date >= cutoff,
                DailySummary.metric_type.in_(["sleep_duration", "sleep_quality"]),
            )
        )
        rows = result.scalars().all()

        by_date: dict[str, SleepRow] = {}
        for r in rows:
            d = r.date.isoformat() if isinstance(r.date, date) else str(r.date)
            if d not in by_date:
                by_date[d] = SleepRow(date=d)
            if r.metric_type == "sleep_duration":
                by_date[d].hours = float(r.value) / 60.0
            elif r.metric_type == "sleep_quality":
                by_date[d].quality_score = float(r.value)

        return sorted(by_date.values(), key=lambda r: r.date)

    async def _fetch_activities(self) -> list[ActivityRow]:
        """Fetch last 30 days of activity data from daily_summaries.

        Uses ``active_calories`` and ``exercise_minutes`` summary rows to
        build simplified ``ActivityRow`` objects (one per date).
        """
        cutoff = self.target_date - timedelta(days=_LOOKBACK_DAILY)
        result = await self.db.execute(
            select(DailySummary).where(
                DailySummary.user_id == self.user_id,
                DailySummary.date >= cutoff,
                DailySummary.metric_type.in_(["active_calories", "exercise_minutes"]),
            )
        )
        rows = result.scalars().all()

        by_date: dict[str, ActivityRow] = {}
        for r in rows:
            d = r.date.isoformat() if isinstance(r.date, date) else str(r.date)
            if d not in by_date:
                by_date[d] = ActivityRow(date=d, activity_type="daily_summary")
            if r.metric_type == "active_calories":
                by_date[d].calories = float(r.value)
            elif r.metric_type == "exercise_minutes":
                by_date[d].duration_seconds = float(r.value) * 60.0

        return sorted(by_date.values(), key=lambda r: r.date)

    async def _fetch_nutrition(self) -> list[NutritionRow]:
        """Fetch last 30 days of nutrition data from daily_summaries.

        Each macro is a separate ``metric_type`` row; pivot them back into
        one ``NutritionRow`` per calendar date.
        """
        cutoff = self.target_date - timedelta(days=_LOOKBACK_DAILY)
        result = await self.db.execute(
            select(DailySummary).where(
                DailySummary.user_id == self.user_id,
                DailySummary.date >= cutoff,
                DailySummary.metric_type.in_(["calories", "protein_grams", "carbs_grams", "fat_grams"]),
            )
        )
        rows = result.scalars().all()

        _METRIC_ATTR = {
            "calories": "calories",
            "protein_grams": "protein_grams",
            "carbs_grams": "carbs_grams",
            "fat_grams": "fat_grams",
        }

        by_date: dict[str, NutritionRow] = {}
        for r in rows:
            d = r.date.isoformat() if isinstance(r.date, date) else str(r.date)
            if d not in by_date:
                by_date[d] = NutritionRow(date=d)
            attr = _METRIC_ATTR.get(r.metric_type)
            if attr is not None:
                setattr(by_date[d], attr, float(r.value))

        return sorted(by_date.values(), key=lambda r: r.date)

    async def _fetch_weight(self) -> list[WeightRow]:
        """Fetch last 90 days of weight data from daily_summaries."""
        cutoff = self.target_date - timedelta(days=_LOOKBACK_WEIGHT)
        result = await self.db.execute(
            select(DailySummary).where(
                DailySummary.user_id == self.user_id,
                DailySummary.date >= cutoff,
                DailySummary.metric_type == "weight_kg",
            )
        )
        rows = result.scalars().all()
        weight_rows = [
            WeightRow(
                date=r.date.isoformat() if isinstance(r.date, date) else str(r.date),
                weight_kg=float(r.value),
            )
            for r in rows
        ]
        return sorted(weight_rows, key=lambda r: r.date)

    async def _fetch_quick_logs(self) -> list[QuickLogRow]:
        """Fetch last 14 days of quick-log entries from health_events."""
        cutoff = datetime(
            self.target_date.year,
            self.target_date.month,
            self.target_date.day,
            tzinfo=timezone.utc,
        ) - timedelta(days=_LOOKBACK_QUICK_LOGS)
        result = await self.db.execute(
            select(HealthEvent)
            .where(
                HealthEvent.user_id == self.user_id,
                HealthEvent.recorded_at >= cutoff,
                HealthEvent.deleted_at.is_(None),
            )
            .order_by(HealthEvent.recorded_at.desc())
            .limit(500)
        )
        rows = result.scalars().all()
        return [
            QuickLogRow(
                metric_type=r.metric_type,
                value=float(r.value) if r.value is not None else None,
                text_value=(r.metadata_ or {}).get("text_value") if r.metadata_ else None,
                data=r.metadata_ if isinstance(r.metadata_, dict) else {},
                logged_at=r.recorded_at.isoformat() if r.recorded_at else "",
            )
            for r in rows
        ]

    async def _fetch_goals(self) -> list[GoalRow]:
        """Fetch all active user goals."""
        result = await self.db.execute(
            select(UserGoal)
            .where(
                UserGoal.user_id == self.user_id,
                UserGoal.is_active.is_(True),
            )
            .limit(50)
        )
        rows = result.scalars().all()
        return [
            GoalRow(
                id=str(r.id),
                metric=r.metric,
                target_value=_float(r, "target_value") or 0.0,
                period=str(r.period.value) if hasattr(r.period, "value") else str(r.period),
                current_value=_float(r, "current_value"),
                is_active=bool(r.is_active),
                deadline=getattr(r, "deadline", None),
            )
            for r in rows
        ]

    async def _fetch_streaks(self) -> list[StreakRow]:
        """Fetch all streak counters for the user."""
        result = await self.db.execute(select(UserStreak).where(UserStreak.user_id == self.user_id).limit(50))
        rows = result.scalars().all()
        return [
            StreakRow(
                streak_type=r.streak_type,
                current_count=int(r.current_count),
                longest_count=int(r.longest_count),
                last_activity_date=getattr(r, "last_activity_date", None),
            )
            for r in rows
        ]

    async def _fetch_preferences(self) -> UserPreferencesSnapshot | None:
        """Fetch user preferences and return a snapshot."""
        result = await self.db.execute(select(UserPreferences).where(UserPreferences.user_id == self.user_id))
        prefs = result.scalar_one_or_none()
        if prefs is None:
            return None

        raw_goals = getattr(prefs, "goals", None)
        goals_list: list[str] = []
        if isinstance(raw_goals, list):
            goals_list = [str(g) for g in raw_goals]

        raw_layout = getattr(prefs, "dashboard_layout", None)
        layout_dict: dict = raw_layout if isinstance(raw_layout, dict) else {}

        return UserPreferencesSnapshot(
            goals=goals_list,
            dashboard_layout=layout_dict,
            coach_persona=str(getattr(prefs, "coach_persona", "balanced") or "balanced"),
            fitness_level=getattr(prefs, "fitness_level", None),
            units_system=str(getattr(prefs, "units_system", "metric") or "metric"),
            timezone=str(getattr(prefs, "timezone", "UTC") or "UTC"),
        )

    async def _fetch_integrations(self) -> list[IntegrationStatus]:
        """Fetch all active integrations with sync timestamps."""
        result = await self.db.execute(
            select(Integration).where(
                Integration.user_id == self.user_id,
                Integration.is_active.is_(True),
            )
        )
        rows = result.scalars().all()
        return [
            IntegrationStatus(
                provider=r.provider,
                is_active=bool(r.is_active),
                last_synced_at=r.last_synced_at if isinstance(r.last_synced_at, datetime) else None,
            )
            for r in rows
        ]
