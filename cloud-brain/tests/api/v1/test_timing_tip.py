"""Tests for GET /api/v1/supplements/timing-tip."""
from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient

from app.main import app
from app.api.deps import get_authenticated_user_id

client = TestClient(app)

_AUTH_USER_ID = "test-user-id"


def _auth_override():
    return _AUTH_USER_ID


app.dependency_overrides[get_authenticated_user_id] = _auth_override


def _make_llm_client(tip: str | None = "Take with food for best absorption.") -> MagicMock:
    """Return a mock LLM client whose .chat() returns a response with the given tip."""
    import json

    mock_llm = MagicMock()
    message = MagicMock()
    message.content = json.dumps({"tip": tip})
    choice = MagicMock()
    choice.message = message
    response = MagicMock()
    response.choices = [choice]
    mock_llm.chat = AsyncMock(return_value=response)
    return mock_llm


def test_timing_tip_valid_request_returns_tip():
    """Valid supplement_name + timing → 200 with tip field."""
    mock_llm = _make_llm_client("Take Vitamin D with a fatty meal for best absorption.")
    app.state.llm_client = mock_llm
    try:
        response = client.get(
            "/api/v1/supplements/timing-tip",
            params={"supplement_name": "Vitamin D", "timing": "with breakfast"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "tip" in data
        assert data["tip"] == "Take Vitamin D with a fatty meal for best absorption."
    finally:
        app.state.llm_client = None


def test_timing_tip_missing_supplement_name_returns_422():
    """Missing supplement_name → 422 validation error."""
    response = client.get(
        "/api/v1/supplements/timing-tip",
        params={"timing": "with breakfast"},
    )
    assert response.status_code == 422


def test_timing_tip_requires_auth():
    """No auth → 401."""
    app.dependency_overrides.pop(get_authenticated_user_id, None)
    try:
        response = client.get(
            "/api/v1/supplements/timing-tip",
            params={"supplement_name": "Magnesium", "timing": "before bed"},
        )
        assert response.status_code == 401
    finally:
        app.dependency_overrides[get_authenticated_user_id] = _auth_override


def test_timing_tip_llm_returns_null_tip():
    """LLM returns {"tip": null} → 200 with tip=None."""
    mock_llm = _make_llm_client(tip=None)
    app.state.llm_client = mock_llm
    try:
        response = client.get(
            "/api/v1/supplements/timing-tip",
            params={"supplement_name": "Collagen", "timing": "morning"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["tip"] is None
    finally:
        app.state.llm_client = None
