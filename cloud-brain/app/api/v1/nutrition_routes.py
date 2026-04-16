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

import base64
import json
import logging
import re
import uuid
from datetime import date, datetime, time, timezone

import httpx
import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from openai import APIError
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import func

from app.agent.llm_client import LLMClient
from app.api.deps import get_authenticated_user_id
from app.api.v1.nutrition_schemas import (
    CorrectionRequest,
    FoodSearchResponse,
    FoodSearchResult,
    MealCreateRequest,
    MealParseRequest,
    MealParseResponse,
    MealUpdateRequest,
    ParsedFoodItem,
)
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models.food_cache import FoodCache
from app.models.meal import Meal
from app.models.meal_food import MealFood
from app.models.nutrition_daily_summary import NutritionDailySummary
from app.services.food_search_service import record_correction, search_foods
from app.services.nutrition_service import recompute_nutrition_summary
from app.utils.sanitize import sanitize_for_llm

logger = logging.getLogger(__name__)

_MEAL_PARSE_SYSTEM_PROMPT = """\
You are a nutrition data extraction assistant for a health tracking app.

Your job: take a natural-language meal description and break it into individual food items with estimated nutritional values.

Rules:
1. Return ONLY a JSON object with a single key "foods" containing an array.
2. Each food item must have exactly these fields:
   - "food_name": string (clear, common name)
   - "portion_amount": number (numeric portion size)
   - "portion_unit": string (one of: g, ml, piece, slice, cup, tbsp, tsp, serving, oz, bowl)
   - "calories": number (estimated calories for this portion)
   - "protein_g": number (estimated protein in grams)
   - "carbs_g": number (estimated carbohydrates in grams)
   - "fat_g": number (estimated fat in grams)
   - "confidence": number (0.0 to 1.0 — how confident you are in this specific item's nutritional estimate. Use 0.8+ for well-known standard foods, 0.5-0.8 for reasonable guesses, below 0.5 for very uncertain items)
3. Separate compound items. "Toast with butter" becomes two items: toast and butter.
4. Use common-sense portion sizes when not specified.
5. Nutritional estimates should be reasonable approximations. They do not need to be exact.
6. If the description is ambiguous, make a reasonable assumption. Never ask for clarification.
7. Do not add foods that are not mentioned in the description.
8. Return between 1 and 50 food items.
9. No text outside the JSON object. No markdown fences. No explanation.\
"""

_IMAGE_SCAN_SYSTEM_PROMPT = """\
You are a nutrition data extraction assistant for a health tracking app.

Your job: analyze a food image and extract nutritional information.

The image may contain:
- A plate of food (identify each food item and estimate nutrition)
- A nutrition facts label (read the exact values from the label)
- A food product (identify the product and estimate nutrition)

Rules:
1. Return ONLY a JSON object with a single key "foods" containing an array.
2. Each food item must have exactly these fields:
   - "food_name": string (clear, common name)
   - "portion_amount": number (numeric portion size)
   - "portion_unit": string (one of: g, ml, piece, slice, cup, tbsp, tsp, serving, oz, bowl)
   - "calories": number (estimated calories for this portion)
   - "protein_g": number (estimated protein in grams)
   - "carbs_g": number (estimated carbohydrates in grams)
   - "fat_g": number (estimated fat in grams)
   - "confidence": number (0.0 to 1.0)
3. For nutrition labels: read exact values. Set confidence to 0.95.
4. For food plates: estimate portions visually. Use 0.5-0.8 confidence.
5. Separate compound items into individual food entries.
6. Return between 1 and 50 food items.
7. No text outside the JSON object. No markdown fences. No explanation.\
"""

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


@limiter.limit("30/minute")
@router.get("/foods/search", response_model=FoodSearchResponse)
async def search_food_cache(
    request: Request,
    q: str,
    limit: int = 10,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> FoodSearchResponse:
    """Search for foods by name. Checks the cache first, falls back to AI."""
    if not q or not q.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query must not be empty.",
        )
    if len(q) > 200:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query must be 200 characters or fewer.",
        )

    foods = await search_foods(db, q, limit)
    return FoodSearchResponse(
        foods=[FoodSearchResult(**f) for f in foods]
    )


