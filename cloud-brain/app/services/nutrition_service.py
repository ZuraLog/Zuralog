"""
Zuralog Cloud Brain — Nutrition Service.

Handles recomputation of the daily nutrition summary whenever meals
are created, updated, or deleted. The summary is upserted into
nutrition_daily_summaries so the dashboard can read totals in a
single fast query.
"""

import logging
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.meal import Meal
from app.models.nutrition_daily_summary import NutritionDailySummary
from app.utils.user_date import get_user_local_date

logger = logging.getLogger(__name__)


async def recompute_nutrition_summary(
    db: AsyncSession,
    user_id: str,
    summary_date: date,
) -> None:
    """Recompute and upsert the daily nutrition summary for a given user and date.

    Fetches all non-deleted meals for the user on the given date, sums the
    macronutrient values across every food item in every meal, and writes
    the totals into nutrition_daily_summaries using an upsert (insert or
    update on conflict).

    Args:
        db: Active async database session.
        user_id: The authenticated user's ID.
        summary_date: The calendar date to recompute.
    """
    # Build UTC day boundaries from the calendar date.
    day_start = datetime.combine(summary_date, time.min, tzinfo=timezone.utc)
    day_end = datetime.combine(summary_date, time.max, tzinfo=timezone.utc)

    # Fetch all non-deleted meals for this user and date.
    # The Meal model's `foods` relationship uses selectin loading,
    # so food items are loaded automatically with each meal.
    result = await db.execute(
        select(Meal).where(
            Meal.user_id == user_id,
            Meal.logged_at >= day_start,
            Meal.logged_at <= day_end,
            Meal.deleted_at.is_(None),
        )
    )
    meals = result.scalars().all()

    # Sum macros across all foods in all meals.
    total_calories = 0.0
    total_protein = 0.0
    total_carbs = 0.0
    total_fat = 0.0
    for meal in meals:
        for food in meal.foods:
            total_calories += food.calories or 0.0
            total_protein += food.protein_g or 0.0
            total_carbs += food.carbs_g or 0.0
            total_fat += food.fat_g or 0.0

    # Upsert into nutrition_daily_summaries.
    stmt = pg_insert(NutritionDailySummary).values(
        user_id=user_id,
        date=summary_date,
        total_calories=round(total_calories, 2),
        total_protein_g=round(total_protein, 2),
        total_carbs_g=round(total_carbs, 2),
        total_fat_g=round(total_fat, 2),
        meal_count=len(meals),
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={
            "total_calories": stmt.excluded.total_calories,
            "total_protein_g": stmt.excluded.total_protein_g,
            "total_carbs_g": stmt.excluded.total_carbs_g,
            "total_fat_g": stmt.excluded.total_fat_g,
            "meal_count": stmt.excluded.meal_count,
        },
    )
    await db.execute(stmt)
    await db.commit()

    logger.info(
        "Recomputed nutrition summary for user=%s date=%s: "
        "%.1f cal, %.1f p, %.1f c, %.1f f (%d meals)",
        user_id,
        summary_date,
        total_calories,
        total_protein,
        total_carbs,
        total_fat,
        len(meals),
    )


# ---------------------------------------------------------------------------
# Range helpers
# ---------------------------------------------------------------------------

_RANGE_TO_DAYS: dict[str, int] = {
    "7d": 7,
    "30d": 30,
    "3m": 90,
    "6m": 180,
    "1y": 365,
}


def _range_to_day_count(range_str: str) -> int:
    """Convert a range string to a day count. Raises ValueError for unknown ranges."""
    count = _RANGE_TO_DAYS.get(range_str)
    if count is None:
        raise ValueError(
            f"Unknown range: {range_str!r}. "
            f"Must be one of {sorted(_RANGE_TO_DAYS.keys())}"
        )
    return count


# ---------------------------------------------------------------------------
# Trend query
# ---------------------------------------------------------------------------


async def get_nutrition_trend(
    db: AsyncSession,
    user_id: str,
    range_str: str,
) -> list[dict]:
    """Fetch per-day nutrition totals for the trend chart.

    Returns a list of dicts with keys: date, calories, protein_g, is_today.
    Days with no logged meals are excluded.
    """
    days = _range_to_day_count(range_str)
    local_date = await get_user_local_date(db, user_id)
    start_date = local_date - timedelta(days=days - 1)

    result = await db.execute(
        select(NutritionDailySummary)
        .where(
            NutritionDailySummary.user_id == user_id,
            NutritionDailySummary.date >= start_date,
            NutritionDailySummary.date <= local_date,
        )
        .order_by(NutritionDailySummary.date)
    )
    rows = result.scalars().all()

    return [
        {
            "date": str(row.date),
            "calories": float(row.total_calories) if row.total_calories is not None else None,
            "protein_g": float(row.total_protein_g) if row.total_protein_g is not None else None,
            "is_today": row.date == local_date,
        }
        for row in rows
    ]


# ---------------------------------------------------------------------------
# All-Data query
# ---------------------------------------------------------------------------


async def get_nutrition_all_data(
    db: AsyncSession,
    user_id: str,
    range_str: str,
) -> list[dict]:
    """Fetch per-day rows for every nutrition metric for the All-Data screen.

    Returns a list of dicts with keys: date, is_today, values (dict with
    calories, protein, carbs, fat, meals). Days with no logged meals are
    excluded.
    """
    days = _range_to_day_count(range_str)
    local_date = await get_user_local_date(db, user_id)
    start_date = local_date - timedelta(days=days - 1)

    result = await db.execute(
        select(NutritionDailySummary)
        .where(
            NutritionDailySummary.user_id == user_id,
            NutritionDailySummary.date >= start_date,
            NutritionDailySummary.date <= local_date,
        )
        .order_by(NutritionDailySummary.date)
    )
    rows = result.scalars().all()

    return [
        {
            "date": str(row.date),
            "is_today": row.date == local_date,
            "values": {
                "calories": float(row.total_calories) if row.total_calories is not None else None,
                "protein": float(row.total_protein_g) if row.total_protein_g is not None else None,
                "carbs": float(row.total_carbs_g) if row.total_carbs_g is not None else None,
                "fat": float(row.total_fat_g) if row.total_fat_g is not None else None,
                "meals": float(row.meal_count) if row.meal_count is not None else None,
            },
        }
        for row in rows
    ]


# ---------------------------------------------------------------------------
# AI Summary query
# ---------------------------------------------------------------------------


async def get_nutrition_ai_summary(
    db: AsyncSession,
    user_id: str,
) -> dict:
    """Fetch today's AI-generated nutrition summary from the insights table.

    Returns a dict with keys: ai_summary (str | None), ai_generated_at (str | None).
    Both are None when no insight exists for today.
    """
    from app.models.insight import Insight  # noqa: PLC0415

    local_date = await get_user_local_date(db, user_id)

    result = await db.execute(
        select(Insight)
        .where(
            Insight.user_id == user_id,
            Insight.type == "nutrition_summary",
            Insight.generation_date == local_date,
            Insight.dismissed_at.is_(None),
        )
        .order_by(Insight.priority.asc())
        .limit(1)
    )
    insight = result.scalars().first()

    if insight:
        return {
            "ai_summary": insight.body,
            "ai_generated_at": (
                insight.created_at
                if insight.created_at
                else None
            ),
        }
    return {
        "ai_summary": None,
        "ai_generated_at": None,
    }
