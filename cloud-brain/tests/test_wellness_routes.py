"""
Zuralog Cloud Brain — Tests for POST /api/v1/wellness/parse.

Uses the shared ``integration_client`` fixture from conftest.py
(mocked AuthService + DB) and patches ``parse_transcript`` directly
so tests never make real LLM calls.

Coverage:
  - Happy path returns correct structured response
  - Values are clamped to the 1.0–10.0 range
  - Unknown tags are filtered out
  - Empty transcript is rejected with 422
  - Transcript over 5000 chars is rejected with 422
  - Missing auth header returns 401
  - LLM JSON parse failure returns 502
  - llm_client=None returns 503
"""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from openai import APIError

USER_ID = "user-wellness-001"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _setup_auth(mock_auth):
    """Configure the mock AuthService to return a known user."""
    mock_auth.get_user.return_value = {"id": USER_ID}


# ---------------------------------------------------------------------------
# Happy-path
# ---------------------------------------------------------------------------


def test_wellness_parse_success(integration_client):
    """POST /api/v1/wellness/parse returns structured data when LLM succeeds."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    fake_result = {
        "mood": 4.0,
        "energy": 6.0,
        "stress": 8.0,
        "tags": ["work_stress"],
        "summary": "Sounds like a heavy day.",
    }

    with patch(
        "app.api.v1.wellness_routes.parse_transcript",
        new_callable=AsyncMock,
        return_value=fake_result,
    ):
        response = client.post(
            "/api/v1/wellness/parse",
            json={"transcript": "had a rough day at work, feeling pretty drained"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    data = response.json()
    assert data["mood"] == 4.0
    assert data["energy"] == 6.0
    assert data["stress"] == 8.0
    assert data["tags"] == ["work_stress"]
    assert data["summary"] == "Sounds like a heavy day."


# ---------------------------------------------------------------------------
# Value clamping (unit-level — test parse_transcript directly)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_parse_transcript_clamps_values():
    """parse_transcript should clamp out-of-range LLM values to 1.0–10.0."""
    from app.api.v1.wellness_routes import parse_transcript

    mock_llm = MagicMock()
    mock_response = MagicMock()
    mock_response.choices = [
        MagicMock(message=MagicMock(content=json.dumps({
            "mood": 0.0,    # below min → 1.0
            "energy": 11.5, # above max → 10.0
            "stress": 5.0,
            "tags": ["calm"],
            "summary": "All good.",
        })))
    ]
    mock_llm.chat = AsyncMock(return_value=mock_response)

    result = await parse_transcript("feeling okay", mock_llm)

    assert result["mood"] == 1.0
    assert result["energy"] == 10.0
    assert result["stress"] == 5.0


@pytest.mark.asyncio
async def test_parse_transcript_filters_unknown_tags():
    """parse_transcript should strip tags not in the preset list."""
    from app.api.v1.wellness_routes import parse_transcript

    mock_llm = MagicMock()
    mock_response = MagicMock()
    mock_response.choices = [
        MagicMock(message=MagicMock(content=json.dumps({
            "mood": 7.0,
            "energy": 8.0,
            "stress": 2.0,
            "tags": ["calm", "unknown_tag", "exercise"],
            "summary": "Great day.",
        })))
    ]
    mock_llm.chat = AsyncMock(return_value=mock_response)

    result = await parse_transcript("feeling great", mock_llm)

    assert "unknown_tag" not in result["tags"]
    assert "calm" in result["tags"]
    assert "exercise" in result["tags"]


@pytest.mark.asyncio
async def test_parse_transcript_truncates_summary():
    """parse_transcript should truncate summary to 240 chars."""
    from app.api.v1.wellness_routes import parse_transcript

    long_summary = "x" * 300
    mock_llm = MagicMock()
    mock_response = MagicMock()
    mock_response.choices = [
        MagicMock(message=MagicMock(content=json.dumps({
            "mood": 5.0,
            "energy": 5.0,
            "stress": 5.0,
            "tags": [],
            "summary": long_summary,
        })))
    ]
    mock_llm.chat = AsyncMock(return_value=mock_response)

    result = await parse_transcript("test", mock_llm)

    assert len(result["summary"]) == 240


# ---------------------------------------------------------------------------
# Validation errors
# ---------------------------------------------------------------------------


def test_wellness_parse_rejects_empty_transcript(integration_client):
    """POST with an empty transcript should return 422."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    response = client.post(
        "/api/v1/wellness/parse",
        json={"transcript": ""},
        headers=AUTH_HEADERS,
    )

    assert response.status_code == 422


def test_wellness_parse_rejects_oversized_transcript(integration_client):
    """POST with a transcript > 5000 chars should return 422."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    response = client.post(
        "/api/v1/wellness/parse",
        json={"transcript": "a" * 5001},
        headers=AUTH_HEADERS,
    )

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------


def test_wellness_parse_requires_auth(integration_client):
    """POST without Authorization header should return 401 (HTTPBearer rejects missing credentials)."""
    client, mock_auth, mock_db = integration_client

    response = client.post(
        "/api/v1/wellness/parse",
        json={"transcript": "feeling okay"},
    )

    # HTTPBearer returns 401 when no credentials are provided in this app
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# Error paths
# ---------------------------------------------------------------------------


def test_wellness_parse_llm_failure_returns_502(integration_client):
    """When parse_transcript raises a JSON decode error, endpoint returns 502."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    with patch(
        "app.api.v1.wellness_routes.parse_transcript",
        new_callable=AsyncMock,
        side_effect=json.JSONDecodeError("Expecting value", "", 0),
    ):
        response = client.post(
            "/api/v1/wellness/parse",
            json={"transcript": "feeling okay"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 502
    assert "AI parsing failed" in response.json()["detail"]


def test_wellness_parse_api_error_returns_502(integration_client):
    """When parse_transcript raises openai.APIError, endpoint returns 502."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    with patch(
        "app.api.v1.wellness_routes.parse_transcript",
        new_callable=AsyncMock,
        side_effect=APIError("LLM network failure", request=MagicMock(), body=None),
    ):
        response = client.post(
            "/api/v1/wellness/parse",
            json={"transcript": "feeling okay"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 502
    assert "AI parsing failed" in response.json()["detail"]


def test_wellness_parse_accepts_exactly_5000_chars(integration_client):
    """POST with a transcript of exactly 5000 chars should return 200 (boundary check)."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    fake_result = {
        "mood": 5.0,
        "energy": 5.0,
        "stress": 5.0,
        "tags": [],
        "summary": "Boundary test.",
    }

    with patch(
        "app.api.v1.wellness_routes.parse_transcript",
        new_callable=AsyncMock,
        return_value=fake_result,
    ):
        response = client.post(
            "/api/v1/wellness/parse",
            json={"transcript": "a" * 5000},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200


def test_wellness_parse_no_llm_client_returns_503(integration_client):
    """When app.state.llm_client is None, endpoint returns 503."""
    client, mock_auth, mock_db = integration_client
    _setup_auth(mock_auth)

    from app.main import app as fastapi_app
    original = getattr(fastapi_app.state, "llm_client", None)
    fastapi_app.state.llm_client = None

    try:
        response = client.post(
            "/api/v1/wellness/parse",
            json={"transcript": "feeling okay"},
            headers=AUTH_HEADERS,
        )
    finally:
        fastapi_app.state.llm_client = original

    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]
