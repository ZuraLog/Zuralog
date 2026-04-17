"""
Zuralog Cloud Brain — Nutrition Pydantic Schemas.

Request schemas for the Nutrition Meal CRUD API.  Field names use
snake_case to match the Flutter client contract.

Schemas:
    - FoodItemRequest: Single food item within a meal.
    - MealCreateRequest: Payload for creating a new meal.
    - MealUpdateRequest: Payload for replacing an existing meal.
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, field_validator

VALID_MEAL_TYPES: set[str] = {"breakfast", "lunch", "dinner", "snack"}


# ---------------------------------------------------------------------------
# Food item schema
# ---------------------------------------------------------------------------


class FoodItemRequest(BaseModel):
    """Single food item within a meal.

    Attributes:
        food_name: Display name of the food (1-200 characters).
        portion_amount: Numeric portion size (must be > 0).
        portion_unit: Unit label for the portion (1-20 characters).
        calories: Total calories for this portion (>= 0).
        protein_g: Protein in grams (>= 0).
        carbs_g: Carbohydrates in grams (>= 0).
        fat_g: Fat in grams (>= 0).
    """

    food_name: str = Field(..., min_length=1, max_length=200)
    portion_amount: float = Field(..., gt=0)
    portion_unit: str = Field(..., min_length=1, max_length=20)
    calories: float = Field(..., ge=0)
    protein_g: float = Field(..., ge=0)
    carbs_g: float = Field(..., ge=0)
    fat_g: float = Field(..., ge=0)


# ---------------------------------------------------------------------------
# Meal request schemas
# ---------------------------------------------------------------------------


class MealCreateRequest(BaseModel):
    """Payload for creating a new meal.

    Attributes:
        meal_type: One of breakfast, lunch, dinner, snack (case-insensitive).
        name: Optional display name for the meal (max 200 characters).
        logged_at: Timestamp when the meal was eaten.
        foods: List of food items (1-50 items).
    """

    meal_type: str
    name: str | None = Field(default=None, max_length=200)
    logged_at: datetime
    foods: list[FoodItemRequest] = Field(..., min_length=1, max_length=50)

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: str) -> str:
        v = v.strip().lower()
        if v not in VALID_MEAL_TYPES:
            msg = f"meal_type must be one of {sorted(VALID_MEAL_TYPES)}"
            raise ValueError(msg)
        return v


class MealUpdateRequest(BaseModel):
    """Payload for replacing an existing meal.

    Same shape as MealCreateRequest — full replacement, not partial update.

    Attributes:
        meal_type: One of breakfast, lunch, dinner, snack (case-insensitive).
        name: Optional display name for the meal (max 200 characters).
        logged_at: Timestamp when the meal was eaten.
        foods: List of food items (1-50 items).
    """

    meal_type: str
    name: str | None = Field(default=None, max_length=200)
    logged_at: datetime
    foods: list[FoodItemRequest] = Field(..., min_length=1, max_length=50)

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: str) -> str:
        v = v.strip().lower()
        if v not in VALID_MEAL_TYPES:
            msg = f"meal_type must be one of {sorted(VALID_MEAL_TYPES)}"
            raise ValueError(msg)
        return v


# ---------------------------------------------------------------------------
# AI Meal Parse schemas (Phase 2C)
# ---------------------------------------------------------------------------


class MealParseRequest(BaseModel):
    """Request body for AI-powered meal parsing."""

    description: str = Field(..., min_length=1, max_length=500)
    mode: Literal["quick", "guided"] = "quick"

    @field_validator("description")
    @classmethod
    def strip_and_validate(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("description must not be empty")
        return v


class ParsedFoodItem(BaseModel):
    """A single food item returned by the AI meal parser.

    Uses defensive clamping rather than strict rejection since
    we are validating LLM output, not user input.
    """

    food_name: str
    portion_amount: float
    portion_unit: str
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    confidence: float = Field(default=0.5, ge=0.0, le=1.0)
    applied_rules: list[str] = Field(default_factory=list)
    origin: Literal["user", "from_answer"] = "user"
    source_question_id: str | None = None
    source_answer_value: str | None = None

    @field_validator("food_name")
    @classmethod
    def truncate_food_name(cls, v: str) -> str:
        return v.strip()[:200]

    @field_validator("portion_unit")
    @classmethod
    def truncate_portion_unit(cls, v: str) -> str:
        return v.strip()[:20]

    @field_validator("portion_amount")
    @classmethod
    def clamp_portion_amount(cls, v: float) -> float:
        return max(0.01, min(9999.0, v))

    @field_validator("calories")
    @classmethod
    def clamp_calories(cls, v: float) -> float:
        return max(0.0, min(9999.0, round(v, 1)))

    @field_validator("protein_g", "carbs_g", "fat_g")
    @classmethod
    def clamp_macros(cls, v: float) -> float:
        return max(0.0, min(999.0, round(v, 1)))

    @field_validator("confidence")
    @classmethod
    def clamp_confidence(cls, v: float) -> float:
        return max(0.0, min(1.0, round(v, 2)))

    @field_validator("source_question_id", "source_answer_value")
    @classmethod
    def truncate_source_fields(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v[:50] if v else None


class OnAnswerFood(BaseModel):
    """A lightweight food payload embedded inside an `add_food` or
    `replace_food` op.

    Mirrors `ParsedFoodItem` but only carries the fields needed to
    reconstruct a food line. Reuses the same clamping validators so
    untrusted LLM values cannot exceed sane bounds.
    """

    food_name: str
    portion_amount: float
    portion_unit: str
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float

    @field_validator("food_name")
    @classmethod
    def truncate_food_name(cls, v: str) -> str:
        return v.strip()[:200]

    @field_validator("portion_unit")
    @classmethod
    def truncate_portion_unit(cls, v: str) -> str:
        return v.strip()[:20]

    @field_validator("portion_amount")
    @classmethod
    def clamp_portion_amount(cls, v: float) -> float:
        return max(0.01, min(9999.0, v))

    @field_validator("calories")
    @classmethod
    def clamp_calories(cls, v: float) -> float:
        return max(0.0, min(9999.0, round(v, 1)))

    @field_validator("protein_g", "carbs_g", "fat_g")
    @classmethod
    def clamp_macros(cls, v: float) -> float:
        return max(0.0, min(999.0, round(v, 1)))


class AddFoodOp(BaseModel):
    """Append a new food line to the working meal."""

    op: Literal["add_food"]
    food: OnAnswerFood


class ScaleFoodOp(BaseModel):
    """Multiply the calories, macros, and portion of the question's target
    food by a scalar factor.
    """

    op: Literal["scale_food"]
    factor: float

    @field_validator("factor")
    @classmethod
    def clamp_factor(cls, v: float) -> float:
        return max(0.1, min(10.0, v))


class ReplaceFoodOp(BaseModel):
    """Replace the question's target food with a new one (e.g. swap raw
    oats for cooked oatmeal)."""

    op: Literal["replace_food"]
    food: OnAnswerFood


class NoOp(BaseModel):
    """Do nothing — use when an answer value does not change the meal."""

    op: Literal["no_op"]


OnAnswerOp = Annotated[
    Union[AddFoodOp, ScaleFoodOp, ReplaceFoodOp, NoOp],
    Field(discriminator="op"),
]


class GuidedQuestion(BaseModel):
    """A single follow-up question the AI asks during Guided mode.

    The `default` field is typed as `Any` because valid values differ per
    component_type (int/float for slider and number_stepper, str for
    button_group, size_picker, and free_text, bool for yes_no).
    """
    id: str = Field(..., min_length=1, max_length=20)
    food_index: int = Field(..., ge=0)
    question: str = Field(..., min_length=1, max_length=200)
    component_type: str
    options: list[str] | None = None
    default: Any = None
    skipped_by_rule: str | None = None
    min: float | None = None
    max: float | None = None
    step: float | None = None
    unit: str | None = None
    on_answer: dict[str, OnAnswerOp] | None = None

    @field_validator("component_type")
    @classmethod
    def validate_component_type(cls, v: str) -> str:
        allowed = {
            "slider",
            "button_group",
            "number_stepper",
            "size_picker",
            "yes_no",
            "free_text",
        }
        if v not in allowed:
            raise ValueError(f"component_type must be one of {sorted(allowed)}")
        return v

    @field_validator("question")
    @classmethod
    def strip_question(cls, v: str) -> str:
        return v.strip()[:200]

    @field_validator("skipped_by_rule")
    @classmethod
    def strip_skipped_by_rule(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v[:500] if v else None

    @field_validator("on_answer")
    @classmethod
    def validate_on_answer(
        cls, v: dict[str, OnAnswerOp] | None
    ) -> dict[str, OnAnswerOp] | None:
        if v is None:
            return None
        if len(v) > 10:
            raise ValueError("on_answer map must contain at most 10 entries")
        for key in v:
            if len(key) > 50:
                raise ValueError(
                    "on_answer keys must be at most 50 characters long"
                )
        return v


class MealParseResponse(BaseModel):
    """Response from the AI meal parser."""

    foods: list[ParsedFoodItem]
    questions: list[GuidedQuestion] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Food Search schemas (Phase 2D)
# ---------------------------------------------------------------------------


class FoodSearchResult(BaseModel):
    """A single food item from the search cache or AI estimation."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    brand: str | None = None
    serving_size: float
    serving_unit: str
    calories_per_serving: float
    protein_per_serving: float
    carbs_per_serving: float
    fat_per_serving: float
    source: str = "cached"


