"""
Zuralog Cloud Brain — Meal Template Pydantic Schemas.

Request and response schemas for the Meal Template CRUD API.

Schemas:
    - MealTemplateCreate: Request payload for creating a meal template.
    - MealTemplateResponse: Response shape for a saved meal template.
"""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class MealTemplateCreate(BaseModel):
    """Request payload for creating a meal template.

    Attributes:
        name: Display name for the template (1-200 characters).
        foods: List of food items (can be empty). Each food is a dict that
               should contain at least food_name, calories, protein_g, carbs_g, fat_g.
    """

    name: str = Field(..., min_length=1, max_length=200)
    foods: list[dict[str, Any]] = Field(default_factory=list)


class MealTemplateResponse(BaseModel):
    """Response shape for a saved meal template.

    Attributes:
        id: Unique ID of the template.
        name: Display name of the template.
        foods: List of food items stored in the template.
        created_at: When the template was created.
    """

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    foods: list[dict[str, Any]]
    created_at: datetime

    @classmethod
    def from_orm_template(cls, tmpl: Any) -> MealTemplateResponse:
        """Convert a MealTemplate ORM instance to a response.

        Parses the foods_json string back into a list of dicts.
        """
        return cls(
            id=tmpl.id,
            name=tmpl.name,
            foods=json.loads(tmpl.foods_json) if tmpl.foods_json else [],
            created_at=tmpl.created_at,
        )
