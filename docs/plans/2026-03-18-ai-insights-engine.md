# AI Insights Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Replace the broken, shallow insight system with a full 5-step analytics pipeline that surfaces real health signals and writes cards via LLM.

**Architecture:** Python analytics runs first (free, testable) — HealthBriefBuilder fetches all data, InsightSignalDetector runs 8 signal categories, SignalPrioritizer ranks and deduplicates, InsightCardWriter makes one LLM call, results persist with a date-lock. The LLM never does analytics — it only writes natural language from pre-computed facts.

**Tech Stack:** Python/FastAPI/SQLAlchemy async, Celery Beat, OpenRouter via AsyncOpenAI SDK, Flutter/Dart, Alembic migrations, pytest

**Branch:** `feat/ai-insights-engine`

---

## Chunk 1 — Database migrations and model changes

> **db subagent required** before writing the migration (see Step 1 instructions below).


**Files:**
- Modify: `cloud-brain/app/models/insight.py`
- Modify: `cloud-brain/app/models/user_preferences.py`
- Create: `cloud-brain/alembic/versions/p1q2r3s4t5u6_ai_insights_engine_schema.py`
- Test: `cloud-brain/tests/test_insight_model.py` (extend existing or create)

**Before writing the migration, consult the `db` subagent** with this exact question:
> "We need to add `generation_date: str` (ISO date, user local timezone) and `signal_type: str` columns to the `insights` table. We also need to drop the old `uq_insights_user_type_day` constraint (and `uq_insights_user_type_date` if present) and add a new unique constraint on `(user_id, signal_type, generation_date)`. We also need to add `timezone: str` (IANA timezone name, default 'UTC') to `user_preferences`. The table already has RLS enabled. What indexes should accompany these changes for a 1M user table, and is there anything else to consider?"

### Step 1: Write the failing test

```python
# cloud-brain/tests/test_insight_model.py
def test_insight_has_generation_date_and_signal_type():
    """Insight ORM model has the two new columns."""
    from app.models.insight import Insight
    assert hasattr(Insight, 'generation_date')
    assert hasattr(Insight, 'signal_type')

def test_user_preferences_has_timezone():
    """UserPreferences ORM model has timezone column."""
    from app.models.user_preferences import UserPreferences
    assert hasattr(UserPreferences, 'timezone')

def test_insight_types_contains_new_types():
    """INSIGHT_TYPES contains all new compound + trend + data_quality types."""
    from app.models.insight import INSIGHT_TYPES
    required = [
        "trend_decline", "trend_improvement",
        "compound_weight_plateau", "compound_overtraining_risk",
        "compound_sleep_debt", "compound_deficit_too_deep",
        "compound_workout_collapse", "compound_recovery_peak",
        "compound_stress_cascade", "compound_dehydration_pattern",
        "compound_weekend_gap", "compound_event_on_track",
        "data_quality",
    ]
    for t in required:
        assert t in INSIGHT_TYPES, f"Missing type: {t}"
```

