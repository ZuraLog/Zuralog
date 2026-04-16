"""
Zuralog Cloud Brain — Nutrition Meal CRUD API.

Endpoints:
  GET    /api/v1/nutrition/today            — Today's meals and daily summary.
  POST   /api/v1/nutrition/meals            — Create a new meal with food items.
  GET    /api/v1/nutrition/meals/{meal_id}  — Fetch a single meal by ID.
  PUT    /api/v1/nutrition/meals/{meal_id}  — Replace a meal entirely.
  DELETE /api/v1/nutrition/meals/{meal_id}  — Soft-delete a meal.
  GET    /api/v1/nutrition/foods/recent     — Most recent unique foods.

All endpoints are auth-guarded; users can only access their own data.
"""

import logging
import uuid
from datetime import date, datetime, time, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import func

from app.api.deps import get_authenticated_user_id
from app.api.v1.nutrition_schemas import MealCreateRequest, MealUpdateRequest
from app.database import get_db
from app.limiter import limiter
from app.models.meal import Meal
from app.models.meal_food import MealFood
from app.models.nutrition_daily_summary import NutritionDailySummary
from app.services.nutrition_service import recompute_nutrition_summary

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/nutrition", tags=["nutrition"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _food_to_response(food: MealFood) -> dict:
    """Convert a MealFood ORM instance to a plain dict for JSON response."""
    return {
        "id": str(food.id),
        "food_name": food.food_name,
        "portion_amount": food.portion_amount,
        "portion_unit": food.portion_unit,
        "calories": food.calories,
        "protein_g": food.protein_g,
        "carbs_g": food.carbs_g,
        "fat_g": food.fat_g,
    }


