"""
Zuralog Cloud Brain — Exercise Entry Pydantic Schemas.

Request and response models for the exercise calorie endpoints.
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class ExerciseEntryCreate(BaseModel):
    """Body accepted by POST /api/v1/nutrition/exercise."""

    activity: str = Field(..., min_length=1, max_length=200)
    duration_minutes: int = Field(default=0, ge=0)
    calories_burned: int = Field(..., gt=0, le=10000)


class ExerciseEntryResponse(BaseModel):
    """Shape returned by all exercise endpoints."""

    id: str
    activity: str
    duration_minutes: int
    calories_burned: int
    logged_at: datetime

    model_config = {"from_attributes": True}
