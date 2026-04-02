"""
Zuralog Cloud Brain — Memory Management API.

Endpoints for inspecting and managing the AI agent's long-term user memory.
These routes operate on whichever memory store is mounted at
``app.state.memory_store`` — either ``InMemoryStore`` (dev) or
``PgVectorMemoryStore`` (production).

Routes:
  GET    /api/v1/memories               — List all memories for the user.
  DELETE /api/v1/memories/{memory_id}   — Delete a single memory by ID.
  DELETE /api/v1/memories               — Clear ALL memories (requires confirm=true).

Notes:
  - ``InMemoryStore`` does not expose individual IDs, so the list endpoint
    returns an empty list when that implementation is in use.
  - All endpoints require a valid Supabase JWT.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel

from app.api.deps import get_authenticated_user_id
from app.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/memories", tags=["memories"])


# ---------------------------------------------------------------------------
# Pydantic response schemas
# ---------------------------------------------------------------------------


class MemoryItem(BaseModel):
    """A single stored memory entry.

    Attributes:
        id: Unique identifier for the memory vector.
        text: The natural-language content of the memory.
        metadata: Arbitrary key-value pairs attached at save time.
    """

    id: str
    text: str
    metadata: dict[str, Any] = {}


class MemoryListResponse(BaseModel):
    """Response envelope for the memory list endpoint.

    Attributes:
        memories: Ordered list of stored memory entries.
        count: Total number of entries returned.
        store_type: Class name of the backing memory store.
    """

    memories: list[MemoryItem]
    count: int
    store_type: str


class DeleteMemoryResponse(BaseModel):
    """Response for a single-memory delete operation.

    Attributes:
        deleted: ``True`` if the delete was acknowledged by the store.
        memory_id: The ID that was requested for deletion.
    """

    deleted: bool
    memory_id: str


class ClearMemoriesResponse(BaseModel):
    """Response for the clear-all-memories operation.

    Attributes:
        cleared: ``True`` if the clear was acknowledged by the store.
        message: Human-readable confirmation string.
    """

    cleared: bool
    message: str


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------


def _store_type_name(memory_store: Any) -> str:
    """Return the class name of the active memory store.

    Args:
        memory_store: The memory store object from app state.

    Returns:
        Class name string (e.g. ``"InMemoryStore"`` or ``"PgVectorMemoryStore"``).
    """
    return type(memory_store).__name__


def _is_managed_store(memory_store: Any) -> bool:
    """Check if the store supports the extended memory management interface.

    PgVectorMemoryStore (and formerly PineconeMemoryStore) implement
    list_memories, delete_memory, and clear_memories beyond the core
    MemoryStore protocol.

    Args:
        memory_store: The memory store object from app state.

    Returns:
        ``True`` if the store supports ``list_memories``, ``delete_memory``,
        and ``clear_memories``.
    """
    return (
        hasattr(memory_store, "list_memories")
        and hasattr(memory_store, "delete_memory")
        and hasattr(memory_store, "clear_memories")
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@limiter.limit("60/minute")
@router.get(
    "",
    response_model=MemoryListResponse,
    summary="List all stored memories for the authenticated user",
)
async def list_memories(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> MemoryListResponse:
    """Return all long-term memories stored for the authenticated user.

    When the active memory store is ``InMemoryStore`` (dev mode), the list
    will always be empty because that implementation does not expose individual
    IDs suitable for management.

    Args:
        request: FastAPI request (used to access ``app.state.memory_store``).
        user_id: Authenticated user ID injected by the JWT dependency.

    Returns:
        A ``MemoryListResponse`` containing the list of memories and metadata.
    """
    memory_store = request.app.state.memory_store
    store_name = _store_type_name(memory_store)

    if not _is_managed_store(memory_store):
        logger.debug(
            "list_memories: store is %s — returning empty list.", store_name
        )
        return MemoryListResponse(memories=[], count=0, store_type=store_name)

    raw_memories = await memory_store.list_memories(user_id)
    memories = [
        MemoryItem(id=str(m.id), text=m.content, metadata={"category": m.category})
        for m in raw_memories
    ]
    logger.info(
        "list_memories: returned %d memories for user '%s'.", len(memories), user_id
    )
    return MemoryListResponse(
        memories=memories,
        count=len(memories),
        store_type=store_name,
    )


@limiter.limit("30/minute")
@router.delete(
    "/{memory_id}",
    response_model=DeleteMemoryResponse,
    summary="Delete a single memory by ID",
)
async def delete_memory(
    memory_id: str,
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> DeleteMemoryResponse:
    """Delete a specific memory vector by its ID.

    Args:
        memory_id: The UUID of the memory to delete.
        request: FastAPI request (used to access ``app.state.memory_store``).
        user_id: Authenticated user ID injected by the JWT dependency.

    Returns:
        A ``DeleteMemoryResponse`` indicating success or failure.

    Raises:
        HTTPException: 501 if the active store does not support deletion.
    """
    memory_store = request.app.state.memory_store

    if not _is_managed_store(memory_store):
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=(
                f"The active memory store ({_store_type_name(memory_store)}) "
                "does not support individual memory deletion."
            ),
        )

    deleted = await memory_store.delete_memory(memory_id, user_id)
    logger.info(
        "delete_memory: user='%s', id='%s', success=%s.", user_id, memory_id, deleted
    )
    return DeleteMemoryResponse(deleted=deleted, memory_id=memory_id)


@limiter.limit("5/hour")
@router.delete(
    "",
    response_model=ClearMemoriesResponse,
    summary="Clear all memories for the authenticated user",
)
async def clear_memories(
    request: Request,
    confirm: bool = Query(
        False,
        description="Must be true to confirm destructive clear operation.",
    ),
    user_id: str = Depends(get_authenticated_user_id),
) -> ClearMemoriesResponse:
    """Delete ALL stored memories for the authenticated user.

    This is a destructive operation and cannot be undone. The caller must
    pass ``?confirm=true`` in the query string to proceed.

    Args:
        request: FastAPI request (used to access ``app.state.memory_store``).
        confirm: Query parameter guard. Must be ``true`` to execute.
        user_id: Authenticated user ID injected by the JWT dependency.

    Returns:
        A ``ClearMemoriesResponse`` with the outcome.

    Raises:
        HTTPException: 400 if ``confirm`` is not ``true``.
        HTTPException: 501 if the active store does not support bulk deletion.
    """
    if not confirm:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Pass ?confirm=true to confirm clearing all memories. This cannot be undone.",
        )

    memory_store = request.app.state.memory_store
    store_name = _store_type_name(memory_store)

    if not _is_managed_store(memory_store):
        # InMemoryStore: treat as a silent no-op
        logger.debug(
            "clear_memories: store is %s — no-op for non-managed store.", store_name
        )
        return ClearMemoriesResponse(
            cleared=True,
            message=f"No persistent memories to clear ({store_name} is ephemeral).",
        )

    cleared = await memory_store.clear_memories(user_id)
    logger.info(
        "clear_memories: user='%s', success=%s.", user_id, cleared
    )
    return ClearMemoriesResponse(
        cleared=cleared,
        message="All memories cleared." if cleared else "Clear operation failed.",
    )