class FoodSearchResponse(BaseModel):
    """Response from the food search endpoint."""

    foods: list[FoodSearchResult]


class CorrectionRequest(BaseModel):
    """Request body for submitting a food correction."""

    food_name: str = Field(..., min_length=1, max_length=200)
    original_calories: float = Field(..., ge=0)
    corrected_calories: float = Field(..., ge=0)
    original_protein_g: float = Field(..., ge=0)
    corrected_protein_g: float = Field(..., ge=0)
    original_carbs_g: float = Field(..., ge=0)
    corrected_carbs_g: float = Field(..., ge=0)
    original_fat_g: float = Field(..., ge=0)
    corrected_fat_g: float = Field(..., ge=0)

    @field_validator("food_name")
    @classmethod
    def strip_food_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("food_name must not be empty")
        return v


class BarcodeLookupResponse(BaseModel):
    """Response from the barcode lookup endpoint."""

    food: FoodSearchResult


# ---------------------------------------------------------------------------
# Nutrition Rules schemas (Phase 3D)
# ---------------------------------------------------------------------------


class NutritionRuleCreate(BaseModel):
    """Request body for creating a nutrition rule."""

    rule_text: str = Field(..., min_length=1, max_length=500)

    @field_validator("rule_text")
    @classmethod
    def strip_rule_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("rule_text must not be empty")
        return v


class NutritionRuleUpdate(BaseModel):
    """Request body for updating a nutrition rule."""

    rule_text: str = Field(..., min_length=1, max_length=500)

    @field_validator("rule_text")
    @classmethod
    def strip_rule_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("rule_text must not be empty")
        return v
