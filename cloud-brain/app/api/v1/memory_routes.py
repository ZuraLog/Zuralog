"""
Zuralog Cloud Brain — Memory Management API.

RESTful endpoints that allow authenticated users to inspect and manage
their long-term AI memory — the context the AI Agent uses to personalise
coaching responses.  These routes back the "Privacy & Data" settings
screen in the mobile app.

Endpoints:
    GET  /api/v1/memories          — list all memories for the authenticated user
    DELETE /api/v1/memories/{id}   — delete a single memory by ID
    DELETE /api/v1/memories        — clear ALL memories (requires confirmation header)

Security:
    - All endpoints require a valid JWT via ``get_authenticated_user_id``.
    - Bulk deletion requires the ``X-Confirm-Clear: true`` header to
      prevent accidental data loss from mis-fired DELETE requests.
    - The memory store is accessed via ``request.app.state.memory_store``
      so the production Pinecone store can be swapped with the in-memory
      stub during tests without touching route code.
"""

from __future__ import annotations

import logging

import sentry_sdk
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import BaseModel

from app.api.v1.deps import get_authenticated_user_id

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class MemoryEntryResponse(BaseModel):
    """Serialised representation of a single memory entry.

    Attributes:
        id: Unique memory identifier.
        text: The stored memory text.
        metadata: Arbitrary key-value pairs attached to the memory.
        score: Similarity score if the entry was returned by a query
            (None when fetched via ``list_memories``).
    """

    id: str
    text: str
    metadata: dict
    score: float | None = None

    model_config = {"from_attributes": True}


class DeleteMemoryResponse(BaseModel):
    """Response returned after a single memory deletion.

    Attributes:
        deleted: Whether the deletion was executed.
        memory_id: The ID of the memory that was targeted.
    """

    deleted: bool
    memory_id: str


class ClearMemoriesResponse(BaseModel):
    """Response returned after clearing all user memories.

    Attributes:
        cleared: Whether the operation was executed successfully.
        count: Number of memories deleted.
    """

    cleared: bool
    count: int


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "memory")


router = APIRouter(
    prefix="/memories",
    tags=["memories"],
    dependencies=[Depends(_set_sentry_module)],
)


# ---------------------------------------------------------------------------
# GET /memories — list all memories
# ---------------------------------------------------------------------------


@router.get("", response_model=list[MemoryEntryResponse])
async def list_memories(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> list[MemoryEntryResponse]:
    """List all AI memories stored for the authenticated user.

    Retrieves every memory entry from the user's personal namespace in
    the backing vector store (Pinecone in production, in-memory in dev).
    Results are not semantically ranked — use the AI chat endpoint for
    context-aware retrieval.

    Args:
        request: The incoming FastAPI request; used to access
            ``app.state.memory_store``.
        user_id: Authenticated user ID injected by the JWT dependency.

    Returns:
        A list of :class:`MemoryEntryResponse` objects.  Returns an
        empty list if the user has no stored memories or the store is
        disabled.

    Raises:
        HTTPException: 503 if the memory store is not configured on
            ``app.state``.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    memory_store = getattr(request.app.state, "memory_store", None)
    if memory_store is None:
        logger.error("list_memories: app.state.memory_store is not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Memory service is not available",
        )

    # Support both PineconeMemoryStore (list_memories) and InMemoryStore (query)
    if hasattr(memory_store, "list_memories"):
        entries = await memory_store.list_memories(user_id)
        return [
            MemoryEntryResponse(
                id=e.id,
                text=e.text,
                metadata=e.metadata,
                score=e.score,
            )
            for e in entries
        ]

    # Fallback for InMemoryStore: query with empty string to return recent entries
    raw_entries = await memory_store.query(user_id, query_text="", limit=1000)
    return [
        MemoryEntryResponse(
            id=str(idx),
            text=entry.get("text", ""),
            metadata=entry.get("metadata", {}),
            score=None,
        )
        for idx, entry in enumerate(raw_entries)
    ]


# ---------------------------------------------------------------------------
# DELETE /memories/{memory_id} — delete a single memory
# ---------------------------------------------------------------------------


@router.delete("/{memory_id}", response_model=DeleteMemoryResponse)
async def delete_memory(
    memory_id: str,
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> DeleteMemoryResponse:
    """Delete a single AI memory by its ID.

    Removes the specified memory from the user's personal namespace.
    Only memories belonging to the authenticated user can be deleted —
    the user-scoped namespace prevents cross-user access.

    Args:
        memory_id: The UUID string of the memory to delete.
        request: The incoming FastAPI request.
        user_id: Authenticated user ID injected by the JWT dependency.

    Returns:
        :class:`DeleteMemoryResponse` with ``deleted=True`` on success.

    Raises:
        HTTPException: 503 if the memory store is not configured.
        HTTPException: 404 if the memory store reports the ID was not found.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    memory_store = getattr(request.app.state, "memory_store", None)
    if memory_store is None:
        logger.error("delete_memory: app.state.memory_store is not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Memory service is not available",
        )

    if not hasattr(memory_store, "delete_memory"):
        # InMemoryStore stub does not support deletion
        logger.warning(
            "delete_memory: store does not support delete_memory — no-op for user '%s'",
            user_id,
        )
        return DeleteMemoryResponse(deleted=False, memory_id=memory_id)

    success = await memory_store.delete_memory(user_id, memory_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Memory '{memory_id}' not found or could not be deleted",
        )

    logger.info("delete_memory: user '%s' deleted memory '%s'", user_id, memory_id)
    return DeleteMemoryResponse(deleted=True, memory_id=memory_id)


# ---------------------------------------------------------------------------
# DELETE /memories — clear all memories
# ---------------------------------------------------------------------------


@router.delete("", response_model=ClearMemoriesResponse)
async def clear_memories(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    x_confirm_clear: str | None = Header(
        default=None,
        alias="X-Confirm-Clear",
        description="Must be 'true' to authorise bulk deletion",
    ),
) -> ClearMemoriesResponse:
    """Clear ALL AI memories for the authenticated user.

    This is a destructive, irreversible operation.  The caller must
    include the ``X-Confirm-Clear: true`` header to confirm intent.
    Without this header the endpoint returns ``400 Bad Request``.

    Args:
        request: The incoming FastAPI request.
        user_id: Authenticated user ID injected by the JWT dependency.
        x_confirm_clear: Must be the string ``"true"`` (case-insensitive)
            to authorise the bulk deletion.

    Returns:
        :class:`ClearMemoriesResponse` with the number of memories deleted.

    Raises:
        HTTPException: 400 if the confirmation header is absent or not
            equal to ``"true"``.
        HTTPException: 503 if the memory store is not configured.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    if not x_confirm_clear or x_confirm_clear.lower() != "true":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=("Bulk deletion requires the 'X-Confirm-Clear: true' header. This action is irreversible."),
        )

    memory_store = getattr(request.app.state, "memory_store", None)
    if memory_store is None:
        logger.error("clear_memories: app.state.memory_store is not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Memory service is not available",
        )

    if not hasattr(memory_store, "clear_memories"):
        logger.warning(
            "clear_memories: store does not support clear_memories — no-op for user '%s'",
            user_id,
        )
        return ClearMemoriesResponse(cleared=False, count=0)

    count = await memory_store.clear_memories(user_id)
    logger.info(
        "clear_memories: user '%s' cleared %d memories",
        user_id,
        count,
    )
    return ClearMemoriesResponse(cleared=True, count=count)
