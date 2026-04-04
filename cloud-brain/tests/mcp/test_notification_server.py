"""Tests for NotificationServer Redis-backed daily rate limiting.

Verifies that the 10/user/day cap is enforced correctly, that Redis errors
cause fail-open behaviour (the notification goes through), and that basic
input validation still blocks bad requests before the rate check runs.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import redis.asyncio as aioredis

from app.mcp_servers.notification_server import NotificationServer
from app.mcp_servers.models import ToolResult

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

USER_ID = "user-abc-123"


def _make_server(
    redis_incr_return: int = 1,
    redis_side_effect: BaseException | None = None,
) -> tuple[NotificationServer, AsyncMock, AsyncMock]:
    """Build a NotificationServer wired to mock dependencies.

    Returns:
        (server, mock_redis, mock_push_service)
    """
    # Mock Redis client — explicitly use AsyncMock for incr/expire because
    # redis.asyncio.Redis uses a command-builder pattern that `inspect` does
    # not recognise as a coroutine, so spec-based auto-mocking creates sync
    # mocks that cannot be awaited.
    mock_redis = MagicMock()
    if redis_side_effect is not None:
        mock_redis.incr = AsyncMock(side_effect=redis_side_effect)
    else:
        mock_redis.incr = AsyncMock(return_value=redis_incr_return)
    mock_redis.expire = AsyncMock()

    # Mock push service
    mock_push = AsyncMock()
    mock_push.send_and_persist = AsyncMock(return_value=True)

    # Mock db session (async context manager)
    mock_db = AsyncMock()

    @asynccontextmanager
    async def _db_factory():
        yield mock_db

    db_factory = MagicMock(side_effect=_db_factory)

    server = NotificationServer(
        db_factory=db_factory,
        push_service=mock_push,
        redis_client=mock_redis,
    )
    return server, mock_redis, mock_push


# ---------------------------------------------------------------------------
# Server identity
# ---------------------------------------------------------------------------


def test_name_property() -> None:
    server, _, _ = _make_server()
    assert server.name == "notification"


def test_returns_one_tool() -> None:
    server, _, _ = _make_server()
    assert len(server.get_tools()) == 1


# ---------------------------------------------------------------------------
# Rate limiting — allowed cases
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_first_notification_allowed() -> None:
    server, _, mock_push = _make_server(redis_incr_return=1)
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is True
    mock_push.send_and_persist.assert_called_once()


@pytest.mark.asyncio
async def test_notification_exactly_at_limit_is_allowed() -> None:
    """The 10th notification of the day must still go through."""
    server, _, mock_push = _make_server(redis_incr_return=10)
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is True
    mock_push.send_and_persist.assert_called_once()


# ---------------------------------------------------------------------------
# Rate limiting — blocked case
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_notification_at_limit_is_blocked() -> None:
    """The 11th notification must be rejected."""
    server, _, mock_push = _make_server(redis_incr_return=11)
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is False
    assert result.error is not None
    assert "limit" in result.error.lower()
    mock_push.send_and_persist.assert_not_called()


# ---------------------------------------------------------------------------
# Fail-open on Redis error
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_redis_error_fails_open() -> None:
    """A Redis outage must not silence real coaching nudges."""
    server, _, mock_push = _make_server(
        redis_side_effect=aioredis.RedisError("connection refused")
    )
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is True
    mock_push.send_and_persist.assert_called_once()


# ---------------------------------------------------------------------------
# EXPIRE behaviour
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_expire_called_on_first_notification() -> None:
    """On the very first increment (count == 1), EXPIRE must be set."""
    server, mock_redis, _ = _make_server(redis_incr_return=1)
    await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    mock_redis.expire.assert_called_once()


@pytest.mark.asyncio
async def test_expire_not_called_on_subsequent() -> None:
    """On increments > 1, EXPIRE must NOT be called again (key already has TTL)."""
    server, mock_redis, _ = _make_server(redis_incr_return=5)
    await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    mock_redis.expire.assert_not_called()


# ---------------------------------------------------------------------------
# Input validation (runs before rate check)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_empty_title_rejected() -> None:
    server, _, mock_push = _make_server()
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is False
    mock_push.send_and_persist.assert_not_called()


@pytest.mark.asyncio
async def test_title_over_100_chars_rejected() -> None:
    server, _, mock_push = _make_server()
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "x" * 101, "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is False
    mock_push.send_and_persist.assert_not_called()


@pytest.mark.asyncio
async def test_body_over_250_chars_rejected() -> None:
    server, _, mock_push = _make_server()
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "x" * 251},
        user_id=USER_ID,
    )
    assert result.success is False
    mock_push.send_and_persist.assert_not_called()


@pytest.mark.asyncio
async def test_unknown_tool_rejected() -> None:
    server, _, mock_push = _make_server()
    result = await server.execute_tool(
        tool_name="unknown",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is False
    mock_push.send_and_persist.assert_not_called()


# ---------------------------------------------------------------------------
# No-Redis path (redis_client=None)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_no_redis_client_skips_rate_check() -> None:
    """When no Redis client is provided, the rate check is skipped entirely."""
    mock_push = AsyncMock()
    mock_push.send_and_persist = AsyncMock(return_value=True)
    mock_db = AsyncMock()

    @asynccontextmanager
    async def _db_factory():
        yield mock_db

    server = NotificationServer(
        db_factory=MagicMock(side_effect=_db_factory),
        push_service=mock_push,
        redis_client=None,
    )
    result = await server.execute_tool(
        tool_name="send_notification",
        params={"title": "Hello", "body": "World"},
        user_id=USER_ID,
    )
    assert result.success is True
    mock_push.send_and_persist.assert_called_once()