@limiter.limit("20/minute")
@router.post("/foods/corrections", status_code=status.HTTP_201_CREATED)
async def submit_food_correction(
    request: Request,
    body: CorrectionRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Submit a correction when the user edits a food's nutrition values."""
    try:
        await record_correction(
            db=db,
            user_id=user_id,
            food_name=body.food_name,
            original_calories=body.original_calories,
            corrected_calories=body.corrected_calories,
            original_protein_g=body.original_protein_g,
            corrected_protein_g=body.corrected_protein_g,
            original_carbs_g=body.original_carbs_g,
            corrected_carbs_g=body.corrected_carbs_g,
            original_fat_g=body.original_fat_g,
            corrected_fat_g=body.corrected_fat_g,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return {"status": "recorded"}


# ---------------------------------------------------------------------------
# AI Meal Parse (Phase 2C)
# ---------------------------------------------------------------------------


@limiter.limit("10/minute")
@router.post("/meals/parse", response_model=MealParseResponse)
async def parse_meal_description(
    request: Request,
    body: MealParseRequest,
    user_id: str = Depends(get_authenticated_user_id),
) -> MealParseResponse:
    """Parse a natural-language meal description into structured food items.

    Uses Qwen 3.5 Flash via OpenRouter. Stateless — nothing is saved.
    Rate limited to 10/minute (AI calls are expensive).
    """
    description = sanitize_for_llm(body.description)
    if not description.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not process the meal description.",
        )

    # Build LLM client for the insight model (cheaper, faster).
    llm = LLMClient(model=settings.openrouter_insight_model)

    messages = [
        {"role": "system", "content": _MEAL_PARSE_SYSTEM_PROMPT},
        {"role": "user", "content": description},
    ]

    try:
        response = await llm.chat(
            messages=messages,
            temperature=0.3,
            max_tokens=2048,
        )
    except APIError as e:
        logger.error("Meal parse LLM call failed: %s", e)
        sentry_sdk.set_tag("ai.error_type", "meal_parse_failure")
        sentry_sdk.capture_exception(e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="The AI service is temporarily unavailable. Please try again in a moment.",
        )

    raw_content = (response.choices[0].message.content or "").strip()

    # Strip markdown code fences if the model wraps its output.
    if raw_content.startswith("```"):
        raw_content = raw_content.split("\n", 1)[-1]
        raw_content = raw_content.rsplit("```", 1)[0].strip()

    # Parse JSON.
    try:
        parsed = json.loads(raw_content)
    except (json.JSONDecodeError, ValueError) as e:
        logger.warning("Meal parse: malformed JSON — %s. Raw: %.300s", e, raw_content)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI returned an unexpected format. Please try rephrasing your meal description.",
        )

    if not isinstance(parsed, dict) or "foods" not in parsed:
        logger.warning("Meal parse: missing 'foods' key. Raw: %.300s", raw_content)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI returned an unexpected format. Please try rephrasing your meal description.",
        )

    raw_foods = parsed["foods"]
    if not isinstance(raw_foods, list) or len(raw_foods) == 0:
        logger.warning("Meal parse: empty foods list. Raw: %.300s", raw_content)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI could not identify any food items. Please try a more specific description.",
        )

    # Validate each food through Pydantic, skipping invalid items.
    validated_foods: list[ParsedFoodItem] = []
    for i, raw_food in enumerate(raw_foods):
        try:
            food = ParsedFoodItem.model_validate(raw_food)
            validated_foods.append(food)
        except Exception as e:
            logger.warning("Meal parse: skipping invalid food at index %d — %s", i, e)

    if not validated_foods:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI could not identify any valid food items. Please try rephrasing your meal description.",
        )

    return MealParseResponse(foods=validated_foods[:50])


