"""
Zuralog Cloud Brain — Analytics API Schemas.

Pydantic models for analytics endpoint request validation
and response serialization. Used by the analytics router to
validate incoming query parameters and serialize outgoing
results from the AnalyticsService facade.
"""

from pydantic import BaseModel, Field


class DailySummaryResponse(BaseModel):
    """Aggregated health data for a single day.

    Combines activity, nutrition, sleep, and weight data into
    a single snapshot suitable for daily summary cards.

    Attributes:
        date: ISO-8601 date string (YYYY-MM-DD).
        steps: Estimated step count for the day.
        calories_consumed: Total caloric intake in kcal.
        calories_burned: Total activity calories burned in kcal.
        workouts_count: Number of recorded workouts.
        sleep_hours: Total sleep duration in fractional hours.
        weight_kg: Most recent weight measurement, or None if absent.
    """

    date: str
    steps: int = 0
    calories_consumed: int = 0
    calories_burned: int = 0
    workouts_count: int = 0
    sleep_hours: float = 0.0
    weight_kg: float | None = None


class WeeklyTrendsResponse(BaseModel):
    """7-day trend data for dashboard charts.

    Provides parallel arrays of daily values for the most recent
    7 days, intended to be plotted together on a multi-series chart.

    Attributes:
        dates: List of 7 ISO-8601 date strings (oldest first).
        steps: Daily step counts corresponding to each date.
        calories_in: Daily caloric intake values.
        calories_out: Daily activity calories burned.
        sleep_hours: Daily sleep durations in fractional hours.
    """

    dates: list[str]
    steps: list[int]
    calories_in: list[int]
    calories_out: list[int]
    sleep_hours: list[float]


class CorrelationResponse(BaseModel):
    """Correlation analysis result between two health metrics.

    Contains the Pearson correlation coefficient and a human-readable
    interpretation of the relationship strength.

    Attributes:
        metric_x: Name of the first metric (independent variable).
        metric_y: Name of the second metric (dependent variable).
        score: Pearson correlation coefficient (-1.0 to 1.0).
        message: Human-readable description of correlation strength.
        lag: Number of days the second metric was shifted (0 = same day).
        data_points: Number of overlapping data points used.
    """

    metric_x: str
    metric_y: str
    score: float
    message: str
    lag: int = 0
    data_points: int = 0


class TrendResponse(BaseModel):
    """Trend detection result for a single metric.

    Compares recent values against a prior window to classify
    the metric's direction as up, down, or stable.

    Attributes:
        metric: Name of the analyzed metric.
        trend: Direction string — one of 'up', 'down', 'stable',
            or 'insufficient_data'.
        percent_change: Percent change between windows.
        recent_avg: Mean of the recent window.
        previous_avg: Mean of the previous window.
    """

    metric: str
    trend: str
    percent_change: float = 0.0
    recent_avg: float = 0.0
    previous_avg: float = 0.0


class GoalProgressResponse(BaseModel):
    """Progress toward a single user-defined goal.

    Attributes:
        metric: The health/fitness metric being tracked.
        period: Goal time horizon (daily, weekly, or long_term).
        target: The user's target value for the metric.
        current: The current accumulated value for the period.
        progress_pct: Percentage of target achieved.
        is_met: Whether the goal has been met or exceeded.
        remaining: Deficit remaining to meet the target (0 if met).
    """

    metric: str
    period: str
    target: float
    current: float
    progress_pct: float
    is_met: bool
    remaining: float


class GoalStreakResponse(BaseModel):
    """Streak information for a goal.

    Tracks how many consecutive recent days a user has met
    a particular goal.

    Attributes:
        metric: The health/fitness metric being tracked.
        streak_days: Number of consecutive days the goal was met.
        is_active: Whether the streak is still ongoing (most recent day met).
    """

    metric: str
    streak_days: int
    is_active: bool


class DashboardInsightResponse(BaseModel):
    """Dashboard insight of the day.

    Combines a prioritized textual insight with structured goal
    progress and trend data for the frontend dashboard.

    Attributes:
        insight: Human-readable insight string (1-2 sentences).
        goals: List of goal progress snapshots.
        trends: Mapping of metric name to trend detection result.
    """

    insight: str
    goals: list[GoalProgressResponse] = []
    trends: dict[str, TrendResponse] = {}


