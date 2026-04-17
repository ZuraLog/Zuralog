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
from typing import Literal

import httpx
import sentry_sdk
from fastapi import APIRouter, Depends, Form, HTTPException, Request, UploadFile, status
from openai import APIError
from pydantic import ValidationError
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
    GuidedQuestion,
    MealCreateRequest,
    MealParseRequest,
    MealParseResponse,
    MealRefineRequest,
    MealRefineResponse,
    MealUpdateRequest,
    NutritionRuleCreate,
    NutritionRuleUpdate,
    ParsedFoodItem,
)
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models.food_cache import FoodCache
from app.models.meal import Meal
from app.models.meal_food import MealFood
from app.models.nutrition_daily_summary import NutritionDailySummary
from app.models.nutrition_rule import NutritionRule
from app.services.food_search_service import record_correction, search_foods
from app.services.nutrition_service import recompute_nutrition_summary
from app.services.rule_suggestion import detect_suggested_rule
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
   - "applied_rules": array of strings (which user rules you used while estimating this food — see APPLIED RULES below)
3. Separate compound items. "Toast with butter" becomes two items: toast and butter.
4. Use common-sense portion sizes when not specified.
5. Nutritional estimates should be reasonable approximations. They do not need to be exact.
6. If the description is ambiguous, make a reasonable assumption. Never ask for clarification.
7. Return between 1 and 50 food items.
8. No text outside the JSON object. No markdown fences. No explanation.
9. Only use quantities the user explicitly mentioned. If the user says 'toast' without a number, assume 1. If they say 'two eggs', use 2. Never invent quantities that weren't stated.
10. Default portion sizes when not specified: 'toast' = 1 slice, 'egg' = 1 piece, 'coffee' = 1 cup (240ml), 'rice' = 1 bowl (200g cooked), 'chicken breast' = 1 piece (150g), 'banana' = 1 piece (120g).
11. When generating on_answer for add_food or replace_food, use realistic and conservative nutrition estimates — never optimistic, never punitive.

GUIDED MODE QUESTIONS:
If the user has Guided mode enabled (indicated by "GUIDED MODE" in the user message), after the foods array also return a "questions" array with follow-up questions that would improve accuracy. Otherwise, omit the questions array or return it empty.

Rules for questions:
- Only ask questions that would meaningfully change the calorie or macro count by at least 10%.
- Each question must have a unique id (q1, q2, q3, ...).
- Each question references a food by its food_index (0-based into the foods array).
- Pick the best component_type for the question:
  * "slider" for continuous numeric ranges (use min, max, step, unit, default — all numeric).
  * "button_group" for single-choice from 2-6 options (use options list of strings and a default string).
  * "number_stepper" for integer counts 1-20 (use min=1, max=20, step=1, default integer).
  * "size_picker" for preset size labels like "Small 100g", "Medium 250ml", "Large 400g" (use options list and default string).
  * "yes_no" for binary questions (use default=true or default=false; do not include options).
  * "free_text" as a fallback only when no structured option fits (use default string).
- Always provide a sensible default so the user can skip.
- If a user rule already answers the question, STILL include the question but set "skipped_by_rule" to the exact text of the rule that answered it.
- Be concise — if the foods are common and high-confidence, return a short or empty questions array.
- Question JSON shape (use null for unused fields):
  {
    "id": "q1",
    "food_index": 0,
    "question": "How were the eggs cooked?",
    "component_type": "button_group",
    "options": ["Scrambled", "Fried", "Boiled", "Poached"],
    "default": "Scrambled",
    "skipped_by_rule": null,
    "min": null,
    "max": null,
    "step": null,
    "unit": null
  }

ON_ANSWER CONTRACT (only when mode = guided):
For every question you emit, include an "on_answer" map in the question object. The map tells the client exactly how to update the meal when the user picks each possible answer. The client applies your recipes instantly — no second AI call is made. Your recipes must be realistic and conservative.

Four operations are supported:
1. add_food — Add a new food line to the meal.
   Example: user said "yes" to "Did you use oil to cook?"
   { "op": "add_food", "food": { "food_name": "cooking oil", "portion_amount": 1, "portion_unit": "tsp", "calories": 45, "protein_g": 0, "carbs_g": 0, "fat_g": 5 } }
2. scale_food — Multiply one existing food's numbers by a factor.
   Example: user picked "Large" on a portion-size question
   { "op": "scale_food", "factor": 1.5 }
   Factor must be between 0.1 and 10.0.