# ---------------------------------------------------------------------------
# AI Image Scan (Phase 3C)
# ---------------------------------------------------------------------------


@limiter.limit("10/minute")
@router.post("/meals/scan-image", response_model=MealParseResponse)
async def scan_food_image(
    request: Request,
    file: UploadFile,
    user_id: str = Depends(get_authenticated_user_id),
) -> MealParseResponse:
    """Scan a food image and return structured food items with nutrition estimates.

    Accepts JPEG or PNG. Auto-detects food plates vs nutrition labels.
    Rate limited to 10/minute (vision calls are expensive).
    """
    # Validate content type
    allowed_types = {"image/jpeg", "image/png", "image/jpg"}
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG and PNG images are accepted.",
        )

    # Read and validate size
    file_bytes = await file.read()
    max_size = 10 * 1024 * 1024  # 10MB
    if len(file_bytes) > max_size:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Image must be smaller than 10MB.",
        )

    if len(file_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file uploaded.",
        )

    # Convert to base64
    b64_image = base64.b64encode(file_bytes).decode("utf-8")
    mime_type = file.content_type or "image/jpeg"

    # Build vision message
    llm = LLMClient(model=settings.openrouter_vision_model)
    messages = [
        {"role": "system", "content": _IMAGE_SCAN_SYSTEM_PROMPT},
        {"role": "user", "content": [
            {"type": "text", "text": "Analyze this food image and extract nutritional information."},
            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{b64_image}"}},
        ]},
    ]

    try:
        response = await llm.chat(
            messages=messages,
            temperature=0.3,
            max_tokens=2048,
        )
    except APIError as e:
        logger.error("Image scan LLM call failed: %s", e)
        sentry_sdk.set_tag("ai.error_type", "image_scan_failure")
        sentry_sdk.capture_exception(e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="The AI vision service is temporarily unavailable. Try describing the food instead.",
        )

    # Parse response — same pattern as parse_meal_description
    raw_content = (response.choices[0].message.content or "").strip()

    if raw_content.startswith("```"):
        raw_content = raw_content.split("\n", 1)[-1]
        raw_content = raw_content.rsplit("```", 1)[0].strip()

    try:
        parsed = json.loads(raw_content)
    except (json.JSONDecodeError, ValueError) as e:
        logger.warning("Image scan: malformed JSON — %s. Raw: %.300s", e, raw_content)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI could not process this image. Try a clearer photo or describe the food instead.",
        )

    if not isinstance(parsed, dict) or "foods" not in parsed:
        logger.warning("Image scan: missing 'foods' key. Raw: %.300s", raw_content)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI could not identify food in this image. Try a different angle or describe the food instead.",
        )

    raw_foods = parsed["foods"]
    if not isinstance(raw_foods, list) or len(raw_foods) == 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI could not identify any food items. Try a clearer photo.",
        )

    validated_foods: list[ParsedFoodItem] = []
    for i, raw_food in enumerate(raw_foods):
        try:
            food = ParsedFoodItem.model_validate(raw_food)
            validated_foods.append(food)
        except Exception as e:
            logger.warning("Image scan: skipping invalid food at index %d — %s", i, e)

    if not validated_foods:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The AI could not extract valid nutrition data. Try describing the food instead.",
        )

    return MealParseResponse(foods=validated_foods[:50])


# ---------------------------------------------------------------------------
# Barcode Lookup (Phase 3C)
# ---------------------------------------------------------------------------


