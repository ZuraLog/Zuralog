"""
Zuralog Cloud Brain — Conversation Management Router.

CRUD endpoints for the conversation list — list, rename, and delete.
This file extends the conversation surface WITHOUT modifying chat.py.

Implemented (Phase 2):
    GET    /conversations        — list all conversations with message count and preview
    PATCH  /conversations/{id}  — rename (update title)
    DELETE /conversations/{id}  — hard delete (cascades to messages via FK)

Deferred (Phase 8 — requires migration for new columns):
    is_archived (bool) — soft-archive without deletion
    deleted_at  (DateTime) — soft-delete tombstone

Schema note:
    The Conversation model (app.models.conversation) currently has:
        id, user_id, title, created_at, updated_at
    Phase 8 should add is_archived and deleted_at via an Alembic migration.
    Until then, DELETE is a hard delete and there is no archive endpoint.

Auth:
    All routes use get_authenticated_user_id (Bearer JWT via Supabase).
    Ownership is enforced at the query level — users can only see/mutate
    their own conversations; 403 is returned for cross-user attempts on
    PATCH / DELETE.
"""

import logging
from datetime import datetime, timezone

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.conversation import Conversation, Message

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class ConversationSummary(BaseModel):
    """Summary row returned in the conversation list.

    Attributes:
        id: Conversation UUID.
        title: User-set or auto-generated title. May be None.
        created_at: UTC creation timestamp.
        updated_at: UTC last-updated timestamp. None if never updated.
        message_count: Total number of messages in the conversation.
        preview: Last message snippet, max 100 chars. None for empty conversations.
    """

    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str | None
    created_at: datetime
    updated_at: datetime | None
    message_count: int
    preview: str | None


class ConversationListResponse(BaseModel):
    """Paginated conversation list.

    Attributes:
        total: Total matching conversations.
        limit: Requested page size.
        offset: Requested page offset.
        items: Conversations for this page.
    """

    total: int
    limit: int
    offset: int
    items: list[ConversationSummary]


class ConversationPatchRequest(BaseModel):
    """Request body for renaming a conversation.

    Only ``title`` is mutable in Phase 2. Providing a None value clears
    the title (falls back to the AI-generated placeholder in the app).

    Attributes:
        title: New conversation title. Pass ``None`` to clear.
    """

    title: str | None = None


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "conversations")


router = APIRouter(
    prefix="/conversations",
    tags=["conversations"],
    dependencies=[Depends(_set_sentry_module)],
)


# ---------------------------------------------------------------------------
# GET /conversations
# ---------------------------------------------------------------------------


@router.get(
    "",
    response_model=ConversationListResponse,
    summary="List conversations",
)
async def list_conversations(
    limit: int = Query(default=20, ge=1, le=100, description="Page size"),
    offset: int = Query(default=0, ge=0, description="Page offset"),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> ConversationListResponse:
    """Return paginated list of conversations for the authenticated user.

    Each item includes a message count (via subquery) and a preview
    snippet taken from the last message (max 100 characters).

    Ordered by most-recently-updated first so the active conversation
    sits at the top of the list.

    Args:
        limit: Maximum number of conversations to return (1–100).
        offset: Number of conversations to skip.
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        ConversationListResponse with total count, pagination meta, and items.
    """
    # Total count
    count_stmt = select(func.count()).select_from(Conversation).where(Conversation.user_id == user_id)
    total: int = (await db.execute(count_stmt)).scalar_one()

    # Conversation rows (ordered)
    conv_stmt = (
        select(Conversation)
        .where(Conversation.user_id == user_id)
        .order_by(
            # Prefer updated_at when set, fall back to created_at
            Conversation.updated_at.desc().nulls_last(),
            Conversation.created_at.desc(),
        )
        .offset(offset)
        .limit(limit)
    )
    conversations = (await db.execute(conv_stmt)).scalars().all()

    items: list[ConversationSummary] = []
    for conv in conversations:
        # Message count per conversation
        msg_count_stmt = select(func.count()).select_from(Message).where(Message.conversation_id == conv.id)
        message_count: int = (await db.execute(msg_count_stmt)).scalar_one()

        # Last message for preview
        last_msg_stmt = (
            select(Message.content)
            .where(Message.conversation_id == conv.id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        last_content_row = (await db.execute(last_msg_stmt)).scalar_one_or_none()
        preview: str | None = None
        if last_content_row:
            preview = last_content_row[:100]

        items.append(
            ConversationSummary(
                id=conv.id,
                title=conv.title,
                created_at=conv.created_at,
                updated_at=conv.updated_at,
                message_count=message_count,
                preview=preview,
            )
        )

    return ConversationListResponse(
        total=total,
        limit=limit,
        offset=offset,
        items=items,
    )


# ---------------------------------------------------------------------------
# PATCH /conversations/{conversation_id}
# ---------------------------------------------------------------------------


@router.patch(
    "/{conversation_id}",
    response_model=ConversationSummary,
    summary="Rename a conversation",
)
async def patch_conversation(
    conversation_id: str,
    body: ConversationPatchRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> ConversationSummary:
    """Rename a conversation (update title).

    Passing ``title=None`` clears the title. The ``updated_at`` timestamp
    is set to the current UTC time on every successful PATCH.

    Args:
        conversation_id: UUID of the conversation to update.
        body: Patch payload with optional new title.
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        Updated ConversationSummary.

    Raises:
        HTTPException 404: Conversation not found.
        HTTPException 403: Conversation belongs to a different user.
    """
    stmt = select(Conversation).where(Conversation.id == conversation_id)
    result = await db.execute(stmt)
    conv: Conversation | None = result.scalar_one_or_none()

    if conv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    if conv.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied.",
        )

    conv.title = body.title
    conv.updated_at = datetime.now(tz=timezone.utc)

    await db.commit()
    await db.refresh(conv)

    # Recompute count and preview for the response
    msg_count: int = (
        await db.execute(select(func.count()).select_from(Message).where(Message.conversation_id == conv.id))
    ).scalar_one()

    last_content = (
        await db.execute(
            select(Message.content)
            .where(Message.conversation_id == conv.id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    return ConversationSummary(
        id=conv.id,
        title=conv.title,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        message_count=msg_count,
        preview=last_content[:100] if last_content else None,
    )


# ---------------------------------------------------------------------------
# DELETE /conversations/{conversation_id}
# ---------------------------------------------------------------------------


@router.delete(
    "/{conversation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a conversation",
)
async def delete_conversation(
    conversation_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Hard-delete a conversation and all its messages.

    Messages are cascaded via the ``conversations → messages`` FK
    (``ondelete="CASCADE"``), so they are removed automatically.

    Note: Phase 8 will introduce soft-delete via a ``deleted_at``
    column and a corresponding Alembic migration. Until then this
    is a permanent hard delete.

    Args:
        conversation_id: UUID of the conversation to delete.
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Raises:
        HTTPException 404: Conversation not found.
        HTTPException 403: Conversation belongs to a different user.
    """
    stmt = select(Conversation).where(Conversation.id == conversation_id)
    result = await db.execute(stmt)
    conv: Conversation | None = result.scalar_one_or_none()

    if conv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    if conv.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied.",
        )

    await db.delete(conv)
    await db.commit()