3. replace_food — Swap an existing food for a different one (used for cooking-method changes like grilled → fried).
   Example: user picked "Fried" on "How was it cooked?"
   { "op": "replace_food", "food": { "food_name": "fried chicken breast", "portion_amount": 100, "portion_unit": "g", "calories": 250, "protein_g": 28, "carbs_g": 8, "fat_g": 12 } }
4. no_op — Answer doesn't change nutrition.
   Example: user said "no" to "Did you use oil?"
   { "op": "no_op" }
5. needs_followup — Answer is ambiguous or open-ended; a second AI round is needed.
   Example: user said "yes" to "Did you use oil or butter?" — we still don't know which.
   { "op": "needs_followup", "reason": "was it oil or butter?" }
   Use sparingly. Prefer concrete add_food/scale_food/replace_food recipes when possible.
   Always emit needs_followup for free_text questions.

Which answer keys to emit per question type:
- yes_no → emit "yes" and "no"
- button_group → emit one key per option (use the exact option value)
- slider, number_stepper, size_picker → emit one key per representative value (min, default, max) — the client interpolates between them via scale_food
- free_text → emit a single "default" key with {"op": "needs_followup", "reason": "..."}. The client will collect the typed answer and POST to /meals/refine for a second AI round.

Rules:
- Keep the on_answer map small — at most 10 keys per question.
- Keys must be 50 characters or less.
- Nutrition estimates inside add_food / replace_food must be realistic and conservative. Never optimistic, never punitive. A teaspoon of cooking oil is ~40-50 kcal, not 200 or 10.
- Always include on_answer when mode = guided. Omit it entirely when mode = quick or manual.

APPLIED RULES:
For each food, list in "applied_rules" which of the user's personal rules (provided below if any) you used while estimating it. Quote the rule text exactly as given. If no rules applied to this specific food, return an empty array [].\
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
   - "applied_rules": array of strings (which user rules you used while estimating this food — see APPLIED RULES below)
3. For nutrition labels: read exact values. Set confidence to 0.95.
4. For food plates: estimate portions visually. Use 0.5-0.8 confidence.
5. Separate compound items into individual food entries.
6. Return between 1 and 50 food items.
7. No text outside the JSON object. No markdown fences. No explanation.
8. Only use quantities you can actually see in the image. If you see one piece of toast, report 1 — do not assume multiples. Count what is visible, nothing more.

GUIDED MODE QUESTIONS:
If the user has Guided mode enabled (indicated by "GUIDED MODE" in the user message), after the foods array also return a "questions" array with follow-up questions that would improve accuracy. Otherwise, omit the questions array or return it empty.

Rules for questions:
- Only ask questions that would meaningfully change the calorie or macro count by at least 10%.
- Each question must have a unique id (q1, q2, q3, ...).
- Each question references a food by its food_index (0-based into the foods array).
- Pick the best component_type for the question:
  * "slider" for continuous numeric ranges (use min, max, step, unit, default — all numeric).
  * "button_group" for single-choice from 2-6 options (use options list of strings and a default string).
  * "number_stepper" for integer counts 1-20 (use min=1, max=20, step=1, default integer).
  * "size_picker" for preset size labels like "Small 100g", "Medium 250ml", "Large 400g" (use options list and default string).
  * "yes_no" for binary questions (use default=true or default=false; do not include options).
  * "free_text" as a fallback only when no structured option fits (use default string).
- Always provide a sensible default so the user can skip.
- If a user rule already answers the question, STILL include the question but set "skipped_by_rule" to the exact text of the rule that answered it.
- Be concise — if the foods are common and high-confidence, return a short or empty questions array.
- Question JSON shape (use null for unused fields):
  {
    "id": "q1",
    "food_index": 0,
    "question": "How were the eggs cooked?",
    "component_type": "button_group",
    "options": ["Scrambled", "Fried", "Boiled", "Poached"],
    "default": "Scrambled",
    "skipped_by_rule": null,
    "min": null,
    "max": null,
    "step": null,
    "unit": null
  }

ON_ANSWER CONTRACT (only when mode = guided):
For every question you emit, include an "on_answer" map in the question object. The map tells the client exactly how to update the meal when the user picks each possible answer. The client applies your recipes instantly — no second AI call is made. Your recipes must be realistic and conservative.

