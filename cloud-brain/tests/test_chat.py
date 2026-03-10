"""
Zuralog Cloud Brain — Chat Endpoint Tests.

Tests for the WebSocket /ws/chat endpoint and REST /chat/history endpoint.
Uses FastAPI dependency_overrides to inject mocked services and
monkeypatches the async_session used by the WebSocket handler.
"""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch

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
    """Create a mocked async database session.

    Configures execute() to return a MagicMock with sync .scalars()/.scalar_one_or_none()
    methods so that ORM result-processing code works without a real DB.
    """
    db = AsyncMock()
    # execute() is awaited, so its return_value is what callers receive.
    # The result object must support sync calls like .scalars().all() and
    # .scalar_one_or_none() — use a plain MagicMock for those.
    mock_result = MagicMock()
    mock_scalars = MagicMock()
    mock_scalars.all.return_value = []
    mock_result.scalars.return_value = mock_scalars
    mock_result.scalar_one_or_none.return_value = None
    db.execute.return_value = mock_result
    return db


@pytest.fixture
def client(mock_auth_service, mock_db):
    """Create a TestClient with mocked dependencies.

    Note: The lifespan function sets app.state values on startup,
    so we must override them AFTER the TestClient context enters.
    Patches ``async_session`` in the chat module so the WS handler
    does not attempt real DB connections for rate-limit / usage
    tracking.
    """
    app.dependency_overrides[auth_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[chat_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    # Build a fake async context manager that yields mock_db
    @asynccontextmanager
    async def _fake_session():
        yield mock_db

    # Patch LLMClient in the orchestrator module so the _title_client created
    # inside Orchestrator.__init__ doesn't attempt real OpenAI API calls.
    mock_title_llm = MagicMock()
    mock_title_resp = MagicMock()
    mock_title_resp.choices = [MagicMock(message=MagicMock(content="Test Title"))]
    mock_title_llm.chat = AsyncMock(return_value=mock_title_resp)

    with (
        patch("app.api.v1.chat.async_session", _fake_session),
        patch("app.agent.orchestrator.LLMClient", return_value=mock_title_llm),
    ):
        with TestClient(app, raise_server_exceptions=False) as c:
            # Override app.state AFTER lifespan has run (it sets real services)
            app.state.auth_service = mock_auth_service
            app.state.mcp_client = MagicMock()
            app.state.mcp_client.get_all_tools.return_value = []
            app.state.mcp_client.get_tools_for_user = AsyncMock(return_value=[])
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

            # stream_chat is awaited and then iterated: stream = await llm_client.stream_chat(...)
            # then: async for chunk in stream: chunk.choices[0].delta.content
            # So stream_chat must be a coroutine that returns an async iterable.
            async def _fake_stream_iterable():
                mock_delta = MagicMock()
                mock_delta.content = "Hello from the AI Brain!"
                mock_chunk = MagicMock()
                mock_chunk.choices = [MagicMock(delta=mock_delta)]
                yield mock_chunk

            async def _fake_stream_chat(messages, tools=None):
                return _fake_stream_iterable()

            mock_llm.stream_chat = _fake_stream_chat
            app.state.llm_client = mock_llm

            # Disable rate limiter for most tests (tested separately)
            app.state.rate_limiter = None

            # Storage service (needed by websocket_chat and REST endpoints)
            app.state.storage_service = MagicMock()

            yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# WebSocket Tests
# ---------------------------------------------------------------------------


def test_ws_rejects_without_token(client):
    """WebSocket connection without a token should send error and close."""
    with client.websocket_connect("/api/v1/chat/ws") as ws:
        response = ws.receive_json()
        assert response["type"] == "error"
        assert "auth token" in response["content"].lower()


def test_ws_rejects_with_invalid_token(client, mock_auth_service):
    """WebSocket connection with invalid token should send error and close."""
    mock_auth_service.get_user.side_effect = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid token",
    )

    with client.websocket_connect("/api/v1/chat/ws?token=bad-token") as ws:
        response = ws.receive_json()
        assert response["type"] == "error"
        assert "invalid" in response["content"].lower() or "expired" in response["content"].lower()


def test_ws_connect_and_echo(client, mock_auth_service):
    """WebSocket should connect with valid token and respond via orchestrator."""
    mock_auth_service.get_user.return_value = {
        "id": "user-123",
        "email": "test@example.com",
    }

    with client.websocket_connect("/api/v1/chat/ws?token=valid-token") as ws:
        # Server sends conversation_init immediately on connect
        init_msg = ws.receive_json()
        assert init_msg["type"] == "conversation_init"
        assert "conversation_id" in init_msg

        # Send user message
        ws.send_json({"message": "Hello"})

        # Server sends typing_start before processing
        typing_msg = ws.receive_json()
        assert typing_msg["type"] == "typing_start"

        # Collect stream_token events until stream_end
        full_content = ""
        while True:
            event = ws.receive_json()
            if event["type"] == "stream_token":
                full_content += event["content"]
            elif event["type"] == "stream_end":
                # stream_end carries the final assembled content
                full_content = event.get("content", full_content)
                assert "conversation_id" in event
                assert "message_id" in event
                break
            else:
                raise AssertionError(f"Unexpected event type: {event['type']}")

        assert "AI Brain" in full_content
        mock_auth_service.get_user.assert_called_once_with("valid-token")


def test_ws_empty_message_returns_error(client, mock_auth_service):
    """Sending an empty message should return an error response."""
    mock_auth_service.get_user.return_value = {
        "id": "user-123",
        "email": "test@example.com",
    }

    with client.websocket_connect("/api/v1/chat/ws?token=valid-token") as ws:
        # Server sends conversation_init immediately on connect (before any message)
        init_msg = ws.receive_json()
        assert init_msg["type"] == "conversation_init"

        # Send empty message
        ws.send_json({"message": ""})

        # Server should respond with an error (and keep the connection open)
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
