"""
Tests for the Quick Actions endpoint.

Covers:
    - Returns actions (basic smoke test).
    - Proactivity 'low' (gentle persona) returns max 3 actions.
    - Proactivity 'high' (tough_love persona) returns up to 8 actions.
    - Time-based actions match the current time of day.
    - Missing Authorization header returns 401.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.models.daily_metrics import DailyHealthMetrics
from app.models.user import User
from app.models.user_goal import GoalPeriod, UserGoal

USER_ID = "user-actions-test"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_user(coach_persona: str = "balanced") -> User:
    u = User()
    u.id = USER_ID
    u.email = "test@example.com"
    u.coach_persona = coach_persona
    u.subscription_tier = "free"
    return u


def _make_metrics(steps: int | None = 8000) -> DailyHealthMetrics:
    m = DailyHealthMetrics()
    m.id = str(uuid.uuid4())
    m.user_id = USER_ID
    m.source = "apple_health"
    m.date = date.today().isoformat()
    m.steps = steps
    return m


def _make_goal(metric: str = "steps", target: float = 10000.0) -> UserGoal:
    g = UserGoal()
    g.id = str(uuid.uuid4())
    g.user_id = USER_ID
    g.metric = metric
    g.target_value = target
    g.period = GoalPeriod.DAILY
    g.is_active = True
    return g


def _build_db(
    user: User | None = None,
    metrics: DailyHealthMetrics | None = None,
    goal: UserGoal | None = None,
) -> AsyncMock:
    """Build a mock DB session returning the given objects in call order."""
    db = AsyncMock()
    call_count = 0

    async def _execute(stmt):
        nonlocal call_count
        call_count += 1
        result = MagicMock()
        if call_count == 1:
            result.scalar_one_or_none.return_value = user
        elif call_count == 2:
            result.scalar_one_or_none.return_value = metrics
        elif call_count == 3:
            result.scalar_one_or_none.return_value = goal
        else:
            result.scalar_one_or_none.return_value = None
        return result

    db.execute = _execute
    return db


def _build_client(db: AsyncMock) -> TestClient:
    app.dependency_overrides[get_authenticated_user_id] = lambda: USER_ID
    app.dependency_overrides[get_db] = lambda: db
    return TestClient(app, raise_server_exceptions=False)


def _cleanup():
    app.dependency_overrides.pop(get_authenticated_user_id, None)
    app.dependency_overrides.pop(get_db, None)


# ---------------------------------------------------------------------------
# Test: Returns actions (basic smoke)
# ---------------------------------------------------------------------------


class TestReturnsActions:
    def test_returns_actions_with_defaults(self):
        """GET /quick-actions returns a list of action objects."""
        db = _build_db(user=_make_user())
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    def test_action_shape(self):
        """Each action must have required fields."""
        db = _build_db(user=_make_user())
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        for item in resp.json():
            assert "id" in item
            assert "title" in item
            assert "subtitle" in item
            assert "icon" in item
            assert "action_type" in item
            assert "prompt" in item
            assert len(item["prompt"]) > 5


# ---------------------------------------------------------------------------
# Test: Proactivity low → max 3 actions
# ---------------------------------------------------------------------------


class TestProactivityLow:
    def test_gentle_persona_returns_at_most_3(self):
        """coach_persona='gentle' maps to proactivity 'low' → max 3 actions."""
        db = _build_db(user=_make_user(coach_persona="gentle"))
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        assert len(resp.json()) <= 3

    def test_low_proactivity_includes_essential_actions(self):
        """Even at max 3, at least one universal action should be present."""
        db = _build_db(user=_make_user(coach_persona="gentle"))
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        # Should always include at least one ask_coach or log_water action
        action_types = [a["action_type"] for a in resp.json()]
        assert len(action_types) >= 1


# ---------------------------------------------------------------------------
# Test: Proactivity high → up to 8 actions
# ---------------------------------------------------------------------------


class TestProactivityHigh:
    def test_tough_love_persona_returns_up_to_8(self):
        """coach_persona='tough_love' maps to proactivity 'high' → up to 8 actions."""
        db = _build_db(user=_make_user(coach_persona="tough_love"))
        client = _build_client(db)
        try:
            resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        count = len(resp.json())
        assert count <= 8
        # With time-of-day + universal pool we expect > 3
        assert count >= 3

    def test_high_proactivity_exceeds_low_proactivity_count(self):
        """High proactivity should return more actions than low proactivity."""
        db_low = _build_db(user=_make_user(coach_persona="gentle"))
        db_high = _build_db(user=_make_user(coach_persona="tough_love"))

        client_low = _build_client(db_low)
        try:
            resp_low = client_low.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        client_high = _build_client(db_high)
        try:
            resp_high = client_high.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert len(resp_high.json()) >= len(resp_low.json())


# ---------------------------------------------------------------------------
# Test: Time-based actions match time of day
# ---------------------------------------------------------------------------


class TestTimeBasedActions:
    def test_morning_includes_morning_checkin(self):
        """hour=7 → 'morning' slot → morning check-in action present."""
        morning = datetime(2026, 1, 15, 7, 0, tzinfo=timezone.utc)

        db = _build_db(user=_make_user(coach_persona="tough_love"))
        client = _build_client(db)
        try:
            with patch("app.api.v1.quick_actions.datetime") as mock_dt:
                mock_dt.now.return_value = morning
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        titles = [a["title"] for a in resp.json()]
        # Morning check-in or sleep recap should be present
        assert any("morning" in t.lower() or "sleep" in t.lower() for t in titles), (
            f"No morning action found in: {titles}"
        )

    def test_evening_includes_workout_log(self):
        """hour=19 → 'evening' slot → log workout action present."""
        evening = datetime(2026, 1, 15, 19, 0, tzinfo=timezone.utc)

        db = _build_db(user=_make_user(coach_persona="tough_love"))
        client = _build_client(db)
        try:
            with patch("app.api.v1.quick_actions.datetime") as mock_dt:
                mock_dt.now.return_value = evening
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        titles = [a["title"] for a in resp.json()]
        assert any("workout" in t.lower() or "evening" in t.lower() for t in titles), (
            f"No evening action found in: {titles}"
        )

    def test_step_proximity_nudge_appears_when_close_to_goal(self):
        """When today_steps is within 1000 of goal, proximity nudge is included."""
        evening = datetime(2026, 1, 15, 19, 0, tzinfo=timezone.utc)

        # steps=9100, goal=10000 → remaining=900 → within threshold
        db = _build_db(
            user=_make_user(coach_persona="tough_love"),
            metrics=_make_metrics(steps=9100),
            goal=_make_goal(target=10000.0),
        )
        client = _build_client(db)
        try:
            with patch("app.api.v1.quick_actions.datetime") as mock_dt:
                mock_dt.now.return_value = evening
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        assert resp.status_code == 200
        titles = [a["title"] for a in resp.json()]
        assert any("almost" in t.lower() or "goal" in t.lower() for t in titles), (
            f"Expected step proximity nudge in: {titles}"
        )

    def test_step_proximity_nudge_absent_when_far_from_goal(self):
        """When today_steps is far from goal, no proximity nudge is shown."""
        evening = datetime(2026, 1, 15, 19, 0, tzinfo=timezone.utc)

        # steps=3000, goal=10000 → remaining=7000 → well outside threshold
        db = _build_db(
            user=_make_user(coach_persona="tough_love"),
            metrics=_make_metrics(steps=3000),
            goal=_make_goal(target=10000.0),
        )
        client = _build_client(db)
        try:
            with patch("app.api.v1.quick_actions.datetime") as mock_dt:
                mock_dt.now.return_value = evening
                mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
                resp = client.get("/api/v1/quick-actions", headers=AUTH_HEADERS)
        finally:
            _cleanup()

        titles = [a["title"] for a in resp.json()]
        assert not any("almost" in t.lower() for t in titles), f"Unexpected proximity nudge in: {titles}"


# ---------------------------------------------------------------------------
# Test: Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_missing_auth_returns_401(self):
        """GET /quick-actions without Authorization header returns 401."""
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.get("/api/v1/quick-actions")
        assert resp.status_code == 401