Four operations are supported:
1. add_food — Add a new food line to the meal.
   Example: user said "yes" to "Did you use oil to cook?"
   { "op": "add_food", "food": { "food_name": "cooking oil", "portion_amount": 1, "portion_unit": "tsp", "calories": 45, "protein_g": 0, "carbs_g": 0, "fat_g": 5 } }
2. scale_food — Multiply one existing food's numbers by a factor.
   Example: user picked "Large" on a portion-size question
   { "op": "scale_food", "factor": 1.5 }
   Factor must be between 0.1 and 10.0.
3. replace_food — Swap an existing food for a different one (used for cooking-method changes like grilled → fried).
   Example: user picked "Fried" on "How was it cooked?"
   { "op": "replace_food", "food": { "food_name": "fried chicken breast", "portion_amount": 100, "portion_unit": "g", "calories": 250, "protein_g": 28, "carbs_g": 8, "fat_g": 12 } }
4. no_op — Answer doesn't change nutrition.
   Example: user said "no" to "Did you use oil?"
   { "op": "no_op" }
5. needs_followup — Answer is ambiguous or open-ended; a second AI round is needed.
   Example: user said "yes" to "Did you use oil or butter?" — we still don't know which.
   { "op": "needs_followup", "reason": "was it oil or butter?" }
   Use sparingly. Prefer concrete add_food/scale_food/replace_food recipes when possible.
   Always emit needs_followup for free_text questions.

Which answer keys to emit per question type:
- yes_no → emit "yes" and "no"
- button_group → emit one key per option (use the exact option value)
- slider, number_stepper, size_picker → emit one key per representative value (min, default, max) — the client interpolates between them via scale_food
- free_text → emit a single "default" key with {"op": "needs_followup", "reason": "..."}. The client will collect the typed answer and POST to /meals/refine for a second AI round.

Rules:
- Keep the on_answer map small — at most 10 keys per question.
- Keys must be 50 characters or less.
- Nutrition estimates inside add_food / replace_food must be realistic and conservative. Never optimistic, never punitive. A teaspoon of cooking oil is ~40-50 kcal, not 200 or 10.
- Always include on_answer when mode = guided. Omit it entirely when mode = quick or manual.

APPLIED RULES:
For each food, list in "applied_rules" which of the user's personal rules (provided below if any) you used while estimating it. Quote the rule text exactly as given. If no rules applied to this specific food, return an empty array [].\
"""

_MEAL_REFINE_SYSTEM_PROMPT = """\
You are refining an existing meal estimate.

You already parsed the meal once and asked the user some follow-up questions. Use their answers to either:
(a) return a refined `foods` list and `is_final: true`, OR
(b) ask one more round of follow-up questions and `is_final: false`.

Use the same JSON schema as /meals/parse: a top-level `foods` array, an optional `questions` array with the on_answer contract, plus an `is_final: bool` field.

ON_ANSWER CONTRACT (only when mode = guided):
For every question you emit, include an "on_answer" map in the question object. The map tells the client exactly how to update the meal when the user picks each possible answer. The client applies your recipes instantly — no second AI call is made. Your recipes must be realistic and conservative.

Four operations are supported:
1. add_food — Add a new food line to the meal.
   Example: user said "yes" to "Did you use oil to cook?"
   { "op": "add_food", "food": { "food_name": "cooking oil", "portion_amount": 1, "portion_unit": "tsp", "calories": 45, "protein_g": 0, "carbs_g": 0, "fat_g": 5 } }
2. scale_food — Multiply one existing food's numbers by a factor.
   Example: user picked "Large" on a portion-size question
   { "op": "scale_food", "factor": 1.5 }
   Factor must be between 0.1 and 10.0.
3. replace_food — Swap an existing food for a different one (used for cooking-method changes like grilled → fried).
   Example: user picked "Fried" on "How was it cooked?"
   { "op": "replace_food", "food": { "food_name": "fried chicken breast", "portion_amount": 100, "portion_unit": "g", "calories": 250, "protein_g": 28, "carbs_g": 8, "fat_g": 12 } }
4. no_op — Answer doesn't change nutrition.
   Example: user said "no" to "Did you use oil?"
   { "op": "no_op" }
5. needs_followup — Answer is ambiguous or open-ended; a second AI round is needed.
   Example: user said "yes" to "Did you use oil or butter?" — we still don't know which.
   { "op": "needs_followup", "reason": "was it oil or butter?" }
   Use sparingly. Prefer concrete add_food/scale_food/replace_food recipes when possible.
   Always emit needs_followup for free_text questions.

Which answer keys to emit per question type:
- yes_no → emit "yes" and "no"
- button_group → emit one key per option (use the exact option value)
- slider, number_stepper, size_picker → emit one key per representative value (min, default, max) — the client interpolates between them via scale_food
- free_text → emit a single "default" key with {"op": "needs_followup", "reason": "..."}. The client will collect the typed answer and POST to /meals/refine for a second AI round.

Rules:
- Keep the on_answer map small — at most 10 keys per question.
- Keys must be 50 characters or less.
- Nutrition estimates inside add_food / replace_food must be realistic and conservative. Never optimistic, never punitive. A teaspoon of cooking oil is ~40-50 kcal, not 200 or 10.
- Always include on_answer when mode = guided. Omit it entirely when mode = quick or manual.

REFINE RULES:

1. Round-3 hard stop. If the user message tells you this is round 3, you MUST return `is_final: true` with a best-effort refined `foods` list and an empty `questions` array. Do not ask more questions regardless of how ambiguous things feel.

2. Conservative numbers only. A teaspoon of cooking oil is ~40-50 kcal, not 200 or 10. A tablespoon of dressing is ~60-80 kcal.

3. Preserve attribution. For every food that the prior rounds already attributed (origin == "from_answer" with source_question_id and source_answer_value), preserve those fields as-is. Only set `origin: "from_answer"` on newly-added foods from THIS round — and tag them with the question id and answer value from this round's inputs.

4. No markdown, no explanation, no text outside the JSON object.
"""

