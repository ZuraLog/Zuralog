"""
Zuralog Cloud Brain — Food Search Service.

Handles food search against the database (USDA-seeded data and previously
cached foods). AI estimation utilities are provided for use by the
Describe/Parse path — search itself is database-only. Also manages
correction learning: when enough users correct the same food's nutrition
values, the cache entry is updated with averaged corrections.
"""

import json
import logging
import re
import uuid
from datetime import datetime, timezone

import sentry_sdk
from openai import APIError
from sqlalchemy import select, text, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.llm_client import LLMClient
from app.config import settings
from app.models.food_cache import FoodCache
from app.models.food_correction import FoodCorrection
from app.utils.sanitize import sanitize_for_llm

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_SIMILARITY_THRESHOLD = 0.3
_MIN_CORRECTION_USERS = 5
_BOUNDS_RATIO_MAX = 3.0
_BOUNDS_RATIO_MIN = 0.3

_ESTIMATION_SYSTEM_PROMPT = (
    "You are a nutrition database. Given a food name, return its estimated "
    "nutritional values for a single standard serving. Always use exactly one "
    "serving — never multiple.\n"
    "Return ONLY a JSON object with: food_name, serving_size, serving_unit, "
    "calories_per_serving, protein_per_serving, carbs_per_serving, "
    "fat_per_serving, confidence (0.0-1.0)"
)


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def _normalize_food_name(name: str) -> str:
    """Lowercase, strip, remove non-alphanumeric except spaces, collapse whitespace."""
    name = name.lower().strip()
    name = re.sub(r"[^a-z0-9 ]", "", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name


def _make_external_id(normalized_name: str) -> str:
    """Return a deterministic external ID for an AI-estimated food entry."""
    return f"ai:{normalized_name.replace(' ', '-')}"


async def _estimate_food_nutrition(food_name: str) -> dict:
    """Call the LLM to estimate nutrition for a single food item.

    Uses the cheaper insight model to keep costs low for simple lookups.

    Args:
        food_name: The food name to estimate (already sanitized).

    Returns:
        A dict with keys: food_name, serving_size, serving_unit,
        calories_per_serving, protein_per_serving, carbs_per_serving,
        fat_per_serving, confidence.

    Raises:
        APIError: If the LLM call fails after retries.
        ValueError: If the LLM response cannot be parsed as valid JSON.
    """
    client = LLMClient(model=settings.openrouter_insight_model)
    sanitized_name = sanitize_for_llm(food_name)

    response = await client.chat(
        messages=[
            {"role": "system", "content": _ESTIMATION_SYSTEM_PROMPT},
            {"role": "user", "content": sanitized_name},
        ],
        temperature=0.3,
        max_tokens=256,
    )

    raw = response.choices[0].message.content.strip()

    # The model sometimes wraps JSON in markdown code fences — strip them.
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)

    try:
        estimated = json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error(
            "Failed to parse LLM nutrition estimate for '%s': %s — raw: %s",
            food_name,
            exc,
            raw[:500],
        )
        sentry_sdk.capture_exception(exc)
        raise ValueError(f"LLM returned unparseable nutrition estimate for '{food_name}'") from exc

    return estimated


async def _upsert_food_cache(
    db: AsyncSession,
    external_id: str,
    estimated: dict,
) -> dict:
    """Insert or update a food_cache entry from an AI estimation result.

    Returns the row as a plain dict suitable for API responses.
    """
    row_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    model_used = settings.openrouter_insight_model
    confidence = estimated.get("confidence", 0.5)

    values = {
        "id": row_id,
        "external_id": external_id,
        "name": estimated.get("food_name", external_id),
        "brand": None,
        "serving_size": float(estimated.get("serving_size", 1)),
        "serving_unit": estimated.get("serving_unit", "serving"),
        "calories_per_serving": float(estimated.get("calories_per_serving", 0)),
        "protein_per_serving": float(estimated.get("protein_per_serving", 0)),
        "carbs_per_serving": float(estimated.get("carbs_per_serving", 0)),
        "fat_per_serving": float(estimated.get("fat_per_serving", 0)),
        "metadata": {
            "source": "ai_estimated",
            "model": model_used,
            "confidence": confidence,
        },
        "fetched_at": now,
    }

    stmt = pg_insert(FoodCache).values(**values)
    stmt = stmt.on_conflict_do_update(
        index_elements=["external_id"],
        set_={
            "name": stmt.excluded.name,
            "serving_size": stmt.excluded.serving_size,
            "serving_unit": stmt.excluded.serving_unit,
            "calories_per_serving": stmt.excluded.calories_per_serving,
            "protein_per_serving": stmt.excluded.protein_per_serving,
            "carbs_per_serving": stmt.excluded.carbs_per_serving,
            "fat_per_serving": stmt.excluded.fat_per_serving,
            "metadata": stmt.excluded.metadata,
            "fetched_at": stmt.excluded.fetched_at,
        },
    )
    await db.execute(stmt)
    await db.commit()

    # Return a clean dict for the caller.
    values["id"] = str(values["id"])
    return values


