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


class MealParseResponse(BaseModel):
    """Response from the AI meal parser."""

    foods: list[ParsedFoodItem]


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