router = APIRouter(prefix="/nutrition", tags=["nutrition"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _call_llm_with_json_retry(
    llm: LLMClient,
    messages: list[dict],
    temperature: float = 0.3,
    max_tokens: int = 2048,
) -> tuple[dict, str]:
    """Call the LLM with JSON mode and retry once on malformed JSON.

    Returns (parsed_dict, raw_content). Raises HTTPException on persistent
    failure.

    Defence in depth, four layers:

    1. ``response_format={"type": "json_object"}`` — JSON mode at the model
       layer so compliant models emit syntactically valid JSON.
    2. ``reasoning={"effort": "none"}`` — the OpenRouter-documented way to
       fully disable reasoning. Reasoning-capable models (e.g. Gemini 3.1
       Flash Lite, Kimi K2.5) can otherwise spend output tokens on hidden
       chain-of-thought and return an empty ``message.content``. Structured
       extraction doesn't need reasoning, so we turn it off.
    3. ``plugins=[{"id": "response-healing"}]`` — OpenRouter's free edge
       repair that fixes trailing commas, missing brackets, and stray
       markdown fences before the response leaves their servers.
    4. One retry with a stricter system nudge if JSON parsing still fails.
    """
    for attempt in range(2):
        try:
            response = await llm.chat(
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                response_format={"type": "json_object"},
                reasoning={"effort": "none"},
                plugins=[{"id": "response-healing"}],
            )
        except APIError as e:
            logger.error("LLM call failed (attempt %d): %s", attempt + 1, e)
            sentry_sdk.set_tag("ai.error_type", "meal_parse_llm_failure")
            sentry_sdk.capture_exception(e)
            if attempt == 0:
                continue  # Retry once
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="The AI service is temporarily unavailable. Please try again in a moment.",
            )

        raw_content = (response.choices[0].message.content or "").strip()

        # Strip markdown code fences as a safety net.
        if raw_content.startswith("```"):
            raw_content = raw_content.split("\n", 1)[-1] if "\n" in raw_content else raw_content
            raw_content = raw_content.rsplit("```", 1)[0].strip()

        try:
            parsed = json.loads(raw_content)
            return parsed, raw_content
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(
                "LLM returned malformed JSON on attempt %d: %s. Raw: %.500s",
                attempt + 1, e, raw_content,
            )
            if attempt == 0:
                logger.info("Retrying LLM call with stricter prompt nudge...")
                # On retry, add a system message nudge to reinforce JSON-only output
                messages = list(messages) + [
                    {
                        "role": "system",
                        "content": "Your previous response was not valid JSON. Return ONLY a valid JSON object. No markdown, no explanation, no text outside the JSON.",
                    }
                ]
                continue
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="The AI could not analyze your input. Please try rephrasing.",
            )
    # Unreachable, but for type checker
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail="The AI could not analyze your input.",
    )


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


