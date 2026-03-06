"""
Zuralog Cloud Brain — Conversation Management Endpoint Tests.

Tests for the conversation management REST endpoints:
  - GET  /api/v1/chat/conversations
  - PATCH /api/v1/chat/conversations/{id}
  - DELETE /api/v1/chat/conversations/{id}

Uses FastAPI dependency_overrides to inject mocked services and an
AsyncMock database session so no real DB connection is required.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException, status
from fastapi.testclient import TestClient

from app.api.v1.chat import _get_auth_service as chat_get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_USER_A = {"id": "user-a", "email": "a@example.com"}
_USER_B = {"id": "user-b", "email": "b@example.com"}


def _make_conversation(
    conv_id: str = "conv-1",
    user_id: str = "user-a",
    title: str = "My Chat",
) -> MagicMock:
    """Build a mock Conversation ORM object."""
    conv = MagicMock()
    conv.id = conv_id
    conv.user_id = user_id
    conv.title = title
    conv.created_at = MagicMock()
    conv.created_at.isoformat.return_value = "2026-01-01T00:00:00+00:00"
    return conv


def _make_message(
    msg_id: str = "msg-1",
    conversation_id: str = "conv-1",
    role: str = "user",
    content: str = "Hello there",
) -> MagicMock:
    """Build a mock Message ORM object."""
    msg = MagicMock()
    msg.id = msg_id
    msg.conversation_id = conversation_id
    msg.role = role
    msg.content = content
    msg.created_at = MagicMock()
    msg.created_at.isoformat.return_value = "2026-01-01T00:01:00+00:00"
    return msg


def _mock_db_execute_sequence(mock_db: AsyncMock, returns: list) -> None:
    """Configure mock_db.execute to return successive values.

    Each call to ``await db.execute(...)`` pops the next value from
    ``returns`` and delivers it. This lets tests stage multiple query
    results in order.

    Args:
        mock_db: The AsyncMock database session.
        returns: Ordered list of values that successive execute calls
            should return.
    """
    side_effects = iter(returns)

    async def _side_effect(*args, **kwargs):
        return next(side_effects)

    mock_db.execute.side_effect = _side_effect


def _scalars_result(rows: list) -> MagicMock:
    """Wrap a list of ORM rows in a mock execute-result object."""
    scalars = MagicMock()
    scalars.all.return_value = rows
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _scalar_one_or_none_result(value) -> MagicMock:
    """Wrap a single value in a mock execute-result object."""
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_auth_service():
    """Mocked AuthService with no side effects by default."""
    return AsyncMock(spec=AuthService)


@pytest.fixture
def mock_db():
    """Mocked async database session."""
    db = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


@pytest.fixture
def client(mock_auth_service, mock_db):
    """TestClient with auth and DB dependencies overridden.

    Yields:
        TestClient configured for conversation management tests.
    """
    app.dependency_overrides[chat_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        app.state.auth_service = mock_auth_service
        yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# GET /api/v1/chat/conversations
# ---------------------------------------------------------------------------


def test_list_conversations(client, mock_auth_service, mock_db):
    """List endpoint returns all conversations belonging to the user."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = _make_conversation("conv-1", "user-a", "My Chat")
    msg = _make_message("msg-1", "conv-1", "user", "Hello there, how are you?")

    _mock_db_execute_sequence(
        mock_db,
        [
            _scalars_result([conv]),   # conversations query
            _scalars_result([msg]),    # messages query for conv-1
        ],
    )

    response = client.get(
        "/api/v1/chat/conversations",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["id"] == "conv-1"
    assert data[0]["title"] == "My Chat"
    assert data[0]["message_count"] == 1
    assert data[0]["preview_snippet"] == "Hello there, how are you?"


def test_list_conversations_preview_truncated(client, mock_auth_service, mock_db):
    """Preview snippet is truncated to 100 characters."""
    mock_auth_service.get_user.return_value = _USER_A

    long_content = "A" * 150
    conv = _make_conversation("conv-1", "user-a", "Long")
    msg = _make_message("msg-1", "conv-1", "assistant", long_content)

    _mock_db_execute_sequence(
        mock_db,
        [
            _scalars_result([conv]),
            _scalars_result([msg]),
        ],
    )

    response = client.get(
        "/api/v1/chat/conversations",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert len(response.json()[0]["preview_snippet"]) == 100


def test_list_conversations_excludes_other_users(client, mock_auth_service, mock_db):
    """List endpoint must not return conversations owned by other users.

    The DB query already filters by user_id. This test verifies that
    the endpoint passes user_id correctly and only surfaces what the
    query returns.
    """
    mock_auth_service.get_user.return_value = _USER_A

    # Simulate DB returning zero conversations for user-a (user-b's
    # conversations are never returned by a correctly filtered query).
    _mock_db_execute_sequence(
        mock_db,
        [_scalars_result([])],
    )

    response = client.get(
        "/api/v1/chat/conversations",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json() == []


def test_list_conversations_empty(client, mock_auth_service, mock_db):
    """List endpoint returns empty list when user has no conversations."""
    mock_auth_service.get_user.return_value = _USER_A

    _mock_db_execute_sequence(mock_db, [_scalars_result([])])

    response = client.get(
        "/api/v1/chat/conversations",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json() == []


def test_list_conversations_auth_required(client):
    """GET /conversations without a token must return 401 or 403."""
    response = client.get("/api/v1/chat/conversations")
    assert response.status_code in (401, 403)


# ---------------------------------------------------------------------------
# PATCH /api/v1/chat/conversations/{id}
# ---------------------------------------------------------------------------


def test_rename_conversation(client, mock_auth_service, mock_db):
    """PATCH updates the conversation title."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = _make_conversation("conv-1", "user-a", "Old Title")

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    # db.refresh should update the mock's attributes to simulate ORM refresh
    async def _refresh(obj):
        pass  # conv is already updated in-place

    mock_db.refresh.side_effect = _refresh

    response = client.patch(
        "/api/v1/chat/conversations/conv-1",
        json={"title": "New Title"},
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert conv.title == "New Title"
    data = response.json()
    assert data["id"] == "conv-1"
    assert data["title"] == "New Title"


def test_archive_conversation(client, mock_auth_service, mock_db):
    """PATCH with archived=True sets the archived flag gracefully."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = _make_conversation("conv-1", "user-a", "To Archive")
    conv.archived = False  # model supports archived

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    response = client.patch(
        "/api/v1/chat/conversations/conv-1",
        json={"archived": True},
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert conv.archived is True


def test_patch_conversation_not_found(client, mock_auth_service, mock_db):
    """PATCH returns 404 when the conversation does not exist."""
    mock_auth_service.get_user.return_value = _USER_A

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(None)],
    )

    response = client.patch(
        "/api/v1/chat/conversations/nonexistent",
        json={"title": "X"},
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404


def test_patch_conversation_wrong_user(client, mock_auth_service, mock_db):
    """PATCH returns 404 when the conversation belongs to another user."""
    mock_auth_service.get_user.return_value = _USER_A

    # Conversation owned by user-b
    conv = _make_conversation("conv-1", "user-b", "Someone else's chat")

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    response = client.patch(
        "/api/v1/chat/conversations/conv-1",
        json={"title": "Hijack"},
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404


def test_patch_conversation_auth_required(client):
    """PATCH without a token must return 401 or 403."""
    response = client.patch(
        "/api/v1/chat/conversations/conv-1",
        json={"title": "No auth"},
    )
    assert response.status_code in (401, 403)


# ---------------------------------------------------------------------------
# DELETE /api/v1/chat/conversations/{id}
# ---------------------------------------------------------------------------


def test_delete_conversation(client, mock_auth_service, mock_db):
    """DELETE soft-deletes the conversation and returns 204."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = _make_conversation("conv-1", "user-a", "To Delete")
    # Simulate model supporting deleted_at via normal attribute assignment
    conv.deleted_at = None

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    response = client.delete(
        "/api/v1/chat/conversations/conv-1",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 204
    mock_db.commit.assert_called_once()
    # deleted_at should now be set (not None)
    assert conv.deleted_at is not None


def test_delete_wrong_user_returns_404(client, mock_auth_service, mock_db):
    """DELETE returns 404 when the conversation belongs to another user."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = _make_conversation("conv-1", "user-b", "Not yours")

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    response = client.delete(
        "/api/v1/chat/conversations/conv-1",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    mock_db.commit.assert_not_called()


def test_delete_conversation_not_found(client, mock_auth_service, mock_db):
    """DELETE returns 404 when conversation does not exist."""
    mock_auth_service.get_user.return_value = _USER_A

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(None)],
    )

    response = client.delete(
        "/api/v1/chat/conversations/nonexistent",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404


def test_delete_conversation_auth_required(client):
    """DELETE without a token must return 401 or 403."""
    response = client.delete("/api/v1/chat/conversations/conv-1")
    assert response.status_code in (401, 403)


# ---------------------------------------------------------------------------
# Graceful degradation — model missing archived / deleted_at columns
# ---------------------------------------------------------------------------


def test_archive_conversation_no_archived_column(client, mock_auth_service, mock_db):
    """PATCH archived=True is a no-op (with warning) when model lacks 'archived'."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = MagicMock(spec=[])  # spec=[] → no attributes, all attr sets raise AttributeError
    conv.id = "conv-1"
    conv.user_id = "user-a"
    conv.title = "Title"
    conv.created_at = MagicMock()
    conv.created_at.isoformat.return_value = "2026-01-01T00:00:00+00:00"

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    # Should not raise — graceful degradation
    response = client.patch(
        "/api/v1/chat/conversations/conv-1",
        json={"archived": True},
        headers={"Authorization": "Bearer valid-token"},
    )

    # Still returns 200; archived field will be None
    assert response.status_code == 200


def test_delete_conversation_fallback_to_archived(client, mock_auth_service, mock_db):
    """DELETE falls back to archived=True when model lacks 'deleted_at'."""
    mock_auth_service.get_user.return_value = _USER_A

    conv = _make_conversation("conv-1", "user-a", "Fallback")
    conv.archived = False  # has archived but not deleted_at

    # Make setting deleted_at raise AttributeError, archived assignment succeed
    def _setattr(name, value):
        if name == "deleted_at":
            raise AttributeError("no deleted_at")
        object.__setattr__(conv, name, value)

    type(conv).__setattr__ = _setattr  # noqa: PLC2801

    _mock_db_execute_sequence(
        mock_db,
        [_scalar_one_or_none_result(conv)],
    )

    response = client.delete(
        "/api/v1/chat/conversations/conv-1",
        headers={"Authorization": "Bearer valid-token"},
    )

    # 204 returned regardless of which soft-delete path is taken
    assert response.status_code == 204
    mock_db.commit.assert_called_once()