@limiter.limit("30/minute")
@router.get("/foods/barcode/{code}")
async def lookup_barcode(
    request: Request,
    code: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Look up a food by barcode via Open Food Facts, with caching.

    Returns 404 if the product is not found.
    """
    # Validate barcode format
    code = code.strip()
    if not code.isdigit() or len(code) < 8 or len(code) > 14:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid barcode. Must be 8-14 digits.",
        )

    external_id = f"off:{code}"

    # Check cache first
    result = await db.execute(
        select(FoodCache).where(FoodCache.external_id == external_id)
    )
    cached = result.scalar_one_or_none()

    if cached:
        return {"food": {
            "id": str(cached.id),
            "name": cached.name,
            "brand": cached.brand,
            "serving_size": cached.serving_size,
            "serving_unit": cached.serving_unit,
            "calories_per_serving": cached.calories_per_serving,
            "protein_per_serving": cached.protein_per_serving,
            "carbs_per_serving": cached.carbs_per_serving,
            "fat_per_serving": cached.fat_per_serving,
            "source": "openfoodfacts",
        }}

    # Call Open Food Facts
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            off_response = await client.get(
                f"https://world.openfoodfacts.org/api/v2/product/{code}",
                params={"fields": "product_name,brands,serving_size,nutriments"},
            )
    except httpx.TimeoutException:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="The barcode lookup service timed out. Please try again.",
        )

    if off_response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found. Try taking a photo of the food instead.",
        )

    off_data = off_response.json()
    if off_data.get("status") != 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found. Try taking a photo of the food instead.",
        )

    product = off_data.get("product", {})
    nutriments = product.get("nutriments", {})

    product_name = product.get("product_name") or "Unknown product"
    brand = product.get("brands") or None

    # Parse serving size — default to 100g
    serving_size = 100.0
    serving_unit = "g"
    raw_serving = product.get("serving_size", "")
    if raw_serving:
        match = re.match(r"([\d.]+)\s*(\w+)?", str(raw_serving))
        if match:
            try:
                serving_size = float(match.group(1))
            except ValueError:
                pass
            if match.group(2):
                serving_unit = match.group(2).lower()

    # Extract nutrition — prefer per-serving, fall back to per-100g
    cal = nutriments.get("energy-kcal_serving") or nutriments.get("energy-kcal_100g") or 0
    protein = nutriments.get("proteins_serving") or nutriments.get("proteins_100g") or 0
    carbs = nutriments.get("carbohydrates_serving") or nutriments.get("carbohydrates_100g") or 0
    fat = nutriments.get("fat_serving") or nutriments.get("fat_100g") or 0

    # Cache the result
    stmt = pg_insert(FoodCache).values(
        id=uuid.uuid4(),
        external_id=external_id,
        name=product_name,
        brand=brand,
        serving_size=round(float(serving_size), 2),
        serving_unit=serving_unit,
        calories_per_serving=round(float(cal), 2),
        protein_per_serving=round(float(protein), 2),
        carbs_per_serving=round(float(carbs), 2),
        fat_per_serving=round(float(fat), 2),
        metadata_={"source": "openfoodfacts", "barcode": code},
        fetched_at=datetime.now(timezone.utc),
    ).on_conflict_do_update(
        index_elements=["external_id"],
        set_={
            "name": product_name,
            "brand": brand,
            "serving_size": round(float(serving_size), 2),
            "serving_unit": serving_unit,
            "calories_per_serving": round(float(cal), 2),
            "protein_per_serving": round(float(protein), 2),
            "carbs_per_serving": round(float(carbs), 2),
            "fat_per_serving": round(float(fat), 2),
            "metadata": {"source": "openfoodfacts", "barcode": code},
            "fetched_at": datetime.now(timezone.utc),
        },
    )
    await db.execute(stmt)
    await db.commit()

    # Fetch the cached entry to get the actual ID
    result = await db.execute(
        select(FoodCache).where(FoodCache.external_id == external_id)
    )
    cached = result.scalar_one_or_none()
    food_id = str(cached.id) if cached else ""

    return {"food": {
        "id": food_id,
        "name": product_name,
        "brand": brand,
        "serving_size": round(float(serving_size), 2),
        "serving_unit": serving_unit,
        "calories_per_serving": round(float(cal), 2),
        "protein_per_serving": round(float(protein), 2),
        "carbs_per_serving": round(float(carbs), 2),
        "fat_per_serving": round(float(fat), 2),
        "source": "openfoodfacts",
    }}