class UserGoalRequest(BaseModel):
    """Request body for creating or updating a user goal.

    Attributes:
        metric: Metric name (e.g., 'steps', 'calories_consumed').
        target_value: Numeric target the user wants to achieve (must be > 0).
        period: Goal time horizon — must be 'daily', 'weekly', or 'long_term'.
    """

    metric: str = Field(
        ...,
        max_length=64,
        pattern=r"^[a-z_]{1,64}$",
        description="Metric name (e.g., 'steps', 'calories_consumed')",
    )
    target_value: float = Field(
        ...,
        gt=0,
        description="Target value for the metric",
    )
    period: str = Field(
        ...,
        pattern="^(daily|weekly|long_term)$",
        description="Goal period",
    )


# ── Data Tab schemas ──────────────────────────────────────────────────────────


class CategorySummaryItem(BaseModel):
    """Summary for a single health category card on the dashboard.

    Attributes:
        category: Category slug (e.g. 'activity', 'sleep').
        primary_value: Formatted display string (e.g. '8,432', '7h 22m').
        unit: Optional unit label (e.g. 'steps', 'bpm').
        delta_percent: Week-over-week percentage change. None if insufficient data.
        trend: 7-day ordered list of raw values (oldest first). None if < 2 days.
        last_updated: ISO-8601 date string of most recent data point.
        has_data: True when real data exists for this category.
    """

    category: str
    primary_value: str = "—"
    unit: str | None = None
    delta_percent: float | None = None
    trend: list[float] | None = None
    last_updated: str | None = None
    has_data: bool = False


class DashboardSummaryResponse(BaseModel):
    """Aggregated dashboard summary for the Health Dashboard screen.

    Attributes:
        categories: List of all category summaries (up to 10).
        visible_order: Ordered list of category slugs with real data.
    """

    categories: list[CategorySummaryItem] = []
    visible_order: list[str] = []


class MetricDataPointItem(BaseModel):
    """A single time-series data point.

    Attributes:
        timestamp: ISO-8601 date string (YYYY-MM-DD).
        value: Numeric metric value.
    """

    timestamp: str
    value: float


class MetricSeriesItem(BaseModel):
    """A named time series for a single metric.

    Attributes:
        metric_id: Metric slug identifier (e.g. 'steps').
        display_name: Human-readable metric name.
        unit: Unit label.
        data_points: Ordered list of data points (oldest first).
        source_integration: Source slug (e.g. 'apple_health').
        current_value: Latest value as formatted string.
        delta_percent: Week-over-week percentage change.
        average: Mean over the selected time range.
    """

    metric_id: str
    display_name: str
    unit: str = ""
    data_points: list[MetricDataPointItem] = []
    source_integration: str | None = None
    current_value: str | None = None
    delta_percent: float | None = None
    average: float | None = None


class CategoryDetailResponse(BaseModel):
    """Full detail for a single health category.

    Attributes:
        category: Category slug.
        metrics: All metrics within this category with time-series data.
        time_range: The selected time range key (e.g. '7D').
    """

    category: str
    metrics: list[MetricSeriesItem] = []
    time_range: str = "7D"


class MetricDetailResponse(BaseModel):
    """Deep-dive data for a single metric.

    Attributes:
        series: The metric's complete time-series data.
        category: Parent category slug.
        ai_insight: Optional AI commentary for this metric.
    """

    series: MetricSeriesItem
    category: str
    ai_insight: str | None = None


# -- Trends Tab schemas -------------------------------------------------------


class ChartSeriesPointSchema(BaseModel):
    date: str
    value: float


class CorrelationHighlightSchema(BaseModel):
    id: str
    metric_a: str
    metric_b: str
    coefficient: float
    direction: str = Field(..., pattern="^(positive|negative|neutral)$")
    headline: str
    body: str
    category_color_hex: str = "#CFE1B9"
    category: str = Field(
        default="activity",
        pattern="^(activity|sleep|heart|nutrition|body|wellness)$",
    )
    discovered_at: str = ""


class TrendsHomeResponse(BaseModel):
    correlation_highlights: list[CorrelationHighlightSchema] = []
    time_periods: list[dict] = []
    has_enough_data: bool = False
    pattern_count: int = 0
    suggestion_cards: list[dict] = []


class PatternExpandResponse(BaseModel):
    id: str
    series_a: list[ChartSeriesPointSchema] = []
    series_b: list[ChartSeriesPointSchema] = []
    series_a_label: str = ""
    series_b_label: str = ""
    ai_explanation: str = ""
    data_sources: list[str] = []
    data_days: int = 0
    time_range: str = "30d"
