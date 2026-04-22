"""Tests for nutrition API endpoints.

Covers:
  - _range_to_day_count unit tests (no HTTP)
  - GET /api/v1/nutrition/trend
  - GET /api/v1/nutrition/all-data
  - GET /api/v1/nutrition/today (AI summary integration)

Uses the per-file client_with_auth fixture pattern — no live DB or auth service
required. All external calls are replaced with AsyncMock.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "test-nutrition-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Shared fixture
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database — no real DB required."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_auth, mock_db

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Class 1: Pure unit tests — no HTTP
# ---------------------------------------------------------------------------


class TestNutritionServiceRangeValidation:
    def test_valid_ranges(self):
        from app.services.nutrition_service import _range_to_day_count

        assert _range_to_day_count("7d") == 7
        assert _range_to_day_count("30d") == 30
        assert _range_to_day_count("3m") == 90
        assert _range_to_day_count("6m") == 180
        assert _range_to_day_count("1y") == 365

    def test_invalid_range_raises(self):
        from app.services.nutrition_service import _range_to_day_count

        with pytest.raises(ValueError):
            _range_to_day_count("2y")
        with pytest.raises(ValueError):
            _range_to_day_count("")
        with pytest.raises(ValueError):
            _range_to_day_count("all")


# ---------------------------------------------------------------------------
# Class 2: GET /api/v1/nutrition/trend
# ---------------------------------------------------------------------------


class TestNutritionTrend:
    def test_trend_7d_returns_days(self, client_with_auth):
        client, mock_auth, mock_db = client_with_auth
        mock_data = [
            {"date": "2026-04-14", "calories": 1800.0, "protein_g": 72.0, "is_today": False},
            {"date": "2026-04-20", "calories": 1200.0, "protein_g": 48.0, "is_today": True},
        ]
        with patch("app.api.v1.nutrition_routes.get_nutrition_trend", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = mock_data
            resp = client.get("/api/v1/nutrition/trend?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        body = resp.json()
        assert body["range"] == "7d"
        assert len(body["days"]) == 2
        assert body["days"][0]["date"] == "2026-04-14"
        assert body["days"][0]["calories"] == 1800.0
        assert body["days"][0]["protein_g"] == 72.0
        assert body["days"][0]["is_today"] is False
        assert body["days"][1]["is_today"] is True

    def test_trend_30d_accepted(self, client_with_auth):
        client, _, _ = client_with_auth
        with patch("app.api.v1.nutrition_routes.get_nutrition_trend", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = []
            resp = client.get("/api/v1/nutrition/trend?range=30d", headers=AUTH_HEADER)
        assert resp.status_code == 200

    def test_trend_invalid_range_rejected(self, client_with_auth):
        client, _, _ = client_with_auth
        resp = client.get("/api/v1/nutrition/trend?range=3m", headers=AUTH_HEADER)
        assert resp.status_code == 422

    def test_trend_empty_data(self, client_with_auth):
        client, _, _ = client_with_auth
        with patch("app.api.v1.nutrition_routes.get_nutrition_trend", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = []
            resp = client.get("/api/v1/nutrition/trend", headers=AUTH_HEADER)
        assert resp.status_code == 200
        assert resp.json()["days"] == []

    def test_trend_null_values_allowed(self, client_with_auth):
        client, _, _ = client_with_auth
        mock_data = [{"date": "2026-04-14", "calories": None, "protein_g": None, "is_today": False}]
        with patch("app.api.v1.nutrition_routes.get_nutrition_trend", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = mock_data
            resp = client.get("/api/v1/nutrition/trend", headers=AUTH_HEADER)
        assert resp.status_code == 200
        day = resp.json()["days"][0]
        assert day["calories"] is None
        assert day["protein_g"] is None


# ---------------------------------------------------------------------------
# Class 3: GET /api/v1/nutrition/all-data
# ---------------------------------------------------------------------------


class TestNutritionAllData:
    def test_all_data_7d_returns_days(self, client_with_auth):
        client, _, _ = client_with_auth
        mock_data = [
            {
                "date": "2026-04-20",
                "is_today": True,
                "values": {"calories": 1240.0, "protein": 45.2, "carbs": 180.0, "fat": 38.1, "meals": 2.0},
            }
        ]
        with patch("app.api.v1.nutrition_routes.get_nutrition_all_data", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = mock_data
            resp = client.get("/api/v1/nutrition/all-data?range=7d", headers=AUTH_HEADER)
        assert resp.status_code == 200
        days = resp.json()["days"]
        assert len(days) == 1
        assert days[0]["date"] == "2026-04-20"
        assert days[0]["is_today"] is True
        v = days[0]["values"]
        assert v["calories"] == 1240.0
        assert v["protein"] == 45.2
        assert v["carbs"] == 180.0
        assert v["fat"] == 38.1
        assert v["meals"] == 2.0

    @pytest.mark.parametrize("range_val", ["30d", "3m", "6m", "1y"])
    def test_all_data_extended_ranges_accepted(self, client_with_auth, range_val):
        client, _, _ = client_with_auth
        with patch("app.api.v1.nutrition_routes.get_nutrition_all_data", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = []
            resp = client.get(f"/api/v1/nutrition/all-data?range={range_val}", headers=AUTH_HEADER)
        assert resp.status_code == 200

    def test_all_data_invalid_range_rejected(self, client_with_auth):
        client, _, _ = client_with_auth
        resp = client.get("/api/v1/nutrition/all-data?range=2y", headers=AUTH_HEADER)
        assert resp.status_code == 422

    def test_all_data_null_values_in_day(self, client_with_auth):
        client, _, _ = client_with_auth
        mock_data = [
            {
                "date": "2026-04-20",
                "is_today": True,
                "values": {"calories": 500.0, "protein": None, "carbs": None, "fat": None, "meals": 1.0},
            }
        ]
        with patch("app.api.v1.nutrition_routes.get_nutrition_all_data", new_callable=AsyncMock) as mock_svc:
            mock_svc.return_value = mock_data
            resp = client.get("/api/v1/nutrition/all-data", headers=AUTH_HEADER)
        assert resp.status_code == 200
        v = resp.json()["days"][0]["values"]
        assert v["protein"] is None
        assert v["carbs"] is None
        assert v["fat"] is None


# ---------------------------------------------------------------------------
# Class 4: GET /api/v1/nutrition/today — AI summary integration
# ---------------------------------------------------------------------------


class TestNutritionTodayAiSummary:
    def test_today_includes_ai_summary(self, client_with_auth):
        client, _, mock_db = client_with_auth

        # Mock DB to return empty meals list and a summary row.
        mock_summary_row = MagicMock()
        mock_summary_row.date = date(2026, 4, 20)
        mock_summary_row.total_calories = 1200.0
        mock_summary_row.total_protein_g = 50.0
        mock_summary_row.total_carbs_g = 150.0
        mock_summary_row.total_fat_g = 40.0
        mock_summary_row.meal_count = 2

        meals_result = MagicMock()
        meals_result.scalars.return_value.all.return_value = []

        summary_result = MagicMock()
        summary_result.scalar_one_or_none.return_value = mock_summary_row

        mock_db.execute = AsyncMock(side_effect=[meals_result, summary_result])

        with patch("app.api.v1.nutrition_routes.get_nutrition_ai_summary", new_callable=AsyncMock) as mock_ai:
            mock_ai.return_value = {"ai_summary": "Good job today!", "ai_generated_at": "2026-04-20T09:00:00Z"}
            resp = client.get("/api/v1/nutrition/today", headers=AUTH_HEADER)

        assert resp.status_code == 200
        summary = resp.json()["summary"]
        assert summary["ai_summary"] == "Good job today!"
        assert summary["ai_generated_at"] == "2026-04-20T09:00:00Z"

    def test_today_ai_summary_null_when_no_insight(self, client_with_auth):
        client, _, mock_db = client_with_auth

        meals_result = MagicMock()
        meals_result.scalars.return_value.all.return_value = []

        summary_result = MagicMock()
        summary_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(side_effect=[meals_result, summary_result])

        with patch("app.api.v1.nutrition_routes.get_nutrition_ai_summary", new_callable=AsyncMock) as mock_ai:
            mock_ai.return_value = {"ai_summary": None, "ai_generated_at": None}
            resp = client.get("/api/v1/nutrition/today", headers=AUTH_HEADER)

        assert resp.status_code == 200
        assert resp.json()["summary"] is None


# ---------------------------------------------------------------------------
# Class 5: MealFood model — new columns for nutrition tracking
# ---------------------------------------------------------------------------


class TestMealFoodNewColumns:
    def test_meal_food_model_has_fiber_sodium_sugar(self):
        from app.models.meal_food import MealFood
        import uuid
        food = MealFood(
            meal_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
            food_name="Apple", portion_amount=150.0, portion_unit="g",
            calories=78.0, protein_g=0.4, carbs_g=21.0, fat_g=0.2,
        )
        assert hasattr(food, "fiber_g")
        assert hasattr(food, "sodium_mg")
        assert hasattr(food, "sugar_g")


# ---------------------------------------------------------------------------
# Class 6: ExerciseEntry model — manual exercise calorie tracking
# ---------------------------------------------------------------------------


class TestExerciseEntryModel:
    def test_exercise_entry_model_fields(self):
        from app.models.exercise_entry import ExerciseEntry
        from datetime import date
        entry = ExerciseEntry(
            user_id="user-1", date=date.today(),
            activity_name="Morning run", calories_burned=350, source="manual",
        )
        assert entry.activity_name == "Morning run"
        assert entry.source == "manual"
        assert entry.session_id is None


# ---------------------------------------------------------------------------
# Class 7: MealTemplate model — saved sets of foods for quick re-logging
# ---------------------------------------------------------------------------


class TestMealTemplateModel:
    def test_meal_template_model_fields(self):
        import json
        from app.models.meal_template import MealTemplate
        t = MealTemplate(user_id="user-1", name="My breakfast",
                         foods_json=json.dumps([{"food_name": "Oats"}]))
        assert t.name == "My breakfast"
        assert json.loads(t.foods_json)[0]["food_name"] == "Oats"