def _meal_to_response(meal: Meal) -> dict:
    """Convert a Meal ORM instance (with loaded foods) to a plain dict.

    Includes nested foods list and computed macro totals.
    """
    foods = [_food_to_response(f) for f in meal.foods]
    total_calories = sum(f["calories"] for f in foods)
    total_protein = sum(f["protein_g"] for f in foods)
    total_carbs = sum(f["carbs_g"] for f in foods)
    total_fat = sum(f["fat_g"] for f in foods)

    return {
        "id": str(meal.id),
        "user_id": meal.user_id,
        "meal_type": meal.meal_type,
        "name": meal.name,
        "logged_at": meal.logged_at.isoformat(),
        "created_at": meal.created_at.isoformat(),
        "updated_at": meal.updated_at.isoformat(),
        "foods": foods,
        "total_calories": round(total_calories, 2),
        "total_protein_g": round(total_protein, 2),
        "total_carbs_g": round(total_carbs, 2),
        "total_fat_g": round(total_fat, 2),
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@limiter.limit("60/minute")
@router.get("/today")
async def get_today(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Fetch today's meals (newest first) and daily nutrition summary.

    Returns a dict with ``meals`` (list) and ``summary`` (object or null).
    """
    today = date.today()
    day_start = datetime.combine(today, time.min, tzinfo=timezone.utc)
    day_end = datetime.combine(today, time.max, tzinfo=timezone.utc)

    # Fetch today's meals, newest first.
    result = await db.execute(
        select(Meal)
        .where(
            Meal.user_id == user_id,
            Meal.logged_at >= day_start,
            Meal.logged_at <= day_end,
            Meal.deleted_at.is_(None),
        )
        .order_by(Meal.logged_at.desc())
    )
    meals = result.scalars().all()

    # Fetch the daily summary.
    summary_result = await db.execute(
        select(NutritionDailySummary).where(
            NutritionDailySummary.user_id == user_id,
            NutritionDailySummary.date == today,
        )
    )
    summary_row = summary_result.scalar_one_or_none()

    summary = None
    if summary_row:
        summary = {
            "date": summary_row.date.isoformat(),
            "total_calories": summary_row.total_calories,
            "total_protein_g": summary_row.total_protein_g,
            "total_carbs_g": summary_row.total_carbs_g,
            "total_fat_g": summary_row.total_fat_g,
            "meal_count": summary_row.meal_count,
        }

    return {
        "meals": [_meal_to_response(m) for m in meals],
        "summary": summary,
    }


@limiter.limit("30/minute")
@router.post("/meals", status_code=status.HTTP_201_CREATED)
async def create_meal(
    request: Request,
    body: MealCreateRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create a new meal with its food items.

    Auto-generates a meal name from the first food item if none is provided.
    Recomputes the daily nutrition summary after saving.
    """
    # Auto-generate name from first food if not provided.
    meal_name = body.name
    if not meal_name and body.foods:
        meal_name = body.foods[0].food_name

    meal = Meal(
        id=uuid.uuid4(),
        user_id=user_id,
        meal_type=body.meal_type,
        name=meal_name,
        logged_at=body.logged_at,
    )
    db.add(meal)

    for food_req in body.foods:
        food = MealFood(
            id=uuid.uuid4(),
            meal_id=meal.id,
            food_name=food_req.food_name,
            portion_amount=food_req.portion_amount,
            portion_unit=food_req.portion_unit,
            calories=food_req.calories,
            protein_g=food_req.protein_g,
            carbs_g=food_req.carbs_g,
            fat_g=food_req.fat_g,
        )
        db.add(food)

    await db.commit()
    await db.refresh(meal)

    # Recompute daily summary (best-effort — never block the main response).
    try:
        summary_date = body.logged_at.date()
        await recompute_nutrition_summary(db, user_id, summary_date)
    except Exception:
        logger.exception("Failed to recompute nutrition summary after create")

    return _meal_to_response(meal)


@limiter.limit("60/minute")
@router.get("/meals/{meal_id}")
async def get_meal(
    request: Request,
    meal_id: uuid.UUID,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Fetch a single meal by ID. Only the owning user can access it."""
    result = await db.execute(
        select(Meal).where(
            Meal.id == meal_id,
            Meal.user_id == user_id,
            Meal.deleted_at.is_(None),
        )
    )
    meal = result.scalar_one_or_none()
    if not meal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found",
        )
    return _meal_to_response(meal)


@limiter.limit("30/minute")
@router.put("/meals/{meal_id}")
async def update_meal(
    request: Request,
    meal_id: uuid.UUID,
    body: MealUpdateRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Replace a meal entirely — deletes old food items and inserts new ones.

    Recomputes the daily summary for both the old and new dates (in case the
    logged_at timestamp changed).
    """
    result = await db.execute(
        select(Meal).where(
            Meal.id == meal_id,
            Meal.user_id == user_id,
            Meal.deleted_at.is_(None),
        )
    )
    meal = result.scalar_one_or_none()
    if not meal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found",
        )

    old_date = meal.logged_at.date()

    # Delete old food items.
    for old_food in list(meal.foods):
        await db.delete(old_food)

    # Update meal fields.
    meal.meal_type = body.meal_type
    meal.name = body.name
    meal.logged_at = body.logged_at

    # Insert new food items.
    for food_req in body.foods:
        food = MealFood(
            id=uuid.uuid4(),
            meal_id=meal.id,
            food_name=food_req.food_name,
            portion_amount=food_req.portion_amount,
            portion_unit=food_req.portion_unit,
            calories=food_req.calories,
            protein_g=food_req.protein_g,
            carbs_g=food_req.carbs_g,
            fat_g=food_req.fat_g,
        )
        db.add(food)

    await db.commit()
    await db.refresh(meal)

    # Recompute summaries for both old and new dates.
    new_date = body.logged_at.date()
    try:
        await recompute_nutrition_summary(db, user_id, old_date)
        if new_date != old_date:
            await recompute_nutrition_summary(db, user_id, new_date)
    except Exception:
        logger.exception("Failed to recompute nutrition summary after update")

    return _meal_to_response(meal)


@limiter.limit("30/minute")
@router.delete("/meals/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meal(
    request: Request,
    meal_id: uuid.UUID,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Soft-delete a meal by setting deleted_at. Recomputes the daily summary."""
    result = await db.execute(
        select(Meal).where(
            Meal.id == meal_id,
            Meal.user_id == user_id,
            Meal.deleted_at.is_(None),
        )
    )
    meal = result.scalar_one_or_none()
    if not meal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found",
        )

    meal.deleted_at = func.now()
    await db.commit()

    # Recompute summary for the meal's date.
    try:
        summary_date = meal.logged_at.date()
        await recompute_nutrition_summary(db, user_id, summary_date)
    except Exception:
        logger.exception("Failed to recompute nutrition summary after delete")


@limiter.limit("60/minute")
@router.get("/foods/recent")
async def get_recent_foods(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the most recent unique foods (by name) for the user, limit 20.

    Uses DISTINCT ON to get the latest entry for each unique food name.
    """
    query = text("""
        SELECT DISTINCT ON (mf.food_name)
            mf.id,
            mf.food_name,
            mf.portion_amount,
            mf.portion_unit,
            mf.calories,
            mf.protein_g,
            mf.carbs_g,
            mf.fat_g,
            mf.created_at
        FROM meal_foods mf
        JOIN meals m ON m.id = mf.meal_id
        WHERE m.user_id = :user_id
          AND m.deleted_at IS NULL
        ORDER BY mf.food_name, mf.created_at DESC
        LIMIT 20
    """)

    result = await db.execute(query, {"user_id": user_id})
    rows = result.mappings().all()

    foods = [
        {
            "id": str(row["id"]),
            "food_name": row["food_name"],
            "portion_amount": float(row["portion_amount"]),
            "portion_unit": row["portion_unit"],
            "calories": float(row["calories"]),
            "protein_g": float(row["protein_g"]),
            "carbs_g": float(row["carbs_g"]),
            "fat_g": float(row["fat_g"]),
        }
        for row in rows
    ]

    return {"foods": foods}
