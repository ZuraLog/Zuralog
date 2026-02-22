"""
Life Logger Cloud Brain — Chat Endpoint Tests.

Tests for the WebSocket /ws/chat endpoint and REST /chat/history endpoint.
Uses FastAPI dependency_overrides to inject mocked services.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException, status
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service as auth_get_auth_service
from app.api.v1.chat import _get_auth_service as chat_get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_auth_service():
    """Create a mocked AuthService."""
    return AsyncMock(spec=AuthService)


@pytest.fixture
def mock_db():
    """Create a mocked async database session."""
    return AsyncMock()


@pytest.fixture
def client(mock_auth_service, mock_db):
    """Create a TestClient with mocked dependencies.

    Note: The lifespan function sets app.state values on startup,
    so we must override them AFTER the TestClient context enters.
    """
    app.dependency_overrides[auth_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[chat_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        # Override app.state AFTER lifespan has run (it sets real services)
        app.state.auth_service = mock_auth_service
        app.state.mcp_client = MagicMock()
        app.state.mcp_client.get_all_tools.return_value = []
        app.state.memory_store = MagicMock()
        app.state.memory_store.query = AsyncMock(return_value=[])

        # Mock LLM client so tests don't call the real OpenAI API
        mock_llm = MagicMock()
        mock_msg = MagicMock()
        mock_msg.content = "Hello from the AI Brain!"
        mock_msg.tool_calls = None
        mock_resp = MagicMock()
        mock_resp.choices = [MagicMock(message=mock_msg)]
        mock_llm.chat = AsyncMock(return_value=mock_resp)
        app.state.llm_client = mock_llm

        yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# WebSocket Tests
# ---------------------------------------------------------------------------


def test_ws_rejects_without_token(client):
    """WebSocket connection without a token should be rejected."""
    with pytest.raises(Exception):
        with client.websocket_connect("/api/v1/chat/ws"):
            pass


def test_ws_rejects_with_invalid_token(client, mock_auth_service):
    """WebSocket connection with invalid token should be rejected."""
    mock_auth_service.get_user.side_effect = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid token",
    )

    with pytest.raises(Exception):
        with client.websocket_connect("/api/v1/chat/ws?token=bad-token"):
            pass


def test_ws_connect_and_echo(client, mock_auth_service):
    """WebSocket should connect with valid token and respond via orchestrator."""
    mock_auth_service.get_user.return_value = {
        "id": "user-123",
        "email": "test@example.com",
    }

    with client.websocket_connect("/api/v1/chat/ws?token=valid-token") as ws:
        ws.send_json({"message": "Hello"})
        response = ws.receive_json()

        assert response["type"] == "message"
        assert response["role"] == "assistant"
        assert "AI Brain" in response["content"]
        mock_auth_service.get_user.assert_called_once_with("valid-token")


def test_ws_empty_message_returns_error(client, mock_auth_service):
    """Sending an empty message should return an error response."""
    mock_auth_service.get_user.return_value = {
        "id": "user-123",
        "email": "test@example.com",
    }

    with client.websocket_connect("/api/v1/chat/ws?token=valid-token") as ws:
        ws.send_json({"message": ""})
        response = ws.receive_json()

        assert response["type"] == "error"
        assert "Empty message" in response["content"]


# ---------------------------------------------------------------------------
# Chat History REST Tests
# ---------------------------------------------------------------------------


def test_chat_history_no_auth(client):
    """Chat history without auth should return 401/403."""
    response = client.get("/api/v1/chat/history")
    assert response.status_code in (401, 403)


def test_chat_history_empty(client, mock_auth_service, mock_db):
    """Chat history with valid auth but no conversations should return []."""
    mock_auth_service.get_user.return_value = {
        "id": "user-123",
        "email": "test@example.com",
    }

    # Mock the DB query to return empty scalars
    mock_scalars = MagicMock()
    mock_scalars.all.return_value = []
    mock_result = MagicMock()
    mock_result.scalars.return_value = mock_scalars
    mock_db.execute.return_value = mock_result

    response = client.get(
        "/api/v1/chat/history",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json() == []


# ---------------------------------------------------------------------------
# Health Check (regression)
# ---------------------------------------------------------------------------


def test_health_still_works(client):
    """Health endpoint should still return healthy after chat changes."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