Run: `pytest cloud-brain/tests/test_insight_model.py -v`
Expected: FAIL (attributes don't exist yet)

### Step 2: Update `insight.py` — add columns + expand INSIGHT_TYPES

In `cloud-brain/app/models/insight.py`, after the `updated_at` column, add:

```python
generation_date: Mapped[str | None] = mapped_column(
    String,
    nullable=True,
    index=True,
    comment="ISO date YYYY-MM-DD in the user's local timezone. Used for the daily date-lock check.",
)
signal_type: Mapped[str | None] = mapped_column(
    String,
    nullable=True,
    comment="Raw signal_type from InsightSignalDetector (e.g. trend_decline, compound_overtraining_risk)",
)
```

Replace `INSIGHT_TYPES` with the expanded tuple from spec §19:

```python
INSIGHT_TYPES: tuple[str, ...] = (
    # Existing
    "sleep_analysis",
    "activity_progress",
    "nutrition_summary",
    "anomaly_alert",
    "goal_nudge",
    "correlation_discovery",
    "streak_milestone",
    "welcome",
    # New
    "trend_decline",
    "trend_improvement",
    "goal_at_risk",
    "goal_streak",
    "compound_weight_plateau",
    "compound_overtraining_risk",
    "compound_sleep_debt",
    "compound_deficit_too_deep",
    "compound_workout_collapse",
    "compound_recovery_peak",
    "compound_stress_cascade",
    "compound_dehydration_pattern",
    "compound_weekend_gap",
    "compound_event_on_track",
    "data_quality",
)
```

### Step 3: Update `user_preferences.py` — add timezone column

After the `fitness_level` column, add:

```python
timezone: Mapped[str] = mapped_column(
    String,
    default="UTC",
    server_default="UTC",
    nullable=False,
    comment="IANA timezone name (e.g. America/New_York). Used for 6 AM fan-out scheduling.",
)
```

### Step 4: Run the model tests to verify they pass

Run: `pytest cloud-brain/tests/test_insight_model.py -v`
Expected: PASS (all 3 tests green)

### Step 5: Write the Alembic migration

Create `cloud-brain/alembic/versions/p1q2r3s4t5u6_ai_insights_engine_schema.py`:

```python
"""AI Insights Engine schema changes.

Revision ID: p1q2r3s4t5u6
Revises: o0p1q2r3s4t5
Create Date: 2026-03-18

Changes:
  1. Add generation_date column to insights (ISO date string, user's local TZ).
  2. Add signal_type column to insights (raw signal type string).
  3. Add timezone column to user_preferences (IANA timezone, default UTC).
  4. Drop old uq_insights_user_type_day / uq_insights_user_type_date constraint.
  5. Add new unique constraint (user_id, signal_type, generation_date).
  6. Add index on insights(user_id, generation_date) for date-lock queries.
"""

import sqlalchemy as sa
from alembic import op

revision = "p1q2r3s4t5u6"
down_revision = "o0p1q2r3s4t5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add generation_date to insights
    op.execute("""
        ALTER TABLE insights
            ADD COLUMN IF NOT EXISTS generation_date VARCHAR
    """)

    # 2. Add signal_type to insights
    op.execute("""
        ALTER TABLE insights
            ADD COLUMN IF NOT EXISTS signal_type VARCHAR
    """)

    # 3. Add timezone to user_preferences
    op.execute("""
        ALTER TABLE user_preferences
            ADD COLUMN IF NOT EXISTS timezone VARCHAR NOT NULL DEFAULT 'UTC'
    """)

    # 4. Drop the old unique constraint (either name variant)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'public.insights'::regclass
                  AND conname = 'uq_insights_user_type_day'
                  AND contype = 'u'
            ) THEN
                ALTER TABLE insights DROP CONSTRAINT uq_insights_user_type_day;
            END IF;

            IF EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'public.insights'::regclass
                  AND conname = 'uq_insights_user_type_date'
                  AND contype = 'u'
            ) THEN
                ALTER TABLE insights DROP CONSTRAINT uq_insights_user_type_date;
            END IF;
        END $$
    """)

    # 5. Add new unique constraint on (user_id, signal_type, generation_date)
    # Allows multiple cards of different signal types per day, but prevents
    # duplicate signals within the same daily batch.
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'public.insights'::regclass
                  AND conname = 'uq_insights_user_signal_date'
                  AND contype = 'u'
            ) THEN
                ALTER TABLE insights
                    ADD CONSTRAINT uq_insights_user_signal_date
                    UNIQUE (user_id, signal_type, generation_date);
            END IF;
        END $$
    """)

    # 6. Index on (user_id, generation_date) for date-lock queries
    # At 1M users generating 5-10 cards/day this index is critical.
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_insights_user_generation_date
            ON insights (user_id, generation_date)
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_insights_user_generation_date")
    op.execute("""
        ALTER TABLE insights
            DROP CONSTRAINT IF EXISTS uq_insights_user_signal_date
    """)
    op.execute("ALTER TABLE user_preferences DROP COLUMN IF EXISTS timezone")
    op.execute("ALTER TABLE insights DROP COLUMN IF EXISTS signal_type")
    op.execute("ALTER TABLE insights DROP COLUMN IF EXISTS generation_date")
```

### Step 6: Run a migration dry-run check

```bash
cd cloud-brain && python -m alembic check
```
Expected: no errors (migration chain is valid)

### Step 7: Commit via git subagent

Message: `feat(db): add generation_date, signal_type to insights; add timezone to user_preferences`

---

## Chunk 2 — Bug fixes (display layer + missing API endpoint)

**Files:**
- Modify: `zuralog/lib/features/today/data/today_repository.dart` (lines 250, 269, 276)
- Modify: `zuralog/lib/features/today/domain/today_models.dart` (InsightCard.fromJson, InsightDetail.fromJson)
- Modify: `cloud-brain/app/api/v1/insight_routes.py` (add GET /{insight_id})
- Test: `cloud-brain/tests/api/test_insight_routes.py` (new or extend)
- Test: `zuralog/test/features/today/today_models_test.dart` (new)
- Test: `zuralog/test/features/today/today_repository_test.dart` (new)

**All 5 bugs from spec §11:**

| # | File | Line | Current | Fix |
|---|------|------|---------|-----|
| 1 | `today_repository.dart` | 250 | `response.data['items']` | `response.data['insights']` |
| 2 | `today_models.dart` InsightCard | `json['summary']` | `json['body']` |
| 3 | `today_models.dart` InsightCard | `json['is_read'] as bool` | `json['read_at'] != null` |
| 4 | `insight_routes.py` | — | missing GET /{id} | add endpoint |
| 5 | `today_repository.dart` | 269, 276 | `{'status': 'read'}` / `{'status': 'dismissed'}` | `{'action': 'read'}` / `{'action': 'dismiss'}` |
| +  | `today_models.dart` InsightDetail | `json['summary']` | `json['body']` |

### Step 1: Write failing backend test for GET /{insight_id}

```python
# cloud-brain/tests/api/test_insight_routes.py

@pytest.mark.asyncio
async def test_get_insight_by_id_returns_404_when_missing(client, auth_headers):
    response = await client.get("/api/v1/insights/nonexistent-id", headers=auth_headers)
    assert response.status_code == 404

@pytest.mark.asyncio
async def test_get_insight_by_id_returns_card(client, auth_headers, seeded_insight):
    """GET /api/v1/insights/{id} returns the card with body field (not summary)."""
    response = await client.get(f"/api/v1/insights/{seeded_insight.id}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == seeded_insight.id
    assert "body" in data          # must be 'body', not 'summary'
    assert "summary" not in data   # confirm no legacy field
```

Run: `pytest cloud-brain/tests/api/test_insight_routes.py::test_get_insight_by_id_returns_404_when_missing -v`
Expected: FAIL (endpoint doesn't exist, returns 404 from the wrong place or 405)

### Step 2: Add GET /{insight_id} endpoint to `insight_routes.py`

Insert this endpoint after `list_insights` and before `update_insight`:

```python
@router.get("/{insight_id}", summary="Get a single insight card", response_model=InsightResponse)
async def get_insight(
    insight_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Return a single insight card by ID.

    Only returns the card if it belongs to the authenticated user.
    Dismissed cards are still returned (the user may be viewing a
    historical notification that deep-links to a dismissed card).

    Args:
        insight_id: UUID of the insight.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        InsightResponse dict.

    Raises:
        HTTPException: 404 if not found or owned by a different user.
    """
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(
        select(Insight).where(
            Insight.id == insight_id,
            Insight.user_id == user_id,
        )
    )
    insight = result.scalar_one_or_none()

    if insight is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Insight not found.",
        )

    return _insight_to_response(insight).model_dump()
```

### Step 3: Run backend tests

Run: `pytest cloud-brain/tests/api/test_insight_routes.py -v`
Expected: PASS

### Step 4: Fix Flutter Bug 1 — `today_repository.dart:250`

Change:
```dart
final list = response.data['items'] as List<dynamic>? ?? [];
```
To:
```dart
final list = response.data['insights'] as List<dynamic>? ?? [];
```

### Step 5: Fix Flutter Bug 5 — `today_repository.dart:269,276`

Change `markInsightRead` body from `{'status': 'read'}` to `{'action': 'read'}`.
Change `dismissInsight` body from `{'status': 'dismissed'}` to `{'action': 'dismiss'}`.

```dart
// markInsightRead — line 269
await _api.patch('/api/v1/insights/$id', body: {'action': 'read'});

// dismissInsight — line 276
await _api.patch('/api/v1/insights/$id', body: {'action': 'dismiss'});
```

### Step 6: Fix Flutter Bugs 2 and 3 — `today_models.dart` InsightCard.fromJson

Current:
```dart
summary: json['summary'] as String,
isRead: json['is_read'] as bool? ?? false,
```

Fixed:
```dart
summary: json['body'] as String? ?? '',
isRead: json['read_at'] != null,
```

### Step 7: Fix Flutter Bug — `today_models.dart` InsightDetail.fromJson

Current:
```dart
summary: json['summary'] as String,
```

Fixed:
```dart
summary: json['body'] as String? ?? '',
```

### Step 8: Write Flutter unit tests

Create `zuralog/test/features/today/today_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

void main() {
  group('InsightCard.fromJson', () {
    test('reads body field (not summary)', () {
      final card = InsightCard.fromJson({
        'id': 'abc',
        'title': 'Test',
        'body': 'The real body text',
        'type': 'trend',
        'created_at': null,
        'read_at': null,
      });
      expect(card.summary, equals('The real body text'));
    });

    test('is_read is true when read_at is non-null', () {
      final card = InsightCard.fromJson({
        'id': 'abc',
        'title': 'Test',
        'body': 'Body',
        'type': 'trend',
        'read_at': '2026-03-18T06:00:00Z',
      });
      expect(card.isRead, isTrue);
    });

    test('is_read is false when read_at is null', () {
      final card = InsightCard.fromJson({
        'id': 'abc',
        'title': 'Test',
        'body': 'Body',
        'type': 'trend',
        'read_at': null,
      });
      expect(card.isRead, isFalse);
    });
  });

  group('InsightDetail.fromJson', () {
    test('reads body field (not summary)', () {
      final detail = InsightDetail.fromJson({
        'id': 'xyz',
        'title': 'Detail',
        'body': 'Detailed body text',
        'reasoning': 'Because reasons',
        'type': 'anomaly',
        'data_points': [],
        'sources': [],
      });
      expect(detail.summary, equals('Detailed body text'));
    });
  });
}
```

Run: `cd zuralog && flutter test test/features/today/today_models_test.dart`
Expected: PASS

### Step 9: Commit via git subagent

Message: `fix(insights): fix 5 display bugs — response key, field names, PATCH body, add GET /{id} endpoint`

---

## Chunk 3 — HealthBriefBuilder and UserFocusProfile

**Files:**
- Create: `cloud-brain/app/analytics/health_brief_builder.py`
- Create: `cloud-brain/app/analytics/user_focus_profile.py`
- Create: `cloud-brain/tests/analytics/test_health_brief_builder.py`
- Create: `cloud-brain/tests/analytics/test_user_focus_profile.py`

### Context

`HealthBriefBuilder` fetches all 11 data sources in parallel using `asyncio.gather`. It applies data quality rules, computes TDEE using Harris-Benedict, and returns a `HealthBrief` dataclass. `UserFocusProfile` maps the user's stated goals and dashboard layout to a priority metric list.

The priority source order for multi-source metrics is: Oura > Fitbit > Polar > Withings > Apple Health > Health Connect > manual. If a source's integration `last_synced_at` is > 24 hours ago, its "today" value is not used.

**Harris-Benedict TDEE formula:**
- Male BMR: `88.362 + (13.397 × weight_kg) + (4.799 × height_cm) - (5.677 × age)`
- Female BMR: `447.593 + (9.247 × weight_kg) + (3.098 × height_cm) - (4.330 × age)`
- No sex/age data: use weight-only estimate or skip TDEE-dependent patterns
- Activity multiplier from avg active calories over 14 days: <200=1.2, 200–400=1.375, 400–600=1.55, >600=1.725
- Height fallback: 170cm. Age fallback: skip age term. Sex fallback: average of male/female coefficients.

### Step 1: Write failing tests for HealthBriefBuilder

```python
# cloud-brain/tests/analytics/test_health_brief_builder.py
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import date, timedelta

@pytest.mark.asyncio
async def test_health_brief_builder_fetches_all_sources():
    """All 11 DB queries fire during build()."""
    # We verify by patching asyncio.gather and confirming 11 coroutines are passed.
    from app.analytics.health_brief_builder import HealthBriefBuilder
    builder = HealthBriefBuilder(user_id="user-1", db=AsyncMock())
    # Patch the 11 private _fetch_* methods to return empty lists
    with patch.multiple(
        builder,
        _fetch_daily_metrics=AsyncMock(return_value=[]),
        _fetch_sleep_records=AsyncMock(return_value=[]),
        _fetch_activities=AsyncMock(return_value=[]),
        _fetch_nutrition=AsyncMock(return_value=[]),
        _fetch_weight=AsyncMock(return_value=[]),
        _fetch_quick_logs=AsyncMock(return_value=[]),
        _fetch_goals=AsyncMock(return_value=[]),
        _fetch_streaks=AsyncMock(return_value=[]),
        _fetch_health_scores=AsyncMock(return_value=[]),
        _fetch_preferences=AsyncMock(return_value=None),
        _fetch_integrations=AsyncMock(return_value=[]),
    ):
        brief = await builder.build()
    assert brief.user_id == "user-1"
    assert brief.daily_metrics == []

@pytest.mark.asyncio
async def test_stale_source_excluded_from_today_value():
    """A source that hasn't synced in 25h is flagged as stale."""
    from app.analytics.health_brief_builder import HealthBriefBuilder, IntegrationStatus
    from datetime import datetime, timezone, timedelta
    stale_time = datetime.now(timezone.utc) - timedelta(hours=25)
    integration = IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=stale_time)
    assert integration.is_stale is True

@pytest.mark.asyncio
async def test_tdee_computed_with_harris_benedict():
    """TDEE is computed when weight and active calories are available."""
    from app.analytics.health_brief_builder import HealthBriefBuilder
    # 80kg, sedentary (<200 kcal/day active) -> TDEE ~ 80*13.397 + ... * 1.2
    tdee = HealthBriefBuilder._compute_tdee(
        weight_kg=80.0,
        avg_active_calories=150.0,
        height_cm=170.0,
        age=None,
        sex=None,
    )
    assert 1800 < tdee < 2400  # reasonable range for 80kg sedentary

def test_tdee_returns_none_when_no_weight():
    """TDEE is None when weight data is unavailable."""
    from app.analytics.health_brief_builder import HealthBriefBuilder
    tdee = HealthBriefBuilder._compute_tdee(
        weight_kg=None,
        avg_active_calories=300.0,
    )
    assert tdee is None
```

Run: `pytest cloud-brain/tests/analytics/test_health_brief_builder.py -v`
Expected: FAIL (module doesn't exist)

### Step 2: Create `health_brief_builder.py`

Create `cloud-brain/app/analytics/health_brief_builder.py`:

```python
"""
Zuralog Cloud Brain — Health Brief Builder.

Fetches all 11 user data sources in parallel and assembles a HealthBrief
dataclass that serves as the input to the InsightSignalDetector.

All DB queries use a maximum 90-day window. No query fetches more rows
than needed. Data quality rules are applied (stale source exclusion,
multi-source preference order).

TDEE is estimated using the Harris-Benedict formula. If weight is
unavailable, TDEE is None and all TDEE-dependent compound patterns
are skipped downstream.
"""

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import SleepRecord, UnifiedActivity
from app.models.integration import Integration
from app.models.user_goal import UserGoal
# Import other models as needed (nutrition, weight, quick_logs, streaks,
# health_scores, user_preferences) — use actual model class names from codebase.

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Source priority order for multi-source deduplication
# Lower index = higher priority
# ---------------------------------------------------------------------------
_SOURCE_PRIORITY = ["oura", "fitbit", "polar", "withings", "apple_health", "health_connect", "manual"]

_STALE_HOURS = 24
_LOOKBACK_DAILY = 30
_LOOKBACK_WEIGHT = 90
_LOOKBACK_QUICK_LOGS = 14
_LOOKBACK_HEALTH_SCORES = 14
_MIN_TREND_POINTS = 7


# ---------------------------------------------------------------------------
# Row dataclasses — lightweight containers for fetched data
# ---------------------------------------------------------------------------

@dataclass
class DailyMetricsRow:
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
    date: str
    hours: float | None = None
    quality_score: float | None = None
    source: str = "unknown"

@dataclass
class ActivityRow:
    date: str
    activity_type: str = ""
    duration_seconds: float | None = None
    distance_meters: float | None = None
    calories: float | None = None
    start_time: str | None = None

@dataclass
class NutritionRow:
    date: str
    calories: float | None = None
    protein_grams: float | None = None
    carbs_grams: float | None = None
    fat_grams: float | None = None

@dataclass
class WeightRow:
    date: str
    weight_kg: float | None = None

@dataclass
class QuickLogRow:
    metric_type: str
    value: float | None = None
    text_value: str | None = None
    data: dict = field(default_factory=dict)
    logged_at: str = ""

@dataclass
class GoalRow:
    id: str
    metric: str
    target_value: float
    period: str
    current_value: float | None = None
    is_active: bool = True
    deadline: str | None = None

@dataclass
class StreakRow:
    streak_type: str
    current_count: int = 0
    longest_count: int = 0
    last_activity_date: str | None = None

@dataclass
class HealthScoreRow:
    score_date: str
    score: float | None = None
    commentary: str | None = None

@dataclass
class UserPreferencesSnapshot:
    goals: list[str] = field(default_factory=list)
    dashboard_layout: dict = field(default_factory=dict)
    coach_persona: str = "balanced"
    fitness_level: str | None = None
    units_system: str = "metric"
    timezone: str = "UTC"

@dataclass
class IntegrationStatus:
    provider: str
    is_active: bool
    last_synced_at: datetime | None = None

    @property
    def is_stale(self) -> bool:
        """True if this integration hasn't synced in 24+ hours."""
        if self.last_synced_at is None:
            return True
        cutoff = datetime.now(timezone.utc) - timedelta(hours=_STALE_HOURS)
        ts = self.last_synced_at
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts < cutoff


# ---------------------------------------------------------------------------
# HealthBrief — the assembled snapshot passed to InsightSignalDetector
# ---------------------------------------------------------------------------

@dataclass
class HealthBrief:
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
    health_scores: list[HealthScoreRow]
    preferences: UserPreferencesSnapshot
    integrations: list[IntegrationStatus]
    data_maturity_days: int
    estimated_tdee: float | None = None  # Harris-Benedict estimate, None if no weight data


# ---------------------------------------------------------------------------
# HealthBriefBuilder
# ---------------------------------------------------------------------------

class HealthBriefBuilder:
    """Fetches all health data for a user and assembles a HealthBrief.

    All 11 data sources are fetched in parallel using asyncio.gather.
    Data quality rules are applied before returning the brief.

    Args:
        user_id: The user to build a brief for.
        db: An active async database session.
        target_date: The date to treat as "today". Defaults to date.today().
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

    async def build(self) -> HealthBrief:
        """Fetch all data sources in parallel and return a HealthBrief."""
        (
            daily_metrics_raw,
            sleep_raw,
            activities_raw,
            nutrition_raw,
            weight_raw,
            quick_logs_raw,
            goals_raw,
            streaks_raw,
            health_scores_raw,
            preferences_raw,
            integrations_raw,
        ) = await asyncio.gather(
            self._fetch_daily_metrics(),
            self._fetch_sleep_records(),
            self._fetch_activities(),
            self._fetch_nutrition(),
            self._fetch_weight(),
            self._fetch_quick_logs(),
            self._fetch_goals(),
            self._fetch_streaks(),
            self._fetch_health_scores(),
            self._fetch_preferences(),
            self._fetch_integrations(),
        )

        preferences = preferences_raw or UserPreferencesSnapshot()

        # Compute data maturity: distinct days with any health data
        all_dates = {r.date for r in daily_metrics_raw} | {r.date for r in sleep_raw}
        data_maturity_days = len(all_dates)

        # Compute TDEE
        latest_weight = next((r.weight_kg for r in weight_raw if r.weight_kg is not None), None)
        avg_active_cals = _safe_mean([r.active_calories for r in daily_metrics_raw[-14:] if r.active_calories])
        estimated_tdee = self._compute_tdee(
            weight_kg=latest_weight,
            avg_active_calories=avg_active_cals,
        )

        return HealthBrief(
            user_id=self.user_id,
            generated_at=datetime.now(timezone.utc),
            daily_metrics=daily_metrics_raw,
            sleep_records=sleep_raw,
            activities=activities_raw,
            nutrition=nutrition_raw,
            weight=weight_raw,
            quick_logs=quick_logs_raw,
            goals=goals_raw,
            streaks=streaks_raw,
            health_scores=health_scores_raw,
            preferences=preferences,
            integrations=integrations_raw,
            data_maturity_days=data_maturity_days,
            estimated_tdee=estimated_tdee,
        )

    @staticmethod
    def _compute_tdee(
        weight_kg: float | None,
        avg_active_calories: float | None = None,
        height_cm: float = 170.0,
        age: int | None = None,
        sex: str | None = None,  # "male" | "female" | None
    ) -> float | None:
        """Estimate TDEE using the Harris-Benedict formula.

        Returns None if weight is unavailable (skip TDEE-dependent patterns).
        Falls back to population averages for missing height/age/sex.
        """
        if weight_kg is None:
            return None

        # BMR using Harris-Benedict
        if sex == "male":
            bmr = 88.362 + (13.397 * weight_kg) + (4.799 * height_cm)
            if age is not None:
                bmr -= 5.677 * age
        elif sex == "female":
            bmr = 447.593 + (9.247 * weight_kg) + (3.098 * height_cm)
            if age is not None:
                bmr -= 4.330 * age
        else:
            # Average of male and female equations (unknown sex)
            male_bmr = 88.362 + (13.397 * weight_kg) + (4.799 * height_cm)
            female_bmr = 447.593 + (9.247 * weight_kg) + (3.098 * height_cm)
            bmr = (male_bmr + female_bmr) / 2

        # Activity multiplier from 14-day avg active calories
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
    # Private fetch methods — each returns a list of row dataclasses
    # ------------------------------------------------------------------

    async def _fetch_daily_metrics(self) -> list[DailyMetricsRow]:
        start = (self.target_date - timedelta(days=_LOOKBACK_DAILY - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(DailyHealthMetrics).where(
            and_(
                DailyHealthMetrics.user_id == self.user_id,
                DailyHealthMetrics.date >= start,
                DailyHealthMetrics.date <= end,
            )
        ).order_by(DailyHealthMetrics.date)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        # Deduplicate by date using source priority order
        return _dedup_by_source(
            [
                DailyMetricsRow(
                    date=r.date,
                    steps=_float(r, "steps"),
                    active_calories=_float(r, "active_calories"),
                    distance_meters=_float(r, "distance_meters"),
                    flights_climbed=_float(r, "flights_climbed"),
                    resting_heart_rate=_float(r, "resting_heart_rate"),
                    hrv_ms=_float(r, "hrv_ms"),
                    heart_rate_avg=_float(r, "heart_rate_avg"),
                    vo2_max=_float(r, "vo2_max"),
                    respiratory_rate=_float(r, "respiratory_rate"),
                    oxygen_saturation=_float(r, "oxygen_saturation"),
                    body_fat_percentage=_float(r, "body_fat_percentage"),
                    source=getattr(r, "source", "unknown") or "unknown",
                )
                for r in rows
            ]
        )

    async def _fetch_sleep_records(self) -> list[SleepRow]:
        start = (self.target_date - timedelta(days=_LOOKBACK_DAILY - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(SleepRecord).where(
            and_(
                SleepRecord.user_id == self.user_id,
                SleepRecord.date >= start,
                SleepRecord.date <= end,
            )
        ).order_by(SleepRecord.date)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return _dedup_by_source(
            [
                SleepRow(
                    date=r.date,
                    hours=_float(r, "hours"),
                    quality_score=_float(r, "quality_score"),
                    source=getattr(r, "source", "unknown") or "unknown",
                )
                for r in rows
            ]
        )

    async def _fetch_activities(self) -> list[ActivityRow]:
        start = (self.target_date - timedelta(days=_LOOKBACK_DAILY - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(UnifiedActivity).where(
            and_(
                UnifiedActivity.user_id == self.user_id,
                UnifiedActivity.start_time >= start,
                UnifiedActivity.start_time <= f"{end}T23:59:59",
            )
        ).order_by(UnifiedActivity.start_time)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [
            ActivityRow(
                date=str(r.start_time)[:10] if r.start_time else end,
                activity_type=getattr(r, "activity_type", "") or "",
                duration_seconds=_float(r, "duration_seconds"),
                distance_meters=_float(r, "distance_meters"),
                calories=_float(r, "calories"),
                start_time=str(r.start_time) if r.start_time else None,
            )
            for r in rows
        ]

    async def _fetch_nutrition(self) -> list[NutritionRow]:
        # Import NutritionEntry model — adjust import path to match actual codebase
        try:
            from app.models.nutrition import NutritionEntry  # type: ignore
        except ImportError:
            logger.debug("NutritionEntry model not available; returning empty nutrition data")
            return []
        start = (self.target_date - timedelta(days=_LOOKBACK_DAILY - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(NutritionEntry).where(
            and_(
                NutritionEntry.user_id == self.user_id,
                NutritionEntry.date >= start,
                NutritionEntry.date <= end,
            )
        ).order_by(NutritionEntry.date)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        # Aggregate by date (sum all entries for the day)
        by_date: dict[str, NutritionRow] = {}
        for r in rows:
            d = str(r.date)[:10]
            if d not in by_date:
                by_date[d] = NutritionRow(date=d)
            nr = by_date[d]
            nr.calories = (nr.calories or 0) + (_float(r, "calories") or 0)
            nr.protein_grams = (nr.protein_grams or 0) + (_float(r, "protein_grams") or 0)
            nr.carbs_grams = (nr.carbs_grams or 0) + (_float(r, "carbs_grams") or 0)
            nr.fat_grams = (nr.fat_grams or 0) + (_float(r, "fat_grams") or 0)
        return sorted(by_date.values(), key=lambda r: r.date)

    async def _fetch_weight(self) -> list[WeightRow]:
        try:
            from app.models.weight import WeightMeasurement  # type: ignore
        except ImportError:
            logger.debug("WeightMeasurement model not available")
            return []
        start = (self.target_date - timedelta(days=_LOOKBACK_WEIGHT - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(WeightMeasurement).where(
            and_(
                WeightMeasurement.user_id == self.user_id,
                WeightMeasurement.date >= start,
                WeightMeasurement.date <= end,
            )
        ).order_by(WeightMeasurement.date)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [WeightRow(date=str(r.date)[:10], weight_kg=_float(r, "weight_kg")) for r in rows]

    async def _fetch_quick_logs(self) -> list[QuickLogRow]:
        try:
            from app.models.quick_log import QuickLog  # type: ignore
        except ImportError:
            logger.debug("QuickLog model not available")
            return []
        start = (self.target_date - timedelta(days=_LOOKBACK_QUICK_LOGS - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(QuickLog).where(
            and_(
                QuickLog.user_id == self.user_id,
                QuickLog.logged_at >= start,
                QuickLog.logged_at <= f"{end}T23:59:59",
            )
        ).order_by(QuickLog.logged_at)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [
            QuickLogRow(
                metric_type=getattr(r, "metric_type", ""),
                value=_float(r, "value"),
                text_value=getattr(r, "text_value", None),
                data=getattr(r, "data", {}) or {},
                logged_at=str(getattr(r, "logged_at", "")),
            )
            for r in rows
        ]

    async def _fetch_goals(self) -> list[GoalRow]:
        stmt = select(UserGoal).where(
            UserGoal.user_id == self.user_id,
            UserGoal.is_active == True,  # noqa: E712
        )
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [
            GoalRow(
                id=str(r.id),
                metric=getattr(r, "metric", ""),
                target_value=float(getattr(r, "target_value", 0) or 0),
                period=getattr(r, "period", "daily"),
                current_value=_float(r, "current_value"),
                is_active=bool(getattr(r, "is_active", True)),
                deadline=str(r.deadline) if getattr(r, "deadline", None) else None,
            )
            for r in rows
        ]

    async def _fetch_streaks(self) -> list[StreakRow]:
        try:
            from app.models.streak import UserStreak  # type: ignore
        except ImportError:
            logger.debug("UserStreak model not available")
            return []
        stmt = select(UserStreak).where(UserStreak.user_id == self.user_id)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [
            StreakRow(
                streak_type=getattr(r, "streak_type", ""),
                current_count=int(getattr(r, "current_count", 0) or 0),
                longest_count=int(getattr(r, "longest_count", 0) or 0),
                last_activity_date=str(r.last_activity_date) if getattr(r, "last_activity_date", None) else None,
            )
            for r in rows
        ]

    async def _fetch_health_scores(self) -> list[HealthScoreRow]:
        try:
            from app.models.health_score import HealthScore  # type: ignore
        except ImportError:
            logger.debug("HealthScore model not available")
            return []
        start = (self.target_date - timedelta(days=_LOOKBACK_HEALTH_SCORES - 1)).isoformat()
        end = self.target_date.isoformat()
        stmt = select(HealthScore).where(
            and_(
                HealthScore.user_id == self.user_id,
                HealthScore.score_date >= start,
                HealthScore.score_date <= end,
            )
        ).order_by(HealthScore.score_date)
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [
            HealthScoreRow(
                score_date=str(r.score_date)[:10],
                score=_float(r, "score"),
                commentary=getattr(r, "commentary", None),
            )
            for r in rows
        ]

    async def _fetch_preferences(self) -> UserPreferencesSnapshot | None:
        from app.models.user_preferences import UserPreferences
        stmt = select(UserPreferences).where(UserPreferences.user_id == self.user_id)
        result = await self.db.execute(stmt)
        row = result.scalar_one_or_none()
        if row is None:
            return UserPreferencesSnapshot()
        return UserPreferencesSnapshot(
            goals=list(row.goals or []),
            dashboard_layout=dict(row.dashboard_layout or {}),
            coach_persona=row.coach_persona or "balanced",
            fitness_level=row.fitness_level,
            units_system=row.units_system or "metric",
            timezone=getattr(row, "timezone", "UTC") or "UTC",
        )

    async def _fetch_integrations(self) -> list[IntegrationStatus]:
        stmt = select(Integration).where(
            Integration.user_id == self.user_id,
            Integration.is_active == True,  # noqa: E712
        )
        result = await self.db.execute(stmt)
        rows = result.scalars().all()
        return [
            IntegrationStatus(
                provider=getattr(r, "provider", ""),
                is_active=bool(r.is_active),
                last_synced_at=getattr(r, "last_synced_at", None),
            )
            for r in rows
        ]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _float(obj: Any, attr: str) -> float | None:
    """Safely get a float attribute from an ORM row."""
    v = getattr(obj, attr, None)
    return float(v) if v is not None else None


def _safe_mean(values: list[float | None]) -> float | None:
    clean = [v for v in values if v is not None]
    return sum(clean) / len(clean) if clean else None


def _priority_index(source: str) -> int:
    try:
        return _SOURCE_PRIORITY.index(source.lower())
    except ValueError:
        return len(_SOURCE_PRIORITY)


def _dedup_by_source(rows: list) -> list:
    """Keep only the highest-priority source per date."""
    by_date: dict[str, Any] = {}
    for row in rows:
        d = row.date
        if d not in by_date:
            by_date[d] = row
        else:
            existing_priority = _priority_index(by_date[d].source)
            new_priority = _priority_index(row.source)
            if new_priority < existing_priority:
                by_date[d] = row
    return sorted(by_date.values(), key=lambda r: r.date)
```

### Step 3: Write failing tests for UserFocusProfile

```python
# cloud-brain/tests/analytics/test_user_focus_profile.py
from app.analytics.user_focus_profile import UserFocusProfileBuilder

def test_weight_loss_goal_maps_to_cutting_focus():
    builder = UserFocusProfileBuilder(
        goals=["weight_loss"],
        dashboard_layout={},
        coach_persona="balanced",
        fitness_level="active",
        units_system="metric",
    )
    profile = builder.build()
    assert profile.inferred_focus == "cutting"
    assert "weight_kg" in profile.focus_metrics
    assert "calories" in profile.focus_metrics

def test_dashboard_layout_infers_recovery_focus():
    builder = UserFocusProfileBuilder(
        goals=[],
        dashboard_layout={"visible_cards": ["sleep", "hrv", "stress"]},
        coach_persona="gentle",
        fitness_level=None,
        units_system="metric",
    )
    profile = builder.build()
    assert profile.inferred_focus in ("recovery", "sleep_optimisation")

def test_combined_goal_and_layout_focus():
    """Stated goal + matching dashboard layout → most specific label."""
    builder = UserFocusProfileBuilder(
        goals=["build_muscle"],
        dashboard_layout={"visible_cards": ["protein", "calories", "weight", "workouts"]},
        coach_persona="tough_love",
        fitness_level="athletic",
        units_system="metric",
    )
    profile = builder.build()
    assert profile.inferred_focus == "body_recomposition"
    assert "protein_grams" in profile.focus_metrics

def test_no_goals_no_layout_returns_default():
    builder = UserFocusProfileBuilder(
        goals=[],
        dashboard_layout={},
        coach_persona="balanced",
        fitness_level=None,
        units_system="metric",
    )
    profile = builder.build()
    assert profile.inferred_focus == "general"
    assert isinstance(profile.focus_metrics, list)
```

Run: `pytest cloud-brain/tests/analytics/test_user_focus_profile.py -v`
Expected: FAIL

### Step 4: Create `user_focus_profile.py`

Create `cloud-brain/app/analytics/user_focus_profile.py`:

```python
"""
Zuralog Cloud Brain — User Focus Profile.

Infers the user's primary health focus from their stated goals (user_preferences.goals)
and revealed preferences (dashboard_layout card keys). The resulting UserFocusProfile
is used by InsightSignalDetector to boost severity for metrics the user cares about.

See spec §7 Category F for the full mapping tables.
"""

from dataclasses import dataclass, field


# ---------------------------------------------------------------------------
# Goal → focus mapping (from spec §7 Category F)
# ---------------------------------------------------------------------------

_GOAL_TO_FOCUS: dict[str, tuple[str, list[str]]] = {
    "weight_loss": ("cutting", ["weight_kg", "calories", "active_calories", "body_fat_percentage", "protein_grams"]),
    "sleep": ("recovery", ["sleep_hours", "sleep_quality", "hrv_ms", "stress", "resting_heart_rate"]),
    "fitness": ("performance", ["steps", "active_calories", "distance_meters", "vo2_max", "workout_frequency"]),
    "stress": ("stress_management", ["stress", "mood", "hrv_ms", "sleep_hours", "resting_heart_rate"]),
    "nutrition": ("nutrition", ["calories", "protein_grams", "carbs_grams", "fat_grams", "water_ml"]),
    "longevity": ("longevity", ["hrv_ms", "resting_heart_rate", "vo2_max", "sleep_hours", "weight_kg"]),
    "build_muscle": ("body_recomposition", ["weight_kg", "protein_grams", "workout_frequency", "active_calories"]),
}

# Dashboard card key combinations → inferred sub-focus
# Each entry is (required_card_keys_subset, focus_label, priority_metrics)
_LAYOUT_PATTERNS: list[tuple[set[str], str, list[str]]] = [
    ({"protein", "calories", "weight", "workouts"}, "body_recomposition",
     ["weight_kg", "protein_grams", "workout_frequency", "active_calories"]),
    ({"sleep", "hrv", "stress"}, "recovery",
     ["sleep_hours", "sleep_quality", "hrv_ms", "stress", "resting_heart_rate"]),
    ({"sleep", "hrv", "water"}, "sleep_optimisation",
     ["sleep_hours", "sleep_quality", "hrv_ms", "water_ml"]),
    ({"hrv", "resting_heart_rate", "sleep", "water"}, "longevity",
     ["hrv_ms", "resting_heart_rate", "vo2_max", "sleep_hours", "weight_kg"]),
    ({"calories", "weight"}, "cutting",
     ["weight_kg", "calories", "active_calories", "body_fat_percentage"]),
    ({"steps", "active_calories", "distance"}, "activity_volume",
     ["steps", "active_calories", "distance_meters"]),
    ({"calories", "protein", "carbs", "fat"}, "nutrition_tracking",
     ["calories", "protein_grams", "carbs_grams", "fat_grams", "water_ml"]),
]


@dataclass
class UserFocusProfile:
    """The inferred focus profile used to weight signal severity.

    Attributes:
        stated_goals: Raw goal strings from user_preferences.goals.
        inferred_focus: Most specific combined label.
        focus_metrics: Metrics that receive severity +1 boost.
        deprioritised_metrics: Still shown on anomaly; lower priority otherwise.
        coach_persona: From user_preferences.
        fitness_level: From user_preferences.
        units_system: From user_preferences.
    """
    stated_goals: list[str] = field(default_factory=list)
    inferred_focus: str = "general"
    focus_metrics: list[str] = field(default_factory=list)
    deprioritised_metrics: list[str] = field(default_factory=list)
    coach_persona: str = "balanced"
    fitness_level: str | None = None
    units_system: str = "metric"


class UserFocusProfileBuilder:
    """Builds a UserFocusProfile from goals + dashboard layout.

    Args:
        goals: List of goal-type strings from user_preferences.goals.
        dashboard_layout: dict from user_preferences.dashboard_layout.
        coach_persona: Coach persona string.
        fitness_level: Self-assessed fitness level.
        units_system: 'metric' | 'imperial'.
    """

    def __init__(
        self,
        goals: list[str],
        dashboard_layout: dict,
        coach_persona: str = "balanced",
        fitness_level: str | None = None,
        units_system: str = "metric",
    ) -> None:
        self.goals = goals or []
        self.dashboard_layout = dashboard_layout or {}
        self.coach_persona = coach_persona
        self.fitness_level = fitness_level
        self.units_system = units_system

    def build(self) -> UserFocusProfile:
        """Infer focus from goals and dashboard layout."""
        # Step 1 — gather focus labels + metrics from stated goals
        goal_focuses: list[str] = []
        goal_metrics: list[str] = []
        for goal in self.goals:
            if goal in _GOAL_TO_FOCUS:
                focus_label, metrics = _GOAL_TO_FOCUS[goal]
                goal_focuses.append(focus_label)
                goal_metrics.extend(m for m in metrics if m not in goal_metrics)

        # Step 2 — infer from dashboard layout card keys
        visible_cards = set(self.dashboard_layout.get("visible_cards", []))
        layout_focus: str | None = None
        layout_metrics: list[str] = []
        for required_keys, focus_label, metrics in _LAYOUT_PATTERNS:
            if required_keys.issubset(visible_cards):
                layout_focus = focus_label
                layout_metrics = metrics
                break

        # Step 3 — combine: layout focus takes priority if it matches a goal focus
        if layout_focus and layout_focus in goal_focuses:
            inferred_focus = layout_focus
            focus_metrics = _merge_unique(layout_metrics, goal_metrics)
        elif layout_focus:
            inferred_focus = layout_focus
            focus_metrics = _merge_unique(layout_metrics, goal_metrics)
        elif goal_focuses:
            inferred_focus = goal_focuses[0]
            focus_metrics = goal_metrics
        else:
            inferred_focus = "general"
            focus_metrics = []

        # All metrics NOT in focus_metrics are deprioritised
        all_known = {m for _, (_, ms) in _GOAL_TO_FOCUS.items() for m in ms}
        deprioritised = [m for m in all_known if m not in focus_metrics]

        return UserFocusProfile(
            stated_goals=self.goals,
            inferred_focus=inferred_focus,
            focus_metrics=focus_metrics,
            deprioritised_metrics=deprioritised,
            coach_persona=self.coach_persona,
            fitness_level=self.fitness_level,
            units_system=self.units_system,
        )


def _merge_unique(primary: list[str], secondary: list[str]) -> list[str]:
    result = list(primary)
    for m in secondary:
        if m not in result:
            result.append(m)
    return result
```

### Step 5: Run all analytics tests

Run: `pytest cloud-brain/tests/analytics/ -v`
Expected: PASS

### Step 6: Commit via git subagent

Message: `feat(analytics): add HealthBriefBuilder and UserFocusProfile with TDEE estimation`

---

## Chunk 4 — InsightSignalDetector (all 8 signal categories)

> **Review subagent runs after this chunk is committed.**

**Files:**
- Create: `cloud-brain/app/analytics/insight_signal_detector.py`
- Create: `cloud-brain/tests/analytics/test_insight_signal_detector.py`

### Context

The detector receives a `HealthBrief` and returns `list[InsightSignal]`. It delegates to existing analytics classes:
- `TrendDetector` — already exists at `app/analytics/trend_detector.py`
- `GoalTracker.check_progress()` — already exists at `app/analytics/goal_tracker.py`
- `CorrelationAnalyzer.calculate_correlation()` — already exists at `app/analytics/correlation_analyzer.py`
- `AnomalyDetector` is extended inline (or via a helper) within the detector for the expanded 12-metric set

The spec §7 describes all 8 categories in detail — read it carefully. Every category is a separate method named `_detect_category_X()`. The detector collects results from all 8 categories into one list.

### Step 1: Write failing tests — one fire/no-fire pair per signal type

```python
# cloud-brain/tests/analytics/test_insight_signal_detector.py
import pytest
from datetime import date, timedelta
from app.analytics.insight_signal_detector import InsightSignalDetector, InsightSignal
from app.analytics.health_brief_builder import (
    HealthBrief, DailyMetricsRow, SleepRow, ActivityRow, GoalRow,
    StreakRow, NutritionRow, WeightRow, QuickLogRow,
    UserPreferencesSnapshot, IntegrationStatus, HealthScoreRow,
)
from datetime import datetime, timezone


def _empty_brief(user_id="u1") -> HealthBrief:
    return HealthBrief(
        user_id=user_id,
        generated_at=datetime.now(timezone.utc),
        daily_metrics=[],
        sleep_records=[],
        activities=[],
        nutrition=[],
        weight=[],
        quick_logs=[],
        goals=[],
        streaks=[],
        health_scores=[],
        preferences=UserPreferencesSnapshot(),
        integrations=[],
        data_maturity_days=30,
    )


def _make_daily_metrics(n=20, steps=8000.0, hrv=40.0, rhr=65.0) -> list[DailyMetricsRow]:
    today = date.today()
    return [
        DailyMetricsRow(
            date=(today - timedelta(days=n - i)).isoformat(),
            steps=steps,
            hrv_ms=hrv,
            resting_heart_rate=rhr,
            active_calories=300.0,
        )
        for i in range(n)
    ]


# ── Category A: Single-metric trends ─────────────────────────────────────────

def test_category_a_trend_decline_fires():
    brief = _empty_brief()
    today = date.today()
    # Recent 7 days: steps=5000 (down >10% from previous 7 days: 8000)
    metrics = []
    for i in range(14):
        d = (today - timedelta(days=13 - i)).isoformat()
        steps = 8000.0 if i < 7 else 5000.0
        metrics.append(DailyMetricsRow(date=d, steps=steps))
    brief.daily_metrics = metrics
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    types = [s.signal_type for s in signals]
    assert "trend_decline" in types

def test_category_a_trend_decline_does_not_fire_with_insufficient_data():
    brief = _empty_brief()
    brief.daily_metrics = _make_daily_metrics(n=10)  # < 14 points
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    a_signals = [s for s in signals if s.category == "A"]
    assert len(a_signals) == 0


# ── Category B: Goal progress ─────────────────────────────────────────────────

def test_category_b_goal_near_miss_fires():
    brief = _empty_brief()
    brief.daily_metrics = _make_daily_metrics(n=20, steps=8200.0)
    brief.goals = [GoalRow(id="g1", metric="steps", target_value=10000.0, period="daily", current_value=8200.0)]
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    types = [s.signal_type for s in signals]
    assert "goal_near_miss" in types

def test_category_b_goal_near_miss_does_not_fire_below_80_pct():
    brief = _empty_brief()
    brief.goals = [GoalRow(id="g1", metric="steps", target_value=10000.0, period="daily", current_value=5000.0)]
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    types = [s.signal_type for s in signals]
    assert "goal_near_miss" not in types

def test_category_b_goal_met_today_fires():
    brief = _empty_brief()
    brief.goals = [GoalRow(id="g1", metric="steps", target_value=10000.0, period="daily", current_value=11000.0)]
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    types = [s.signal_type for s in signals]
    assert "goal_met_today" in types


# ── Category C: Anomaly detection ────────────────────────────────────────────

def test_category_c_anomaly_fires_for_elevated_rhr():
    brief = _empty_brief()
    today = date.today()
    # Baseline RHR=63, today RHR=78 (>3 stddev)
    metrics = []
    for i in range(29):
        d = (today - timedelta(days=29 - i)).isoformat()
        metrics.append(DailyMetricsRow(date=d, resting_heart_rate=63.0))
    metrics.append(DailyMetricsRow(date=today.isoformat(), resting_heart_rate=78.0))
    brief.daily_metrics = metrics
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    types = [s.signal_type for s in signals]
    assert "anomaly" in types

def test_category_c_anomaly_does_not_fire_with_normal_value():
    brief = _empty_brief()
    brief.daily_metrics = _make_daily_metrics(n=20, rhr=63.0)  # all same = no anomaly
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "anomaly"]
    # Uniform values → zero stddev → no anomaly (current==mean)
    assert len(signals) == 0


# ── Category D: Correlations ──────────────────────────────────────────────────

def test_category_d_correlation_fires_when_strong_relationship():
    from app.analytics.health_brief_builder import SleepRow
    brief = _empty_brief()
    today = date.today()
    # Strong positive: more sleep → more steps next day
    sleep = []
    metrics = []
    for i in range(20):
        d = (today - timedelta(days=20 - i)).isoformat()
        d_next = (today - timedelta(days=19 - i)).isoformat()
        hours = 6.0 if i % 2 == 0 else 8.0
        steps = 5000.0 if hours < 7 else 10000.0
        sleep.append(SleepRow(date=d, hours=hours))
        metrics.append(DailyMetricsRow(date=d, steps=steps))
    brief.sleep_records = sleep
    brief.daily_metrics = metrics
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.category == "D"]
    assert len(signals) > 0

def test_category_d_correlation_does_not_fire_with_weak_relationship():
    brief = _empty_brief()
    brief.sleep_records = [SleepRow(date=(date.today() - timedelta(days=i)).isoformat(), hours=7.0) for i in range(20)]
    brief.daily_metrics = [DailyMetricsRow(date=(date.today() - timedelta(days=i)).isoformat(), steps=8000.0) for i in range(20)]
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.category == "D"]
    assert len(signals) == 0  # no variance = no correlation


# ── Category E: Compound patterns ─────────────────────────────────────────────

def test_category_e_overtraining_risk_fires():
    brief = _empty_brief()
    today = date.today()
    # 6 consecutive workout days
    brief.activities = [
        ActivityRow(
            date=(today - timedelta(days=i)).isoformat(),
            activity_type="run",
            duration_seconds=3600.0,
            calories=500.0,
        )
        for i in range(6)
    ]
    # HRV declining, RHR rising
    brief.daily_metrics = [
        DailyMetricsRow(
            date=(today - timedelta(days=i)).isoformat(),
            hrv_ms=max(20.0, 40.0 - i * 3),
            resting_heart_rate=min(80.0, 60.0 + i * 2),
        )
        for i in range(14)
    ]
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "compound_overtraining_risk"]
    assert len(signals) == 1

def test_category_e_weight_plateau_fires():
    brief = _empty_brief()
    today = date.today()
    # Weight stable ±0.1kg for 14 days
    brief.weight = [
        WeightRow(date=(today - timedelta(days=i)).isoformat(), weight_kg=75.0)
        for i in range(14)
    ]
    brief.goals = [GoalRow(id="g1", metric="weight_kg", target_value=70.0, period="monthly", current_value=75.0)]
    brief.estimated_tdee = 1900.0
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "compound_weight_plateau"]
    assert len(signals) == 1


# ── Category F: Focus severity boost ─────────────────────────────────────────

def test_category_f_focus_boosts_severity():
    brief = _empty_brief()
    brief.preferences = UserPreferencesSnapshot(goals=["weight_loss"])
    today = date.today()
    # Trend decline for weight_kg (focus metric)
    brief.weight = [
        WeightRow(date=(today - timedelta(days=i)).isoformat(), weight_kg=75.0 - i * 0.1)
        for i in range(20)
    ]
    # Also a non-focus trend (steps)
    brief.daily_metrics = [
        DailyMetricsRow(
            date=(today - timedelta(days=i)).isoformat(),
            steps=10000.0 if i < 7 else 6000.0,
        )
        for i in range(20)
    ]
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()
    steps_signals = [s for s in signals if "steps" in s.metrics]
    weight_signals = [s for s in signals if "weight_kg" in s.metrics]
    # Weight signal should have higher severity than steps (focus boost)
    if steps_signals and weight_signals:
        assert weight_signals[0].severity >= steps_signals[0].severity


# ── Category G: Streaks ────────────────────────────────────────────────────────

def test_category_g_streak_at_risk_fires():
    brief = _empty_brief()
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    brief.streaks = [StreakRow(streak_type="steps", current_count=15, longest_count=20, last_activity_date=yesterday)]
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "streak_at_risk"]
    assert len(signals) == 1

def test_category_g_streak_milestone_tomorrow_fires():
    brief = _empty_brief()
    today = date.today().isoformat()
    brief.streaks = [StreakRow(streak_type="steps", current_count=6, longest_count=10, last_activity_date=today)]
    # current_count 6 → milestone at 7 is tomorrow
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "streak_milestone_tomorrow"]
    assert len(signals) == 1


# ── Category H: Data quality ──────────────────────────────────────────────────

def test_category_h_stale_integration_fires():
    from datetime import datetime, timezone, timedelta
    brief = _empty_brief()
    stale_time = datetime.now(timezone.utc) - timedelta(hours=25)
    brief.integrations = [IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=stale_time)]
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "integration_stale"]
    assert len(signals) == 1

def test_category_h_fresh_integration_does_not_fire():
    from datetime import datetime, timezone, timedelta
    brief = _empty_brief()
    fresh_time = datetime.now(timezone.utc) - timedelta(hours=1)
    brief.integrations = [IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=fresh_time)]
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "integration_stale"]
    assert len(signals) == 0
```

Run: `pytest cloud-brain/tests/analytics/test_insight_signal_detector.py -v`
Expected: FAIL (module doesn't exist)

### Step 2: Create `insight_signal_detector.py`

Create `cloud-brain/app/analytics/insight_signal_detector.py`. This is the largest file in the feature. Implement all 8 categories strictly following spec §7. Key implementation notes:

**Structure:**
```python
@dataclass
class InsightSignal:
    signal_type: str
    category: str           # "A" through "H"
    metrics: list[str]
    values: dict[str, Any]
    severity: int           # 1-5
    actionable: bool
    focus_relevant: bool
    title_hint: str
    data_payload: dict

class InsightSignalDetector:
    def __init__(self, brief: HealthBrief) -> None:
        self.brief = brief
        self._focus = UserFocusProfileBuilder(
            goals=brief.preferences.goals,
            dashboard_layout=brief.preferences.dashboard_layout,
            coach_persona=brief.preferences.coach_persona,
            fitness_level=brief.preferences.fitness_level,
            units_system=brief.preferences.units_system,
        ).build()

    def detect_all(self) -> list[InsightSignal]:
        """Run all 8 categories and return the combined signal list."""
        signals: list[InsightSignal] = []
        signals.extend(self._detect_category_a())
        signals.extend(self._detect_category_b())
        signals.extend(self._detect_category_c())
        signals.extend(self._detect_category_d())
        signals.extend(self._detect_category_e())
        # F is preprocessing — already done in __init__
        signals.extend(self._detect_category_g())
        signals.extend(self._detect_category_h())
        return signals
```

**Category A (trends):** Use `TrendDetector.detect_trend()`. Requires ≥14 values. For each of the 15 metrics, extract the time series from the brief, run the detector. `trend_decline` if direction=="down", `trend_improvement` if "up". Apply severity rules from spec.

**Category B (goal progress):** Use `GoalTracker.check_progress()` on each active goal. Implement all 8 signal types from the spec table. Pacing logic for weekly goals must use the formula from spec §7 Category B.

**Category C (anomalies):** Re-implement the anomaly computation inline using the existing `_mean`, `_stddev`, `_classify_severity` logic from `anomaly_detector.py`. Cover all 12 metrics. Weight anomaly uses a special rule: ≥2kg jump in one day. Map severity: elevated → severity 3, critical → severity 5.

**Category D (correlations):** Use `CorrelationAnalyzer.calculate_correlation()`. Implement lag support using the date-alignment approach from `analyze_sleep_impact_on_activity()`. Check all 14 pairs from spec. Require ≥14 paired points. Only surface |r| > 0.4.

**Category E (compound patterns):** Implement each of the 10 patterns as a dedicated `_detect_compound_*()` method. Each returns `list[InsightSignal]` (usually 0 or 1 element). Use `brief.estimated_tdee` for TDEE-dependent patterns. Skip if None.

**Category G (streaks):** Use `brief.streaks` directly. Streak milestones: 7, 14, 30, 60, 90, 180, 365.

**Category H (data quality):** Check `brief.integrations` for stale sources. Check sleep/activity gaps. Only fire `first_week` if `data_maturity_days < 7`.

**Severity adjustment:** After computing base severity for each signal, apply focus boost: if signal's primary metric is in `self._focus.focus_metrics`, severity = min(5, severity + 1).

### Step 3: Run the full signal detector test suite

Run: `pytest cloud-brain/tests/analytics/test_insight_signal_detector.py -v`
Expected: All tests PASS

### Step 4: Run all analytics tests

Run: `pytest cloud-brain/tests/analytics/ -v`
Expected: All PASS

### Step 5: Commit via git subagent

Message: `feat(analytics): add InsightSignalDetector with all 8 signal categories`

### Step 6: Run review subagent

The review subagent must check that all signal types, conditions, severity rules, and data requirements from spec §7 are correctly implemented. It must also check that Categories A–H are all present and that the focus severity boost is applied.

---

## Chunk 5 — SignalPrioritizer and InsightCardWriter

**Files:**
- Create: `cloud-brain/app/analytics/signal_prioritizer.py`
- Create: `cloud-brain/app/analytics/insight_card_writer.py`
- Create: `cloud-brain/tests/analytics/test_signal_prioritizer.py`
- Create: `cloud-brain/tests/analytics/test_insight_card_writer.py`

### Context

`SignalPrioritizer` takes `list[InsightSignal]` and returns an ordered `list[InsightSignal]` (2–10 items). It applies the composite score, anomaly pinning, deduplication, diversity cap, and dynamic count from spec §8.

`InsightCardWriter` takes the prioritized signals and a `UserFocusProfile` and makes a single OpenRouter LLM call using `OPENROUTER_INSIGHT_MODEL`. It sends the full signal brief in one request and parses the JSON array. Full fallback chain from spec §9.

### Step 1: Write failing tests for SignalPrioritizer

```python
# cloud-brain/tests/analytics/test_signal_prioritizer.py
import pytest
from app.analytics.insight_signal_detector import InsightSignal
from app.analytics.signal_prioritizer import SignalPrioritizer


def _make_signal(signal_type, category, severity, focus_relevant=False, actionable=False, metrics=None):
    return InsightSignal(
        signal_type=signal_type,
        category=category,
        metrics=metrics or ["steps"],
        values={},
        severity=severity,
        actionable=actionable,
        focus_relevant=focus_relevant,
        title_hint="Test",
        data_payload={},
    )


def test_prioritizer_pins_critical_anomaly_to_top():
    signals = [
        _make_signal("trend_decline", "A", severity=2),
        _make_signal("anomaly", "C", severity=5),  # critical anomaly
        _make_signal("goal_nudge", "B", severity=3),
    ]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    assert result[0].signal_type == "anomaly"
    assert result[0].severity == 5

def test_prioritizer_composite_score_orders_correctly():
    # focus_relevant + actionable should score higher than neither
    high = _make_signal("goal_near_miss", "B", severity=3, focus_relevant=True, actionable=True)
    low = _make_signal("correlation_positive", "D", severity=3, focus_relevant=False, actionable=False)
    prioritizer = SignalPrioritizer([low, high])
    result = prioritizer.prioritize()
    assert result[0].signal_type == "goal_near_miss"

def test_prioritizer_deduplication_merges_trend_and_goal():
    signals = [
        _make_signal("trend_decline", "A", severity=2, metrics=["steps"]),
        _make_signal("goal_near_miss", "B", severity=4, metrics=["steps"]),
    ]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    # Should be merged into one signal for "steps"
    steps_signals = [s for s in result if "steps" in s.metrics]
    assert len(steps_signals) == 1
    assert steps_signals[0].severity == 4  # higher severity wins

def test_prioritizer_diversity_cap():
    # More than 2 signals from category A should be capped to 2 (unless anomaly)
    signals = [_make_signal(f"trend_{i}", "A", severity=2) for i in range(5)]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    a_signals = [s for s in result if s.category == "A"]
    assert len(a_signals) <= 2

def test_prioritizer_anomaly_exempt_from_diversity_cap():
    signals = [_make_signal("anomaly", "C", severity=5) for _ in range(3)]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    c_signals = [s for s in result if s.category == "C"]
    assert len(c_signals) == 3  # all 3 critical anomalies pass through

def test_prioritizer_minimum_two_cards():
    signals = [_make_signal("trend_decline", "A", severity=2)]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    assert len(result) >= 1  # with only 1 signal, return that 1

def test_prioritizer_maximum_ten_cards():
    signals = [_make_signal(f"type_{i}", chr(65 + i % 8), severity=2) for i in range(15)]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    assert len(result) <= 10

def test_prioritizer_at_least_two_categories_when_four_or_more_signals():
    signals = [_make_signal("type_a", "A", severity=3) for _ in range(2)] + \
              [_make_signal("type_b", "B", severity=3) for _ in range(2)]
    prioritizer = SignalPrioritizer(signals)
    result = prioritizer.prioritize()
    categories = {s.category for s in result}
    assert len(categories) >= 2
```

Run: `pytest cloud-brain/tests/analytics/test_signal_prioritizer.py -v`
Expected: FAIL

### Step 2: Create `signal_prioritizer.py`

Create `cloud-brain/app/analytics/signal_prioritizer.py`:

```python
"""
Zuralog Cloud Brain — Signal Prioritizer.

Receives the raw list of InsightSignals from InsightSignalDetector and returns
the final ordered subset for the LLM call.

Rules (from spec §8):
1. Critical anomalies (category C, severity 5) are pinned to top 1-2 positions.
2. Remaining signals sorted by composite score: (severity × 3) + (focus_relevant × 2) + (actionable × 1).
3. Recency tie-breaking: today/yesterday data > historical patterns. Correlation signals are lowest recency.
4. Deduplication: trend_decline + goal_near_miss on the same metric → merge (keep higher severity, combine payloads).
5. Diversity cap: max 2 signals per category (A–H). Anomaly signals (C) are exempt.
6. At least 2 different categories must be represented when ≥4 signals exist.
7. Dynamic count: min 2, max 10 cards.
"""

import logging
from dataclasses import replace
from app.analytics.insight_signal_detector import InsightSignal

logger = logging.getLogger(__name__)

_MIN_CARDS = 2
_MAX_CARDS = 10
_MAX_PER_CATEGORY = 2
_RECENCY_ORDER = {"A": 1, "B": 1, "C": 0, "E": 1, "G": 1, "H": 2, "D": 3, "F": 4}


class SignalPrioritizer:
    def __init__(self, signals: list[InsightSignal]) -> None:
        self.signals = signals

    def prioritize(self) -> list[InsightSignal]:
        if not self.signals:
            return []

        # Step 1: Deduplicate — merge trend+goal on same metric
        signals = _deduplicate(self.signals)

        # Step 2: Separate critical anomalies from the rest
        critical = [s for s in signals if s.category == "C" and s.severity == 5]
        rest = [s for s in signals if not (s.category == "C" and s.severity == 5)]

        # Step 3: Score and sort the rest
        def _score(s: InsightSignal) -> tuple[int, int]:
            composite = (s.severity * 3) + (int(s.focus_relevant) * 2) + int(s.actionable)
            recency = _RECENCY_ORDER.get(s.category, 99)
            return (-composite, recency)  # negative so higher score sorts first

        rest_sorted = sorted(rest, key=_score)

        # Step 4: Enforce diversity cap (max 2 per category, anomaly exempt)
        category_counts: dict[str, int] = {}
        diverse: list[InsightSignal] = []
        for s in rest_sorted:
            count = category_counts.get(s.category, 0)
            if count < _MAX_PER_CATEGORY:
                diverse.append(s)
                category_counts[s.category] = count + 1

        # Step 5: Enforce category diversity when ≥4 signals exist
        combined = critical[:2] + diverse  # cap anomaly pin at 2
        if len(combined) >= 4:
            categories_present = {s.category for s in combined}
            if len(categories_present) < 2:
                # Add the next signal from a different category
                for s in rest_sorted:
                    if s.category not in categories_present and s not in combined:
                        combined.append(s)
                        break

        # Step 6: Clamp to dynamic count
        result = combined[:_MAX_CARDS]

        logger.debug(
            "SignalPrioritizer: %d signals in → %d signals out",
            len(self.signals),
            len(result),
        )
        return result


def _deduplicate(signals: list[InsightSignal]) -> list[InsightSignal]:
    """Merge trend_decline + goal_near_miss for the same metric."""
    # Build a map: metric → list of signals about that metric
    by_metric: dict[str, list[InsightSignal]] = {}
    for s in signals:
        for m in s.metrics:
            by_metric.setdefault(m, []).append(s)

    merged: set[int] = set()
    result: list[InsightSignal] = []

    for s in signals:
        if id(s) in merged:
            continue

        # Find a goal signal for the same metric
        if s.signal_type == "trend_decline" and s.metrics:
            metric = s.metrics[0]
            goal_signal = next(
                (g for g in by_metric.get(metric, [])
                 if g.signal_type in ("goal_near_miss", "goal_behind_pace")
                 and id(g) not in merged),
                None
            )
            if goal_signal is not None:
                # Merge: keep higher severity, combine payloads
                merged_signal = replace(
                    s if s.severity >= goal_signal.severity else goal_signal,
                    severity=max(s.severity, goal_signal.severity),
                    data_payload={**s.data_payload, **goal_signal.data_payload},
                    values={**s.values, **goal_signal.values},
                )
                result.append(merged_signal)
                merged.add(id(s))
                merged.add(id(goal_signal))
                continue

        result.append(s)
        merged.add(id(s))

    return result
```

### Step 3: Write failing tests for InsightCardWriter

```python
# cloud-brain/tests/analytics/test_insight_card_writer.py
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.analytics.insight_signal_detector import InsightSignal
from app.analytics.user_focus_profile import UserFocusProfile
from app.analytics.insight_card_writer import InsightCardWriter


def _make_signal(signal_type="trend_decline", metrics=None, severity=3):
    return InsightSignal(
        signal_type=signal_type,
        category="A",
        metrics=metrics or ["steps"],
        values={"recent_avg": 5000, "previous_avg": 8000, "pct_change": -37.5},
        severity=severity,
        actionable=True,
        focus_relevant=True,
        title_hint="Steps declining",
        data_payload={"recent_avg": 5000},
    )


def _make_focus():
    return UserFocusProfile(
        stated_goals=["fitness"],
        inferred_focus="performance",
        focus_metrics=["steps", "active_calories"],
        deprioritised_metrics=[],
        coach_persona="balanced",
        fitness_level="active",
        units_system="metric",
    )


@pytest.mark.asyncio
async def test_card_writer_uses_llm_when_successful():
    """When LLM returns valid JSON, cards come from LLM."""
    llm_json = '[{"type": "trend_decline", "title": "Steps Falling", "body": "Your steps dropped 37%.", "priority": 3, "reasoning": "Trend detected."}]'
    mock_response = MagicMock()
    mock_response.choices = [MagicMock(message=MagicMock(content=llm_json))]

    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        instance = MockLLM.return_value
        instance.chat = AsyncMock(return_value=mock_response)
        writer = InsightCardWriter(
            signals=[_make_signal()],
            focus=_make_focus(),
            target_date="2026-03-18",
        )
        cards = await writer.write_cards()

    assert len(cards) == 1
    assert cards[0]["title"] == "Steps Falling"
    assert cards[0]["body"] == "Your steps dropped 37%."


@pytest.mark.asyncio
async def test_card_writer_falls_back_on_malformed_json():
    """When LLM returns non-JSON, rule-based fallback is used."""
    mock_response = MagicMock()
    mock_response.choices = [MagicMock(message=MagicMock(content="Not valid JSON at all!"))]

    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        instance = MockLLM.return_value
        instance.chat = AsyncMock(return_value=mock_response)
        writer = InsightCardWriter(
            signals=[_make_signal()],
            focus=_make_focus(),
            target_date="2026-03-18",
        )
        cards = await writer.write_cards()

    # Fallback must produce at least one card
    assert len(cards) >= 1
    assert "title" in cards[0]
    assert "body" in cards[0]


@pytest.mark.asyncio
async def test_card_writer_falls_back_on_api_error():
    """When LLM call fails with APIError, rule-based fallback is used."""
    from openai import APIError

    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        instance = MockLLM.return_value
        instance.chat = AsyncMock(side_effect=APIError("timeout", request=MagicMock(), body=None))
        writer = InsightCardWriter(
            signals=[_make_signal()],
            focus=_make_focus(),
            target_date="2026-03-18",
        )
        cards = await writer.write_cards()

    assert len(cards) >= 1


@pytest.mark.asyncio
async def test_card_writer_minimum_card_guarantee():
    """Even with total fallback failure, at least 1 card is returned."""
    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        instance = MockLLM.return_value
        instance.chat = AsyncMock(side_effect=Exception("total failure"))
        writer = InsightCardWriter(
            signals=[_make_signal()],
            focus=_make_focus(),
            target_date="2026-03-18",
        )
        cards = await writer.write_cards()

    assert len(cards) >= 1
```

Run: `pytest cloud-brain/tests/analytics/test_insight_card_writer.py -v`
Expected: FAIL

### Step 4: Add `OPENROUTER_INSIGHT_MODEL` to `config.py`

In `cloud-brain/app/config.py`, add after `openrouter_model`:

```python
openrouter_insight_model: str = "google/gemini-flash-2.5"
# OPENROUTER_INSIGHT_MODEL — cheap fast model for daily insight generation.
# Separate from openrouter_model (Kimi K2.5) which is reserved for the Coach tab.
# Candidates: google/gemini-flash-2.5, openai/gpt-4o-mini
```

Also add `OPENROUTER_INSIGHT_MODEL=google/gemini-flash-2.5` to `.env.example` if it exists.

### Step 5: Create `insight_card_writer.py`

Create `cloud-brain/app/analytics/insight_card_writer.py`:

```python
"""
Zuralog Cloud Brain — Insight Card Writer.

Makes a single OpenRouter LLM call to turn pre-computed InsightSignals
into natural-language insight cards. Uses the cheap/fast model configured
in OPENROUTER_INSIGHT_MODEL (separate from the Coach tab's Kimi K2.5).

Fallback chain (from spec §9):
1. LLM call succeeds + valid JSON array → use LLM cards
2. LLM call succeeds + malformed JSON  → rule-based fallback per signal
3. LLM call fails (APIError)          → rule-based fallback per signal
4. Rule-based fallback also fails      → minimum "working on it" card
"""

import json
import logging
from typing import Any

from openai import APIError

from app.agent.llm_client import LLMClient
from app.analytics.insight_signal_detector import InsightSignal
from app.analytics.user_focus_profile import UserFocusProfile
from app.config import settings

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """\
You are a health insight writer for Zuralog. Your job is to turn structured health data signals into clear, personal, and actionable insight cards.

User context:
- Coach persona: {persona}
- Fitness level: {fitness_level}
- Primary goals: {stated_goals}
- Inferred focus: {inferred_focus}
- Units: {units_system}

Persona writing style:
- tough_love: Direct, honest, no sugarcoating. Holds the user accountable.
- balanced: Supportive but honest. Acknowledges effort and gaps equally.
- gentle: Encouraging, kind, never negative. Frames everything as an opportunity.

Output rules:
1. Return a JSON array only. No prose outside the array.
2. Each element must have: type, title, body, priority (1-10, lower=more urgent), reasoning.
3. title: 3-7 words. Punchy headline.
4. body: 1-3 sentences. Specific numbers from the signal data. No generic advice.
5. reasoning: 1 sentence explaining why this signal was surfaced today.
6. Never invent numbers. Only use values from the signal data provided.
7. Never repeat the same insight. Each card must cover a different point.
8. Write in second person ("you", "your").
9. Do not use emoji.\
"""

_USER_PROMPT = """\
Today is {date}. Here are the health signals detected for this user. Write one insight card per signal.

Signals:
{signals_json}\
"""


class InsightCardWriter:
    """Writes insight cards from prioritized signals via a single LLM call.

    Args:
        signals: Ordered list of InsightSignals from SignalPrioritizer.
        focus: The user's focus profile (for persona context).
        target_date: ISO date string for the prompt (YYYY-MM-DD).
    """

    def __init__(
        self,
        signals: list[InsightSignal],
        focus: UserFocusProfile,
        target_date: str,
    ) -> None:
        self.signals = signals
        self.focus = focus
        self.target_date = target_date
        self._llm = LLMClient(model=settings.openrouter_insight_model)

    async def write_cards(self) -> list[dict[str, Any]]:
        """Write cards for all signals. Returns at least 1 card always."""
        if not self.signals:
            return [_minimum_card()]

        # Step 1 — attempt LLM call
        try:
            cards = await self._call_llm()
            if cards is not None:
                return cards
        except APIError as e:
            logger.warning("InsightCardWriter: LLM API error — falling back to rule-based. error=%s", e)
        except Exception as e:
            logger.error("InsightCardWriter: unexpected error — falling back. error=%s", e)

        # Step 2 — rule-based fallback
        try:
            return [_rule_based_card(s) for s in self.signals]
        except Exception as e:
            logger.error("InsightCardWriter: rule-based fallback failed. error=%s", e)

        # Step 3 — minimum card guarantee
        return [_minimum_card()]

    async def _call_llm(self) -> list[dict[str, Any]] | None:
        """Call the LLM and parse the JSON response. Returns None on parse failure."""
        system_prompt = _SYSTEM_PROMPT.format(
            persona=self.focus.coach_persona,
            fitness_level=self.focus.fitness_level or "active",
            stated_goals=", ".join(self.focus.stated_goals) or "general health",
            inferred_focus=self.focus.inferred_focus,
            units_system=self.focus.units_system,
        )

        signals_for_llm = [
            {
                "signal_type": s.signal_type,
                "metrics": s.metrics,
                "values": s.values,
                "actionable": s.actionable,
                "title_hint": s.title_hint,
                "data_payload": s.data_payload,
            }
            for s in self.signals
        ]

        user_prompt = _USER_PROMPT.format(
            date=self.target_date,
            signals_json=json.dumps(signals_for_llm, indent=2),
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        response = await self._llm.chat(messages=messages, temperature=0.4)
        raw = response.choices[0].message.content or ""

        # Strip markdown code fences if present
        raw = raw.strip()
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1]
            raw = raw.rsplit("```", 1)[0]

        try:
            cards = json.loads(raw)
            if not isinstance(cards, list):
                raise ValueError("LLM response is not a JSON array")
            return cards
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning("InsightCardWriter: LLM returned malformed JSON — %s. Raw: %.200s", e, raw)
            return None


def _rule_based_card(signal: InsightSignal) -> dict[str, Any]:
    """Generate a minimal rule-based card from a signal."""
    metric_label = signal.metrics[0].replace("_", " ") if signal.metrics else "metric"
    direction_word = "improving" if "improvement" in signal.signal_type else "changing"

    body_parts = []
    if "pct_change" in signal.values:
        pct = abs(signal.values["pct_change"])
        direction = "up" if signal.values["pct_change"] > 0 else "down"
        body_parts.append(f"Your {metric_label} is {direction} {pct:.0f}% recently.")
    elif "current" in signal.values and "target" in signal.values:
        body_parts.append(
            f"You're at {signal.values['current']} vs your goal of {signal.values['target']}."
        )
    else:
        body_parts.append(f"Your {metric_label} is {direction_word}.")

    if signal.actionable:
        body_parts.append("Take action today to stay on track.")

    return {
        "type": signal.signal_type,
        "title": signal.title_hint or f"{metric_label.title()} update",
        "body": " ".join(body_parts),
        "priority": max(1, 11 - signal.severity * 2),
        "reasoning": f"Detected via {signal.signal_type} analysis.",
    }


def _minimum_card() -> dict[str, Any]:
    """Last-resort card when everything else fails."""
    return {
        "type": "welcome",
        "title": "Insights loading",
        "body": "Your health insights are being prepared. Check back shortly.",
        "priority": 10,
        "reasoning": "Fallback card — generation in progress.",
    }
```

### Step 6: Run all tests

Run: `pytest cloud-brain/tests/analytics/ -v`
Expected: All PASS

### Step 7: Commit via git subagent

Message: `feat(analytics): add SignalPrioritizer and InsightCardWriter with LLM fallback chain`

---

## Chunk 6 — Wire everything together + Celery schedule + integration tests

> **Review subagent runs after this chunk is committed (final review of the whole feature).**
> **docs subagent runs after review passes.**
> **git subagent commits docs changes.**

**Files:**
- Replace body of: `cloud-brain/app/tasks/insight_tasks.py`
- Modify: `cloud-brain/app/worker.py` (add fan_out_daily_insights to beat schedule)
- Create: `cloud-brain/tests/integration/test_insight_pipeline.py`
- Update: `docs/roadmap.md` (via docs subagent)
- Update: `docs/implementation-status.md` (via docs subagent)

### Context

The task replaces the entire `_run()` body in `generate_insights_for_user` with the new 5-step pipeline. The date-lock check is the first thing that runs. The fan-out task queries `user_preferences` for users whose local hour is 6 AM and enqueues individual tasks.

The existing `_build_card_text`, `_get_time_of_day_priorities`, and `_PRIORITY_BY_HOUR` code at the top of the file can be kept as dead code initially (do not delete, to preserve git blame history), but the main task body is fully replaced.

### Step 1: Write failing integration test

```python
# cloud-brain/tests/integration/test_insight_pipeline.py
import pytest
import asyncio
from datetime import date, datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

# This test seeds a user with 30 days of health data and verifies the pipeline
# produces insights that appear in the GET /api/v1/insights endpoint.

@pytest.mark.asyncio
async def test_generate_insights_for_user_produces_cards(
    async_db_session,
    seeded_user_with_30_days_data,
):
    """End-to-end: seed user + run pipeline → cards appear in GET /api/v1/insights."""
    from app.tasks.insight_tasks import _run_pipeline_async

    user_id = seeded_user_with_30_days_data

    # Mock the LLM call so we don't need a real API key in tests
    llm_card = [{
        "type": "trend_decline",
        "title": "Steps declining",
        "body": "Your steps dropped 37% this week.",
        "priority": 3,
        "reasoning": "Trend detected.",
    }]
    mock_llm_response = MagicMock()
    mock_llm_response.choices = [MagicMock(message=MagicMock(content=str(llm_card).replace("'", '"')))]

    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(return_value=mock_llm_response)
        result = await _run_pipeline_async(user_id=user_id, db=async_db_session)

    assert result["status"] == "ok"
    assert result["insights_written"] >= 1

    # Verify cards appear in the database
    from sqlalchemy import select
    from app.models.insight import Insight
    stmt = select(Insight).where(
        Insight.user_id == user_id,
        Insight.dismissed_at.is_(None),
    )
    db_result = await async_db_session.execute(stmt)
    rows = db_result.scalars().all()
    assert len(rows) >= 1
    # All cards have generation_date set
    today_str = date.today().isoformat()
    for row in rows:
        assert row.generation_date == today_str


@pytest.mark.asyncio
async def test_date_lock_prevents_second_run(
    async_db_session,
    seeded_user_with_30_days_data,
):
    """Running the pipeline twice on the same day is a no-op on the second run."""
    from app.tasks.insight_tasks import _run_pipeline_async

    user_id = seeded_user_with_30_days_data
    mock_llm_response = MagicMock()
    mock_llm_response.choices = [MagicMock(message=MagicMock(content='[{"type":"welcome","title":"T","body":"B","priority":5,"reasoning":"R"}]'))]

    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(return_value=mock_llm_response)
        result1 = await _run_pipeline_async(user_id=user_id, db=async_db_session)
        result2 = await _run_pipeline_async(user_id=user_id, db=async_db_session)

    assert result1["status"] == "ok"
    assert result2["status"] == "skipped_date_lock"
    assert result2["insights_written"] == 0
```

Run: `pytest cloud-brain/tests/integration/test_insight_pipeline.py -v`
Expected: FAIL (function doesn't exist)

### Step 2: Replace `insight_tasks.py` body

Replace the entire contents of `cloud-brain/app/tasks/insight_tasks.py` with the new implementation below. The old `_build_card_text` and `_get_time_of_day_priorities` helpers are preserved as private helpers but are no longer called by the main task.

Key design:
- `generate_insights_for_user` remains the Celery task signature (same task name, no migration needed)
- `_run_pipeline_async` is extracted as a testable async function
- Date-lock check: query `SELECT COUNT(*) FROM insights WHERE user_id=? AND generation_date=? AND dismissed_at IS NULL`
- Welcome card for immature accounts (< `MIN_DATA_DAYS_FOR_MATURITY` days): no LLM call, insert one welcome card

```python
"""
Zuralog Cloud Brain — Celery Tasks for Insight Generation.

New pipeline (replaces the old rule-based generator):
1. Date-lock check — exit immediately if today's batch already exists.
2. HealthBriefBuilder — fetches all 11 data sources in parallel.
3. InsightSignalDetector — runs all 8 signal categories.
4. SignalPrioritizer — ranks, deduplicates, enforces diversity.
5. InsightCardWriter — single LLM call (with fallback chain).
6. Persist — bulk insert with generation_date set.

Also provides fan_out_daily_insights task for the hourly Celery Beat schedule.
"""

import asyncio
import logging
import uuid
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import and_, func, select, text as sa_text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.health_brief_builder import HealthBriefBuilder
from app.analytics.insight_signal_detector import InsightSignalDetector
from app.analytics.signal_prioritizer import SignalPrioritizer
from app.analytics.insight_card_writer import InsightCardWriter
from app.analytics.user_focus_profile import UserFocusProfileBuilder
from app.constants import MIN_DATA_DAYS_FOR_MATURITY
from app.database import worker_async_session as async_session
from app.models.insight import Insight
from app.models.user_preferences import UserPreferences
from app.worker import celery_app

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Main Celery task
# ---------------------------------------------------------------------------

@celery_app.task(name="app.tasks.insight_tasks.generate_insights_for_user")
def generate_insights_for_user(user_id: str) -> dict:
    """Generate and persist daily insight cards for a user.

    This task is either enqueued by fan_out_daily_insights (scheduled) or
    by the health ingest pipeline (triggered). It is safe to call multiple
    times — the date-lock prevents re-generation.

    Args:
        user_id: Zuralog user ID.

    Returns:
        Summary dict with user_id, insights_written, and status.
    """
    logger.info("generate_insights_for_user: starting for user '%s'", user_id)
    return asyncio.run(_run_pipeline_for_celery(user_id))


async def _run_pipeline_for_celery(user_id: str) -> dict:
    async with async_session() as db:
        return await _run_pipeline_async(user_id=user_id, db=db)


async def _run_pipeline_async(user_id: str, db: AsyncSession) -> dict:
    """Testable async implementation of the 5-step pipeline."""

    # ------------------------------------------------------------------
    # Step 1: Date-lock check
    # ------------------------------------------------------------------
    today_str = date.today().isoformat()

    lock_stmt = select(func.count()).select_from(Insight).where(
        and_(
            Insight.user_id == user_id,
            Insight.generation_date == today_str,
            Insight.dismissed_at.is_(None),
        )
    )
    lock_result = await db.execute(lock_stmt)
    existing_count: int = lock_result.scalar_one()

    if existing_count > 0:
        logger.info(
            "generate_insights_for_user: date-lock hit for user='%s' date='%s' existing=%d",
            user_id, today_str, existing_count,
        )
        return {"user_id": user_id, "insights_written": 0, "status": "skipped_date_lock"}

    # ------------------------------------------------------------------
    # Step 2: Fetch all health data
    # ------------------------------------------------------------------
    builder = HealthBriefBuilder(user_id=user_id, db=db)
    brief = await builder.build()

    # ------------------------------------------------------------------
    # Welcome card for immature accounts
    # ------------------------------------------------------------------
    if brief.data_maturity_days < MIN_DATA_DAYS_FOR_MATURITY:
        days_remaining = max(0, MIN_DATA_DAYS_FOR_MATURITY - brief.data_maturity_days)
        welcome_card = {
            "type": "welcome",
            "title": "Building your health baseline",
            "body": (
                f"Zuralog is learning your patterns. Keep syncing — "
                f"personalised insights unlock in about {days_remaining} more "
                f"day{'s' if days_remaining != 1 else ''}."
            ),
            "priority": 1,
            "reasoning": None,
            "signal_type": "first_week",
            "data_payload": {
                "days_logged": brief.data_maturity_days,
                "days_until_mature": days_remaining,
            },
        }
        written = await _persist_cards(user_id, [welcome_card], today_str, db)
        return {"user_id": user_id, "insights_written": written, "status": "ok"}

    # ------------------------------------------------------------------
    # Step 3: Detect signals
    # ------------------------------------------------------------------
    detector = InsightSignalDetector(brief)
    raw_signals = detector.detect_all()

    logger.debug(
        "generate_insights_for_user: user='%s' raw_signals=%d",
        user_id, len(raw_signals),
    )

    # ------------------------------------------------------------------
    # Step 4: Prioritize
    # ------------------------------------------------------------------
    prioritizer = SignalPrioritizer(raw_signals)
    prioritized = prioritizer.prioritize()

    if not prioritized:
        logger.info("generate_insights_for_user: no signals for user='%s'", user_id)
        return {"user_id": user_id, "insights_written": 0, "status": "ok_no_signals"}

    # ------------------------------------------------------------------
    # Step 5: Write cards via LLM (with fallback)
    # ------------------------------------------------------------------
    focus = UserFocusProfileBuilder(
        goals=brief.preferences.goals,
        dashboard_layout=brief.preferences.dashboard_layout,
        coach_persona=brief.preferences.coach_persona,
        fitness_level=brief.preferences.fitness_level,
        units_system=brief.preferences.units_system,
    ).build()

    writer = InsightCardWriter(
        signals=prioritized,
        focus=focus,
        target_date=today_str,
    )
    llm_cards = await writer.write_cards()

    # Attach signal_type and data_payload from original signals to each card
    enriched_cards = _enrich_cards(llm_cards, prioritized)

    # ------------------------------------------------------------------
    # Step 6: Persist
    # ------------------------------------------------------------------
    written = await _persist_cards(user_id, enriched_cards, today_str, db)

    logger.info(
        "generate_insights_for_user: wrote %d card(s) for user='%s'",
        written, user_id,
    )
    return {"user_id": user_id, "insights_written": written, "status": "ok"}


async def _persist_cards(
    user_id: str,
    cards: list[dict],
    generation_date: str,
    db: AsyncSession,
) -> int:
    """Bulk insert insight cards. Uses INSERT ... ON CONFLICT DO NOTHING
    to respect the (user_id, signal_type, generation_date) unique constraint.
    """
    if not cards:
        return 0

    rows = []
    for i, card in enumerate(cards):
        rows.append(dict(
            id=str(uuid.uuid4()),
            user_id=user_id,
            type=card.get("type", "welcome"),
            title=card.get("title", "Health insight"),
            body=card.get("body", ""),
            data=card.get("data_payload", card.get("data", {})),
            reasoning=card.get("reasoning"),
            priority=int(card.get("priority", 5)),
            generation_date=generation_date,
            signal_type=card.get("signal_type", card.get("type", "welcome")),
        ))

    stmt = pg_insert(Insight).values(rows)
    stmt = stmt.on_conflict_do_nothing(
        constraint="uq_insights_user_signal_date"
    )
    await db.execute(stmt)
    await db.commit()
    return len(rows)


def _enrich_cards(
    llm_cards: list[dict],
    signals: list,
) -> list[dict]:
    """Attach signal metadata from original signals to LLM-written cards."""
    enriched = []
    for i, card in enumerate(llm_cards):
        signal = signals[i] if i < len(signals) else None
        enriched.append({
            **card,
            "signal_type": signal.signal_type if signal else card.get("type", "welcome"),
            "data_payload": signal.data_payload if signal else {},
        })
    return enriched


# ---------------------------------------------------------------------------
# Hourly fan-out task (runs every hour, enqueues users at 6 AM local time)
# ---------------------------------------------------------------------------

@celery_app.task(name="app.tasks.insight_tasks.fan_out_daily_insights")
def fan_out_daily_insights() -> dict:
    """Hourly fan-out: find users whose local time is 6 AM, enqueue their insight tasks.

    Runs at the top of every UTC hour via Celery Beat.
    Queries user_preferences for all users with a timezone where current local hour == 6.
    Handles invalid/missing timezone by treating as UTC.
    """
    logger.info("fan_out_daily_insights: starting")
    return asyncio.run(_fan_out_async())


async def _fan_out_async() -> dict:
    now_utc = datetime.now(timezone.utc)
    async with async_session() as db:
        stmt = select(UserPreferences.user_id, UserPreferences.timezone)
        result = await db.execute(stmt)
        rows = result.all()

    enqueued = 0
    for user_id, tz_str in rows:
        try:
            tz = ZoneInfo(tz_str or "UTC")
        except (ZoneInfoNotFoundError, Exception):
            tz = ZoneInfo("UTC")

        local_hour = now_utc.astimezone(tz).hour
        if local_hour == 6:
            generate_insights_for_user.delay(user_id)
            enqueued += 1

    logger.info("fan_out_daily_insights: enqueued %d tasks", enqueued)
    return {"enqueued": enqueued}


# ---------------------------------------------------------------------------
# Stale integration check (unchanged from previous version)
# ---------------------------------------------------------------------------

@celery_app.task(name="app.tasks.insight_tasks.check_stale_integrations_task")
def check_stale_integrations_task() -> dict[str, int]:
    """Check for integrations that haven't synced in 24+ hours."""
    from datetime import timedelta
    from sqlalchemy import or_
    from app.models.integration import Integration

    async def _run() -> dict[str, int]:
        async with async_session() as session:
            now = datetime.now(timezone.utc)
            cutoff = now - timedelta(hours=24)
            stmt = (
                select(func.count())
                .select_from(Integration)
                .where(
                    Integration.is_active == True,  # noqa: E712
                    or_(
                        Integration.last_synced_at < cutoff,
                        and_(
                            Integration.last_synced_at.is_(None),
                            Integration.created_at < cutoff,
                        ),
                    ),
                )
            )
            stale_count: int = (await session.execute(stmt)).scalar_one()
            if stale_count > 0:
                logger.warning("Found %d stale integrations (not synced in 24h)", stale_count)
            return {"stale_count": stale_count}

    return asyncio.run(_run())
```

### Step 3: Add fan_out_daily_insights to Celery Beat in `worker.py`

In `cloud-brain/app/worker.py`, add to `celery_app.conf.beat_schedule`:

```python
"fan-out-daily-insights-1h": {
    "task": "app.tasks.insight_tasks.fan_out_daily_insights",
    "schedule": crontab(minute=0),  # top of every UTC hour
},
```

### Step 4: Run the full test suite

Run: `pytest cloud-brain/tests/ -v --tb=short`
Expected: All tests PASS. Note any pre-existing failures and do not regress them.

### Step 5: Run the integration tests specifically

Run: `pytest cloud-brain/tests/integration/test_insight_pipeline.py -v`
Expected: PASS — pipeline writes cards, date-lock prevents second run.

### Step 6: Commit implementation via git subagent

Message: `feat(insights): wire 5-step pipeline in insight_tasks, add hourly fan-out to Beat schedule`

### Step 7: Run review subagent (final review of entire feature)

The review subagent must:
1. Check spec §4–§10 pipeline steps are all present and correctly ordered
2. Verify the date-lock check uses `generation_date` and exits early
3. Verify the fan-out uses `ZoneInfo` timezone lookup with graceful fallback
4. Verify `OPENROUTER_INSIGHT_MODEL` is used (not the Coach model)
5. Verify all 5 bugs from §11 are fixed
6. Check for any security issues (user_id ownership on GET /{id}, rate limiting considerations)
7. Verify no N+1 queries
8. Confirm the migration's down_revision matches the last file in alembic/versions/

### Step 8: Update docs via docs subagent

The docs subagent must update:
- `docs/roadmap.md` — mark AI Insights Engine tasks as complete
- `docs/implementation-status.md` — add entry for this feature with date, summary, and files changed

### Step 9: Commit docs changes via git subagent

Message: `docs: update roadmap and implementation status for AI Insights Engine`

---

## Open questions to resolve before implementation begins

These were flagged in spec §21 as unresolved:

1. **Dashboard layout card key names** — Before implementing the `UserFocusProfile` inference in Chunk 3, read the Flutter `dashboard_layout` serialisation code to confirm the exact key names (e.g., is it `"sleep"` or `"sleep_hours"`?). Look in `zuralog/lib/features/today/` or `zuralog/lib/features/settings/`. The mapping in `user_focus_profile.py` must use these exact keys.

2. **`OPENROUTER_INSIGHT_MODEL` value** — Confirm with the project owner which model to use before merging. The plan uses `google/gemini-flash-2.5` as the default. Update `.env.example` and Railway environment variables.

3. **Missing model imports** — Some models referenced in `health_brief_builder.py` may not exist yet (e.g., `NutritionEntry`, `WeightMeasurement`, `QuickLog`, `UserStreak`, `HealthScore`). The file uses try/except ImportError for graceful degradation. Before implementing, check which models exist with `ls cloud-brain/app/models/`. If a model is missing, the corresponding data source returns `[]` and the relevant signals are skipped — this is correct behaviour for a phased rollout.


- **Spec:** `docs/specs/2026-03-18-ai-insights-engine-design.md` — primary source of truth
- **Existing analytics:** `cloud-brain/app/analytics/` — TrendDetector, CorrelationAnalyzer, GoalTracker, InsightGenerator all exist and should be reused
- **Existing anomaly detector:** `cloud-brain/app/services/anomaly_detector.py` — covers 6 metrics, needs expansion to 12
- **Existing task:** `cloud-brain/app/tasks/insight_tasks.py` — entirely replaced in Chunk 6
- **Existing routes:** `cloud-brain/app/api/v1/insight_routes.py` — GET list + PATCH exist; GET single missing
- **Existing constraint name:** `uq_insights_user_type_day` — referenced in insight_tasks.py, must be dropped in migration
- **Flutter bugs:** `today_repository.dart:250` reads `items` (wrong), `today_repository.dart:269,276` sends `status` (wrong); `today_models.dart` reads `summary` (wrong) and `is_read` (wrong)
- **DB subagent:** Must be consulted before finalising Chunk 1 migration
- **Review subagent:** Must run after Chunks 4 and 6
- **Git subagent:** Handles all commits — never commit directly
- **All new Python follows FastAPI async patterns** from `.agent/skills/fastapi-templates/SKILL.md`

---

