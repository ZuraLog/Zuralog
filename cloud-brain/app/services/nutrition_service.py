"""
Zuralog Cloud Brain — Nutrition Service.

Handles recomputation of the daily nutrition summary whenever meals
are created, updated, or deleted. The summary is upserted into
nutrition_daily_summaries so the dashboard can read totals in a
single fast query.
"""

import logging
from datetime import date, datetime, time, timezone

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.meal import Meal
from app.models.nutrition_daily_summary import NutritionDailySummary

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