async def _get_user_rules_prompt(db: AsyncSession, user_id: str) -> str:
    """Fetch user's nutrition rules and format as a prompt addendum."""
    result = await db.execute(
        select(NutritionRule.rule_text)
        .where(NutritionRule.user_id == user_id)
        .order_by(NutritionRule.created_at.asc())
    )
    rules = result.scalars().all()
    if not rules:
        return ""

    rules_block = "\n".join(f"- {r}" for r in rules)
    return (
        "\n\n--- User's personal nutrition rules (apply these to all estimates) ---\n"
        f"{rules_block}\n"
        "--- End of user rules ---"
    )


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
            origin=food_req.origin,
            source_question_id=food_req.source_question_id,
            source_answer_value=food_req.source_answer_value,
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
            origin=food_req.origin,
            source_question_id=food_req.source_question_id,
            source_answer_value=food_req.source_answer_value,
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
# Nutrition Rules CRUD (Phase 3D)
# ---------------------------------------------------------------------------

MAX_RULES_PER_USER = 20


@limiter.limit("60/minute")
@router.get("/rules")
async def list_rules(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List all nutrition rules for the authenticated user, oldest first."""
    result = await db.execute(
        select(NutritionRule)
        .where(NutritionRule.user_id == user_id)
        .order_by(NutritionRule.created_at.asc())
    )
    rules = result.scalars().all()

    return {
        "rules": [
            {
                "id": str(r.id),
                "rule_text": r.rule_text,
                "created_at": r.created_at.isoformat(),
                "updated_at": r.updated_at.isoformat(),
            }
            for r in rules
        ]
    }


@limiter.limit("20/minute")
@router.post("/rules", status_code=status.HTTP_201_CREATED)
async def create_rule(
    request: Request,
    body: NutritionRuleCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create a new nutrition rule. Each user may have up to 20 rules."""
    # Enforce per-user cap.
    count_result = await db.execute(
        select(func.count())
        .select_from(NutritionRule)
        .where(NutritionRule.user_id == user_id)
    )
    current_count = count_result.scalar() or 0

    if current_count >= MAX_RULES_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"You can have at most {MAX_RULES_PER_USER} nutrition rules. Delete one before adding another.",
        )

    clean_text = sanitize_for_llm(body.rule_text)
    if not clean_text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rule text could not be processed.",
        )

    rule = NutritionRule(
        user_id=user_id,
        rule_text=clean_text,
    )
    db.add(rule)
    await db.commit()
    await db.refresh(rule)

    return {
        "id": str(rule.id),
        "rule_text": rule.rule_text,
        "created_at": rule.created_at.isoformat(),
        "updated_at": rule.updated_at.isoformat(),
    }


@limiter.limit("20/minute")
@router.put("/rules/{rule_id}")
async def update_rule(
    request: Request,
    rule_id: uuid.UUID,
    body: NutritionRuleUpdate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Update the text of an existing nutrition rule."""
    result = await db.execute(
        select(NutritionRule).where(
            NutritionRule.id == rule_id,
            NutritionRule.user_id == user_id,
        )
    )
    rule = result.scalar_one_or_none()
    if not rule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nutrition rule not found.",
        )

    clean_text = sanitize_for_llm(body.rule_text)
    if not clean_text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rule text could not be processed.",
        )

    rule.rule_text = clean_text
    await db.commit()
    await db.refresh(rule)

    return {
        "id": str(rule.id),
        "rule_text": rule.rule_text,
        "created_at": rule.created_at.isoformat(),
        "updated_at": rule.updated_at.isoformat(),
    }


@limiter.limit("20/minute")
@router.delete("/rules/{rule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_rule(
    request: Request,
    rule_id: uuid.UUID,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Hard-delete a nutrition rule."""
    result = await db.execute(
        select(NutritionRule).where(
            NutritionRule.id == rule_id,
            NutritionRule.user_id == user_id,
        )
    )
    rule = result.scalar_one_or_none()
    if not rule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nutrition rule not found.",
        )

    await db.delete(rule)
    await db.commit()


# ---------------------------------------------------------------------------
# AI Meal Parse (Phase 2C)
# ---------------------------------------------------------------------------


