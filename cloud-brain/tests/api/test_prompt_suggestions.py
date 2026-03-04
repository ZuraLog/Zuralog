"""
Tests for the Prompt Suggestions endpoint.

Covers:
    - Returns 3–5 suggestions.
    - Morning time returns sleep-related suggestions.
    - Evening time returns workout-related suggestions.
    - No health data returns onboarding fallback suggestions.
    - Missing Authorization header returns 401.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

USER_ID = "user-suggestions-test"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


def _build_client(db: AsyncMock) -> TestClient:
    app.dependency_overrides[get_authenticated_user_id] = lambda: USER_ID
    app.dependency_overrides[get_db] = lambda: db
    return TestClient(app, raise_server_exceptions=False)


def _cleanup():
    app.dependency_overrides.pop(get_authenticated_user_id, None)
    app.dependency_overrides.pop(get_db, None)


def _make_db(has_data: bool = True, goal_metrics: list[str] | None = None) -> AsyncMock:
    """Build a mock DB that simulates health data presence and user goals.

    Args:
        has_data: Whether the user has health data in the last 7 days.
        goal_metrics: List of active goal metric names.

    Returns:
        AsyncMock database session.
    """
    db = AsyncMock()
    call_count = 0
    goal_metrics = goal_metrics or []

    async def _execute(stmt):
        nonlocal call_count
        call_count += 1
        result = MagicMock()
        if call_count == 1:
            # Health data check
            result.scalar_one_or_none.return_value = "fake-id" if has_data else None
        elif call_count == 2:
            # Goals query
            result.scalars.return_value.all.return_value = goal_metrics
        return result

    db.execute = _execute
    return db


# ---------------------------------------------------------------------------
# Test: Returns 3–5 suggestions
# ---------------------------------------------------------------------------


class TestSuggestionCount:
    def test_returns_between_3_and_5_suggestions_with_data(self):
        """With health data, endpoint must return 3–5 suggestions."""
        db = _make_db(has_data=True)
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        data = resp.json()
        assert 3 <= len(data) <= 5

    def test_returns_between_3_and_5_suggestions_without_data(self):
        """Without health data, onboarding fallbacks must number 3–5."""
        db = _make_db(has_data=False)
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        data = resp.json()
        assert 3 <= len(data) <= 5

    def test_suggestion_shape(self):
        """Each suggestion must have id, text, category, icon."""
        db = _make_db(has_data=True)
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        for item in resp.json():
            assert "id" in item
            assert "text" in item
            assert "category" in item
            assert "icon" in item
            assert len(item["text"]) > 5


# ---------------------------------------------------------------------------
# Test: Morning time returns sleep-related suggestions
# ---------------------------------------------------------------------------


class TestMorningTimeSuggestions:
    def test_morning_includes_sleep_suggestion(self):
        """hour=7 → time slot 'morning' → at least one sleep-category suggestion."""
        morning = datetime(2026, 1, 15, 7, 30, tzinfo=timezone.utc)

        db = _make_db(has_data=True)
        client = _build_client(db)
        try:
            with patch("app.api.v1.prompt_suggestions.datetime") as mock_dt:
                mock_dt.now.return_value = morning
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        categories = [s["category"] for s in resp.json()]
        assert "sleep" in categories, f"Expected 'sleep' in {categories}"

    def test_morning_text_mentions_sleep_or_energy(self):
        """Morning suggestions should reference sleep or energy themes."""
        morning = datetime(2026, 1, 15, 8, 0, tzinfo=timezone.utc)

        db = _make_db(has_data=True)
        client = _build_client(db)
        try:
            with patch("app.api.v1.prompt_suggestions.datetime") as mock_dt:
                mock_dt.now.return_value = morning
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        texts = " ".join(s["text"].lower() for s in resp.json())
        assert any(kw in texts for kw in ("sleep", "energy", "morning", "heart"))


# ---------------------------------------------------------------------------
# Test: Evening time returns workout-related suggestions
# ---------------------------------------------------------------------------


class TestEveningTimeSuggestions:
    def test_evening_includes_activity_suggestion(self):
        """hour=19 → time slot 'evening' → at least one activity-category suggestion."""
        evening = datetime(2026, 1, 15, 19, 0, tzinfo=timezone.utc)

        db = _make_db(has_data=True)
        client = _build_client(db)
        try:
            with patch("app.api.v1.prompt_suggestions.datetime") as mock_dt:
                mock_dt.now.return_value = evening
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        categories = [s["category"] for s in resp.json()]
        assert "activity" in categories, f"Expected 'activity' in {categories}"

    def test_evening_text_mentions_workout_or_stress(self):
        """Evening suggestions should reference workout or stress themes."""
        evening = datetime(2026, 1, 15, 20, 0, tzinfo=timezone.utc)

        db = _make_db(has_data=True)
        client = _build_client(db)
        try:
            with patch("app.api.v1.prompt_suggestions.datetime") as mock_dt:
                mock_dt.now.return_value = evening
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        texts = " ".join(s["text"].lower() for s in resp.json())
        assert any(kw in texts for kw in ("workout", "stress", "sleep", "calorie"))


# ---------------------------------------------------------------------------
# Test: No data returns fallback suggestions
# ---------------------------------------------------------------------------


class TestNoDataFallbacks:
    def test_no_data_returns_onboarding_suggestions(self):
        """When the user has no health data, onboarding-category suggestions appear."""
        db = _make_db(has_data=False)
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        categories = [s["category"] for s in resp.json()]
        assert "onboarding" in categories, f"Expected 'onboarding' in {categories}"

    def test_no_data_suggestions_mention_getting_started(self):
        """Onboarding suggestions should reference setup or getting started."""
        db = _make_db(has_data=False)
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/prompts/suggestions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        texts = " ".join(s["text"].lower() for s in resp.json())
        assert any(kw in texts for kw in ("started", "connect", "track", "goal", "zuralog", "insight"))


# ---------------------------------------------------------------------------
# Test: Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_missing_auth_returns_401(self):
        """GET /prompts/suggestions without Authorization header returns 401."""
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.get("/api/v1/prompts/suggestions")
        assert resp.status_code == 401
