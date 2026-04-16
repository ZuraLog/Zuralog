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