@limiter.limit("10/minute")
@router.post("/meals/parse", response_model=MealParseResponse)
async def parse_meal_description(
    request: Request,
    body: MealParseRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
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

    # Inject user's personal nutrition rules into the system prompt.
    rules_addendum = await _get_user_rules_prompt(db, user_id)
    system_prompt = _MEAL_PARSE_SYSTEM_PROMPT + rules_addendum

    # Suffix the user message in Guided mode so the model branches on it.
    user_message = description
    if body.mode == "guided":
        user_message = (
            f"{description}\n\n"
            "(GUIDED MODE — generate follow-up questions to improve accuracy)"
        )

    # Build LLM client for the insight model (cheaper, faster).
    llm = LLMClient(model=settings.openrouter_insight_model)

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]

    # JSON mode + one retry on malformed output. The helper handles API errors,
    # markdown fences, and the retry-with-nudge flow.
    parsed, raw_content = await _call_llm_with_json_retry(
        llm,
        messages,
        temperature=0.3,
        max_tokens=2048,
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

    foods_out = validated_foods[:50]

    # Validate optional questions array (best-effort).
    validated_questions: list[GuidedQuestion] = []
    raw_questions = parsed.get("questions")
    if isinstance(raw_questions, list):
        for i, raw_q in enumerate(raw_questions):
            try:
                q = GuidedQuestion.model_validate(raw_q)
            except Exception as e:
                logger.warning(
                    "Meal parse: skipping invalid question at index %d — %s", i, e
                )
                continue
            if q.food_index >= len(foods_out):
                logger.warning(
                    "Meal parse: dropping question %s — food_index %d out of range",
                    q.id, q.food_index,
                )
                continue
            validated_questions.append(q)

    suggested = await detect_suggested_rule(db, user_id)

    return MealParseResponse(
        foods=foods_out,
        questions=validated_questions,
        suggested_rule=suggested,
    )


# ---------------------------------------------------------------------------
# AI Meal Refine (Phase 6 Plan 3)
# ---------------------------------------------------------------------------


@limiter.limit("10/minute")
@router.post("/meals/refine", response_model=MealRefineResponse)
async def refine_meal(
    request: Request,
    body: MealRefineRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> MealRefineResponse:
    """Run a second-round refinement over an existing meal parse.

    Called by the walkthrough when an answer is open-ended (free text) or
    the first round's recipes couldn't resolve it deterministically. Feeds
    the original description plus the full question-and-answer history
    back to the model, which returns either a refined food list or one
    more round of questions.

    Hard-capped at 3 refine rounds per meal — enforced server-side so a
    malicious client cannot force unbounded AI spend.
    """
    # Server-side hard cap — client enforces this too but we never trust it.
    if body.round > 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum refinement rounds exceeded.",
        )

    # Build the LLM user message. Sanitize every string that might echo
    # user input back into the prompt.
    sanitized_description = sanitize_for_llm(body.description)

    # Build a recap of the Q&A history — each entry tagged by its round.
    history_lines: list[str] = []
    questions_by_id = {q.id: q for q in body.questions_history}
    for entry in body.answers_history:
        q = questions_by_id.get(entry.question_id)
        q_text = sanitize_for_llm(q.question) if q else "(question not found)"
        a_text = sanitize_for_llm(entry.answer_value)
        history_lines.append(
            f"  • Round {entry.round}: Q: {q_text}  →  A: {a_text}"
        )
    history_block = "\n".join(history_lines) if history_lines else "  (no prior answers)"

    foods_json = json.dumps([f.model_dump() for f in body.foods], indent=2)

    # Inject user rules (same helper as parse_meal_description uses).
    rules_block = await _get_user_rules_prompt(db, user_id)

    round_marker = ""
    if body.round == 3:
        round_marker = (
            "THIS IS THE FINAL ROUND. Return is_final=true and empty questions. "
            "Best-effort foods only.\n\n"
        )

    user_message = (
        f"{round_marker}"
        f"Original description: {sanitized_description}\n\n"
        f"Current foods:\n{foods_json}\n\n"
        f"Question and answer history:\n{history_block}\n\n"
        f"This is refinement round {body.round} of 3.\n\n"
        f"{rules_block}"
    )

    messages = [
        {"role": "system", "content": _MEAL_REFINE_SYSTEM_PROMPT},
        {"role": "user", "content": user_message},
    ]

    # Run through the retry wrapper, same as parse.
    llm = LLMClient(model=settings.openrouter_insight_model)
    try:
        parsed_dict, raw_content = await _call_llm_with_json_retry(
            llm,
            messages,
            temperature=0.3,
            max_tokens=2048,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("refine_meal LLM call failed")
        sentry_sdk.capture_exception(e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Meal refinement service is temporarily unavailable.",
        ) from e

    # Validate response structure — tolerate missing fields.
    foods_list = parsed_dict.get("foods") or []
    if not isinstance(foods_list, list):
        foods_list = []
    refined_foods: list[ParsedFoodItem] = []
    for f in foods_list:
        if not isinstance(f, dict):
            continue
        try:
            refined_foods.append(ParsedFoodItem.model_validate(f))
        except ValidationError:
            logger.warning("refine_meal: skipping invalid food: %r", f)
            continue

    # Defence: if the LLM returned no valid foods, fall back to the input foods
    # so the walkthrough can keep going rather than crash the user's session.
    if not refined_foods:
        logger.warning(
            "refine_meal: LLM returned no valid foods, falling back to input. Raw: %.300s",
            raw_content,
        )
        refined_foods = list(body.foods)

    questions_list = parsed_dict.get("questions") or []
    if not isinstance(questions_list, list):
        questions_list = []
    refined_questions: list[GuidedQuestion] = []
    for q in questions_list:
        if not isinstance(q, dict):
            continue
        try:
            gq = GuidedQuestion.model_validate(q)
        except ValidationError:
            logger.warning("refine_meal: skipping invalid question: %r", q)
            continue
        # Drop questions with out-of-range food_index.
        if gq.food_index < 0 or gq.food_index >= len(refined_foods):
            logger.warning(
                "refine_meal: dropping question with out-of-range food_index: %d",
                gq.food_index,
            )
            continue
        refined_questions.append(gq)

    is_final_raw = parsed_dict.get("is_final", False)
    is_final = bool(is_final_raw) if is_final_raw is not None else False

    # Server-side override — round 3 forces is_final=true, empty questions.
    # Last line of defence against runaway rounds.
    if body.round >= 3:
        is_final = True
        refined_questions = []

    rounds_remaining = max(0, 3 - body.round)

    suggested = await detect_suggested_rule(db, user_id)

    return MealRefineResponse(
        foods=refined_foods,
        questions=refined_questions,
        is_final=is_final,
        rounds_remaining=rounds_remaining,
        suggested_rule=suggested,
    )


# ---------------------------------------------------------------------------
# AI Image Scan (Phase 3C)
# ---------------------------------------------------------------------------


@limiter.limit("10/minute")
@router.post("/meals/scan-image", response_model=MealParseResponse)
async def scan_food_image(
    request: Request,
    file: UploadFile,
    mode: Literal["quick", "guided"] = Form(default="quick"),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
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

    # Inject user's personal nutrition rules into the system prompt.
    rules_addendum = await _get_user_rules_prompt(db, user_id)
    system_prompt = _IMAGE_SCAN_SYSTEM_PROMPT + rules_addendum

    # Suffix the user message in Guided mode so the model branches on it.
    user_text = "Analyze this food image and extract nutritional information."
    if mode == "guided":
        user_text = (
            f"{user_text}\n\n"
            "(GUIDED MODE — generate follow-up questions to improve accuracy)"
        )

    # Build vision message
    llm = LLMClient(model=settings.openrouter_vision_model)
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": [
            {"type": "text", "text": user_text},
            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{b64_image}"}},
        ]},
    ]

    # JSON mode + one retry on malformed output. The helper handles API errors,
    # markdown fences, and the retry-with-nudge flow.
    parsed, raw_content = await _call_llm_with_json_retry(
        llm,
        messages,
        temperature=0.3,
        max_tokens=2048,
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

    foods_out = validated_foods[:50]

    # Validate optional questions array (best-effort).
    validated_questions: list[GuidedQuestion] = []
    raw_questions = parsed.get("questions")
    if isinstance(raw_questions, list):
        for i, raw_q in enumerate(raw_questions):
            try:
                q = GuidedQuestion.model_validate(raw_q)
            except Exception as e:
                logger.warning(
                    "Image scan: skipping invalid question at index %d — %s", i, e
                )
                continue
            if q.food_index >= len(foods_out):
                logger.warning(
                    "Image scan: dropping question %s — food_index %d out of range",
                    q.id, q.food_index,
                )
                continue
            validated_questions.append(q)

    suggested = await detect_suggested_rule(db, user_id)

    return MealParseResponse(
        foods=foods_out,
        questions=validated_questions,
        suggested_rule=suggested,
    )


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
