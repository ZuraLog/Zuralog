"""
Unit tests for meal template endpoints and schemas.
"""

import pytest
from pydantic import ValidationError

from app.api.v1.template_schemas import MealTemplateCreate, MealTemplateResponse


class TestTemplateSchemas:
    """Unit tests for template schema validation."""

    def test_meal_template_create_validates_name_min_length(self):
        """Empty name should raise validation error."""
        with pytest.raises(ValidationError):
            MealTemplateCreate(name="", foods=[])

    def test_meal_template_create_validates_name_max_length(self):
        """Name longer than 200 chars should raise validation error."""
        long_name = "x" * 201
        with pytest.raises(ValidationError):
            MealTemplateCreate(name=long_name, foods=[])

    def test_meal_template_create_valid_minimal(self):
        """Minimal valid template with name only."""
        t = MealTemplateCreate(name="My Template")
        assert t.name == "My Template"
        assert t.foods == []

    def test_meal_template_create_valid_with_foods(self):
        """Valid template with food items."""
        foods = [
            {"food_name": "chicken breast", "calories": 165, "protein_g": 31},
            {"food_name": "rice", "calories": 130, "carbs_g": 28},
        ]
        t = MealTemplateCreate(name="Lunch", foods=foods)
        assert t.name == "Lunch"
        assert len(t.foods) == 2
        assert t.foods[0]["food_name"] == "chicken breast"

    def test_meal_template_response_from_orm_template(self):
        """Construct response from ORM template instance."""
        import json
        from datetime import datetime

        # Mock ORM template
        class MockTemplate:
            id = "tmpl-123"
            name = "My Lunch"
            foods_json = json.dumps([{"food_name": "chicken"}])
            created_at = datetime.now()

        tmpl = MockTemplate()
        response = MealTemplateResponse.from_orm_template(tmpl)
        assert response.id == "tmpl-123"
        assert response.name == "My Lunch"
        assert len(response.foods) == 1
        assert response.foods[0]["food_name"] == "chicken"

    def test_meal_template_response_from_orm_template_empty_foods(self):
        """Construct response when foods_json is None or empty."""
        from datetime import datetime

        class MockTemplate:
            id = "tmpl-456"
            name = "Empty Template"
            foods_json = None
            created_at = datetime.now()

        tmpl = MockTemplate()
        response = MealTemplateResponse.from_orm_template(tmpl)
        assert response.id == "tmpl-456"
        assert response.foods == []