# ---------------------------------------------------------------------------
# Correction learning (private)
# ---------------------------------------------------------------------------


async def _process_food_corrections(db: AsyncSession, food_name: str) -> None:
    """If enough unique users have corrected this food, update the cache.

    Requires at least ``_MIN_CORRECTION_USERS`` distinct users before
    overwriting the cached values. When the threshold is met, the cache
    entry is updated with the average of all corrected values.
    """
    # Count unique users who submitted a correction for this food.
    count_result = await db.execute(
        select(func.count(func.distinct(FoodCorrection.user_id))).where(
            FoodCorrection.food_name == food_name,
        )
    )
    unique_users = count_result.scalar() or 0

    if unique_users < _MIN_CORRECTION_USERS:
        logger.debug(
            "Only %d unique correction users for '%s' (need %d) — skipping update",
            unique_users,
            food_name,
            _MIN_CORRECTION_USERS,
        )
        return

    # Compute averages across all corrections.
    avg_result = await db.execute(
        select(
            func.avg(FoodCorrection.corrected_calories).label("avg_calories"),
            func.avg(FoodCorrection.corrected_protein_g).label("avg_protein"),
            func.avg(FoodCorrection.corrected_carbs_g).label("avg_carbs"),
            func.avg(FoodCorrection.corrected_fat_g).label("avg_fat"),
        ).where(FoodCorrection.food_name == food_name)
    )
    avgs = avg_result.one()

    # Update the food_cache entry.
    external_id = _make_external_id(food_name)
    await db.execute(
        FoodCache.__table__.update()
        .where(FoodCache.external_id == external_id)
        .values(
            calories_per_serving=round(float(avgs.avg_calories), 2),
            protein_per_serving=round(float(avgs.avg_protein), 2),
            carbs_per_serving=round(float(avgs.avg_carbs), 2),
            fat_per_serving=round(float(avgs.avg_fat), 2),
            metadata_={
                "source": "user_corrected",
                "correction_count": unique_users,
            },
            fetched_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()

    logger.info(
        "Updated food_cache for '%s' from %d user corrections: "
        "%.1f cal, %.1f p, %.1f c, %.1f f",
        food_name,
        unique_users,
        avgs.avg_calories,
        avgs.avg_protein,
        avgs.avg_carbs,
        avgs.avg_fat,
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


async def search_foods(
    db: AsyncSession,
    query: str,
    limit: int = 10,
) -> list[dict]:
    """Search for foods in the database using trigram similarity.

    Queries the food_cache table (USDA-seeded data and previously cached
    foods) using PostgreSQL trigram similarity (pg_trgm). Returns only
    database results — no AI fallback. AI estimation is handled
    separately through the Describe/Parse path.

    Args:
        db: Active async database session.
        query: The user's free-text food search query.
        limit: Maximum number of results to return. Defaults to 10.

    Returns:
        A list of dicts, each representing a food cache entry.
        Returns an empty list if no matches are found.
    """
    normalized = _normalize_food_name(query)
    if not normalized:
        return []

    # Try the cache first using pg_trgm similarity search.
    result = await db.execute(
        text(
            "SELECT id, external_id, name, brand, serving_size, serving_unit, "
            "calories_per_serving, protein_per_serving, carbs_per_serving, "
            "fat_per_serving, metadata, fetched_at "
            "FROM food_cache "
            "WHERE name % :query AND similarity(name, :query) > :threshold "
            "ORDER BY similarity(name, :query) DESC "
            "LIMIT :limit"
        ),
        {"query": normalized, "threshold": _SIMILARITY_THRESHOLD, "limit": limit},
    )
    rows = result.mappings().all()

    if rows:
        logger.debug("Cache hit for '%s': %d results", normalized, len(rows))
        return [
            {
                "id": str(r["id"]),
                "name": r["name"],
                "brand": r["brand"],
                "serving_size": float(r["serving_size"]),
                "serving_unit": r["serving_unit"],
                "calories_per_serving": float(r["calories_per_serving"]),
                "protein_per_serving": float(r["protein_per_serving"]),
                "carbs_per_serving": float(r["carbs_per_serving"]),
                "fat_per_serving": float(r["fat_per_serving"]),
                "source": (r["metadata"] or {}).get("source", "cached") if r["metadata"] else "cached",
            }
            for r in rows
        ]

    # No cache results — return empty. AI estimation only happens
    # through the Describe/Parse path, not through search.
    return []


async def record_correction(
    db: AsyncSession,
    user_id: str,
    food_name: str,
    original_calories: float,
    corrected_calories: float,
    original_protein_g: float,
    corrected_protein_g: float,
    original_carbs_g: float,
    corrected_carbs_g: float,
    original_fat_g: float,
    corrected_fat_g: float,
) -> None:
    """Record a user's correction to AI-estimated nutrition and trigger learning.

    Validates that corrections are within reasonable bounds (0.3x to 3x of
    the original value) to prevent abuse or accidental bad data.

    Args:
        db: Active async database session.
        user_id: The authenticated user's ID.
        food_name: The food name being corrected.
        original_calories: Original AI-estimated calories.
        corrected_calories: User-corrected calories.
        original_protein_g: Original AI-estimated protein (grams).
        corrected_protein_g: User-corrected protein (grams).
        original_carbs_g: Original AI-estimated carbs (grams).
        corrected_carbs_g: User-corrected carbs (grams).
        original_fat_g: Original AI-estimated fat (grams).
        corrected_fat_g: User-corrected fat (grams).

    Raises:
        ValueError: If any corrected value is more than 3x or less than
            0.3x the original value.
    """
    # Bounds check — reject corrections that are wildly off from the original.
    pairs = [
        ("calories", original_calories, corrected_calories),
        ("protein", original_protein_g, corrected_protein_g),
        ("carbs", original_carbs_g, corrected_carbs_g),
        ("fat", original_fat_g, corrected_fat_g),
    ]
    for label, original, corrected in pairs:
        if original > 0:
            ratio = corrected / original
            if ratio > _BOUNDS_RATIO_MAX or ratio < _BOUNDS_RATIO_MIN:
                raise ValueError(
                    f"Corrected {label} ({corrected}) is outside the "
                    f"acceptable range ({original * _BOUNDS_RATIO_MIN:.1f} – "
                    f"{original * _BOUNDS_RATIO_MAX:.1f}) for original value {original}"
                )

    normalized = _normalize_food_name(food_name)
    external_id = _make_external_id(normalized)

    # Look up the food_cache entry (may be None if the food was never cached).
    cache_result = await db.execute(
        select(FoodCache.id).where(FoodCache.external_id == external_id)
    )
    food_cache_id = cache_result.scalar_one_or_none()

    # Insert the correction record.
    correction = FoodCorrection(
        user_id=user_id,
        food_cache_id=food_cache_id,
        food_name=normalized,
        original_calories=original_calories,
        corrected_calories=corrected_calories,
        original_protein_g=original_protein_g,
        corrected_protein_g=corrected_protein_g,
        original_carbs_g=original_carbs_g,
        corrected_carbs_g=corrected_carbs_g,
        original_fat_g=original_fat_g,
        corrected_fat_g=corrected_fat_g,
    )
    db.add(correction)
    await db.commit()

    logger.info(
        "Recorded correction for '%s' from user=%s (cache_id=%s)",
        normalized,
        user_id,
        food_cache_id,
    )

    # Trigger correction learning to see if we have enough data to update the cache.
    await _process_food_corrections(db, normalized)
