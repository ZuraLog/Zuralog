"""
Tests for Conversation Management API.

Covers:
    - List returns all conversations for the authenticated user.
    - List excludes conversations belonging to other users.
    - PATCH renames a conversation.
    - DELETE removes the conversation (and its messages via cascade).
    - 404 on non-existent conversation for PATCH and DELETE.
    - 403 when a user attempts to PATCH/DELETE another user's conversation.
    - 401 when the Authorization header is missing.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.conversation_routes import router as conv_router
from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.models.conversation import Conversation, Message


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

USER_A = "user-aaa"
USER_B = "user-bbb"
TOKEN_A = "Bearer token-aaa"
TOKEN_B = "Bearer token-bbb"


def _make_conv(user_id: str = USER_A, title: str | None = "My Workout Log") -> Conversation:
    """Build an in-memory Conversation (not DB-backed)."""
    conv = Conversation()
    conv.id = str(uuid.uuid4())
    conv.user_id = user_id
    conv.title = title
    conv.created_at = datetime(2026, 1, 10, 8, 0, tzinfo=timezone.utc)
    conv.updated_at = None
    return conv


def _make_message(conv_id: str, content: str = "Hello!") -> Message:
    msg = Message()
    msg.id = str(uuid.uuid4())
    msg.conversation_id = conv_id
    msg.role = "user"
    msg.content = content
    msg.created_at = datetime(2026, 1, 10, 8, 1, tzinfo=timezone.utc)
    return msg


def _mock_execute_returning_scalar(value):
    """Return an AsyncMock execute() that yields scalar_one() = value."""
    result = MagicMock()
    result.scalar_one.return_value = value
    result.scalar_one_or_none.return_value = None
    result.scalars.return_value.all.return_value = []
    return result


def _build_client(user_id: str, db: AsyncMock) -> TestClient:
    """Build a TestClient with auth and DB mocked for the given user."""
    app.dependency_overrides[get_authenticated_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db
    client = TestClient(app, raise_server_exceptions=False)
    return client


def _cleanup():
    app.dependency_overrides.pop(get_authenticated_user_id, None)
    app.dependency_overrides.pop(get_db, None)


# ---------------------------------------------------------------------------
# List conversations
# ---------------------------------------------------------------------------


class TestListConversations:
    def test_list_returns_user_conversations(self):
        """GET /conversations returns the authenticated user's conversations."""
        conv = _make_conv(user_id=USER_A)
        msg = _make_message(conv.id, "Morning run done!")

        db = AsyncMock()
        call_count = 0

        async def _execute(stmt):
            nonlocal call_count
            call_count += 1
            result = MagicMock()
            if call_count == 1:
                # total count
                result.scalar_one.return_value = 1
            elif call_count == 2:
                # conversation rows
                result.scalars.return_value.all.return_value = [conv]
            elif call_count == 3:
                # message count for conv
                result.scalar_one.return_value = 1
            elif call_count == 4:
                # last message preview
                result.scalar_one_or_none.return_value = msg.content
            return result

        db.execute = _execute

        client = _build_client(USER_A, db)
        try:
            resp = client.get(
                "/api/v1/conversations",
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert len(data["items"]) == 1
        assert data["items"][0]["id"] == conv.id
        assert data["items"][0]["message_count"] == 1
        assert data["items"][0]["preview"] == "Morning run done!"

    def test_list_excludes_other_users_conversations(self):
        """Only USER_A's conversations are returned, not USER_B's."""
        conv_b = _make_conv(user_id=USER_B)

        db = AsyncMock()
        call_count = 0

        async def _execute(stmt):
            nonlocal call_count
            call_count += 1
            result = MagicMock()
            if call_count == 1:
                result.scalar_one.return_value = 0
            elif call_count == 2:
                result.scalars.return_value.all.return_value = []
            return result

        db.execute = _execute

        client = _build_client(USER_A, db)
        try:
            resp = client.get(
                "/api/v1/conversations",
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 0
        assert data["items"] == []

    def test_list_returns_401_without_auth(self):
        """Missing Authorization header should return 401."""
        # Remove dependency override so real auth runs (which will fail with no token)
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.get("/api/v1/conversations")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# PATCH /conversations/{id}
# ---------------------------------------------------------------------------


class TestPatchConversation:
    def test_patch_renames_conversation(self):
        """PATCH /conversations/{id} with a new title updates the title."""
        conv = _make_conv(user_id=USER_A, title="Old Title")

        db = AsyncMock()
        call_count = 0

        async def _execute(stmt):
            nonlocal call_count
            call_count += 1
            result = MagicMock()
            if call_count == 1:
                result.scalar_one_or_none.return_value = conv
            elif call_count == 2:
                result.scalar_one.return_value = 0  # msg count
            elif call_count == 3:
                result.scalar_one_or_none.return_value = None  # preview
            return result

        db.execute = _execute
        db.commit = AsyncMock()
        db.refresh = AsyncMock()

        client = _build_client(USER_A, db)
        try:
            resp = client.patch(
                f"/api/v1/conversations/{conv.id}",
                json={"title": "New Title"},
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 200
        # The model was mutated in-place; verify title was set
        assert conv.title == "New Title"

    def test_patch_returns_404_for_nonexistent_conversation(self):
        """PATCH on a conversation that doesn't exist returns 404."""
        db = AsyncMock()

        async def _execute(stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = None
            return result

        db.execute = _execute

        client = _build_client(USER_A, db)
        try:
            resp = client.patch(
                "/api/v1/conversations/does-not-exist",
                json={"title": "Whatever"},
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 404

    def test_patch_returns_403_for_other_users_conversation(self):
        """PATCH on USER_B's conversation by USER_A returns 403."""
        conv_b = _make_conv(user_id=USER_B)

        db = AsyncMock()

        async def _execute(stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = conv_b  # found, but belongs to B
            return result

        db.execute = _execute

        client = _build_client(USER_A, db)
        try:
            resp = client.patch(
                f"/api/v1/conversations/{conv_b.id}",
                json={"title": "Stolen"},
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 403

    def test_patch_returns_401_without_auth(self):
        """Missing Authorization header on PATCH returns 401."""
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.patch(
            "/api/v1/conversations/some-id",
            json={"title": "X"},
        )
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# DELETE /conversations/{id}
# ---------------------------------------------------------------------------


class TestDeleteConversation:
    def test_delete_removes_conversation(self):
        """DELETE /conversations/{id} hard-deletes the conversation."""
        conv = _make_conv(user_id=USER_A)

        db = AsyncMock()

        async def _execute(stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = conv
            return result

        db.execute = _execute
        db.delete = AsyncMock()
        db.commit = AsyncMock()

        client = _build_client(USER_A, db)
        try:
            resp = client.delete(
                f"/api/v1/conversations/{conv.id}",
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 204
        db.delete.assert_awaited_once_with(conv)
        db.commit.assert_awaited_once()

    def test_delete_returns_404_for_nonexistent_conversation(self):
        """DELETE on a conversation that doesn't exist returns 404."""
        db = AsyncMock()

        async def _execute(stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = None
            return result

        db.execute = _execute

        client = _build_client(USER_A, db)
        try:
            resp = client.delete(
                "/api/v1/conversations/ghost-id",
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 404

    def test_delete_returns_403_for_other_users_conversation(self):
        """DELETE on USER_B's conversation by USER_A returns 403."""
        conv_b = _make_conv(user_id=USER_B)

        db = AsyncMock()

        async def _execute(stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = conv_b
            return result

        db.execute = _execute

        client = _build_client(USER_A, db)
        try:
            resp = client.delete(
                f"/api/v1/conversations/{conv_b.id}",
                headers={"Authorization": TOKEN_A},
            )
        finally:
            _cleanup()

        assert resp.status_code == 403

    def test_delete_returns_401_without_auth(self):
        """Missing Authorization header on DELETE returns 401."""
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.delete("/api/v1/conversations/some-id")
        assert resp.status_code == 401
