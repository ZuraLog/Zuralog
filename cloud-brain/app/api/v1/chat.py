"""
Zuralog Cloud Brain — Chat API Router.

WebSocket endpoint for real-time AI chat streaming and REST endpoints
for chat history retrieval and conversation management. Handles
authentication, message routing through the Orchestrator, and message
persistence.

WebSocket Protocol (server → client):
  - {"type": "conversation_init", "conversation_id": str}  — sent once on connect
  - {"type": "typing_start"}                               — AI is processing
  - {"type": "tool_start", "tool_name": str}               — tool executing
  - {"type": "tool_end",   "tool_name": str}               — tool done
  - {"type": "stream_token", "content": str}               — partial token
  - {"type": "stream_end",   "content": str,
     "message_id": str, "conversation_id": str,
     "client_action": dict|null}                           — final response
  - {"type": "error", "content": str}                      — error

WebSocket Protocol (client → server):
  - {"message": str, "attachments": [...], "persona": str, "proactivity": str}
"""

import logging
from datetime import datetime, timezone
from typing import Any

import sentry_sdk
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    Response,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.agent.orchestrator import Orchestrator
from app.api.deps import _get_auth_service, check_rate_limit
from app.database import async_session, get_db
from app.limiter import limiter
from app.models.conversation import Conversation, Message
from app.models.user_preferences import UserPreferences
from app.services.auth_service import AuthService
from app.services.rate_limiter import RateLimiter
from app.services.storage_service import StorageService
from app.services.usage_tracker import UsageTracker

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "chat")


router = APIRouter(
    prefix="/chat",
    tags=["chat"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


def _get_storage_service(request: Request) -> StorageService:
    """FastAPI dependency that retrieves the shared StorageService."""
    return request.app.state.storage_service


async def _authenticate_ws(
    websocket: WebSocket,
    auth_service: AuthService,
    token: str | None,
) -> dict | None:
    """Validates a WebSocket connection token via Supabase Auth.

    Args:
        websocket: The WebSocket connection to accept or reject.
        auth_service: The shared auth service for token validation.
        token: JWT access token from the query parameter.

    Returns:
        The user data dict on success, or None on failure.
    """
    if not token:
        await websocket.send_json({"type": "error", "content": "Missing auth token"})
        await websocket.close(code=4001, reason="Missing auth token")
        return None

    try:
        user = await auth_service.get_user(token)
        return user
    except HTTPException:
        await websocket.send_json({"type": "error", "content": "Invalid or expired token"})
        await websocket.close(code=4003, reason="Invalid or expired token")
        return None


def _process_attachments(attachments: list[dict]) -> str:
    """Process attachments and return text to augment the user message.

    Image attachments are noted as metadata for the LLM.

    Args:
        attachments: List of attachment dicts from the client.

    Returns:
        Combined text fragments to append to the user message.
    """
    parts: list[str] = []
    for att in attachments:
        if att.get("type") == "image":
            parts.append(f"[User attached image: {att.get('filename', 'image')}]")
    return "\n".join(parts)


async def _refresh_attachment_urls(
    attachments: list[dict] | None,
    storage_service: StorageService,
) -> list[dict] | None:
    """Generate fresh signed URLs for message attachments.

    Args:
        attachments: Stored attachment metadata from the DB.
        storage_service: Storage service for generating signed URLs.

    Returns:
        The attachment list with refreshed signed_url fields.
    """
    if not attachments:
        return attachments
    refreshed = []
    for att in attachments:
        updated = dict(att)
        if att.get("storage_path"):
            bucket, _, obj_path = att["storage_path"].partition("/")
            updated["signed_url"] = await storage_service.get_signed_url(bucket, obj_path)
        refreshed.append(updated)
    return refreshed


def _message_to_dict(msg: Message) -> dict[str, Any]:
    """Serialise a Message ORM object to a response dict.

    Args:
        msg: The SQLAlchemy Message instance.

    Returns:
        A dict suitable for JSON serialisation.
    """
    created = msg.created_at
    return {
        "id": msg.id,
        "role": msg.role,
        "content": msg.content,
        "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created),
        "attachments": msg.attachments or [],
    }


async def _load_conversation_history(
    db: AsyncSession,
    conversation_id: str,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """Load recent messages for LLM context injection.

    Fetches the last ``limit`` messages for the given conversation, ordered
    oldest-first, and maps them to the OpenAI message format.

    Args:
        db: Async database session.
        conversation_id: The conversation to fetch history for.
        limit: Maximum number of messages to load (caps token usage).

    Returns:
        A list of ``{"role": str, "content": str}`` dicts.
    """
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.asc())
        .limit(limit)
    )
    messages = result.scalars().all()
    # Only pass user/assistant roles to the LLM; skip tool/system rows.
    return [{"role": m.role, "content": m.content or ""} for m in messages if m.role in ("user", "assistant")]


async def _load_user_preferences(db: AsyncSession, user_id: str) -> tuple[str, str, str]:
    """Load the user's coach persona, proactivity, and response_length preferences.

    Args:
        db: Async database session.
        user_id: The authenticated user's ID.

    Returns:
        A (persona, proactivity, response_length) tuple;
        defaults to ("balanced", "medium", "concise").
    """
    try:
        result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
        prefs = result.scalar_one_or_none()
        if prefs:
            response_length = getattr(prefs, "response_length", None) or "concise"
            return (prefs.coach_persona or "balanced", prefs.proactivity_level or "medium", response_length)
    except Exception as e:  # noqa: BLE001
        logger.warning("Failed to load user preferences for user %s: %s", user_id, e)
    return ("balanced", "medium", "concise")


# ---------------------------------------------------------------------------
# WebSocket — real-time AI chat with streaming
# ---------------------------------------------------------------------------


@router.websocket("/ws")
async def websocket_chat(
    websocket: WebSocket,
    token: str | None = Query(default=None),
    conversation_id: str | None = Query(default=None, alias="conversation_id"),
) -> None:
    """WebSocket endpoint for real-time AI chat with token streaming.

    On connect:
      1. Validates the JWT token.
      2. Resolves or creates the conversation (returns its UUID to the client).
      3. Enters a message loop: receives user messages, runs them through
         the Orchestrator with streaming, persists both messages, and updates
         the conversation title on first exchange.

    Args:
        websocket: The WebSocket connection.
        token: JWT access token (query param).
        conversation_id: Optional existing conversation UUID (query param).
            If omitted, a new conversation is created and its ID is returned
            in the ``conversation_init`` message.
    """
    app = websocket.app
    auth_service: AuthService = app.state.auth_service
    mcp_client: MCPClient = app.state.mcp_client
    memory_store: MemoryStore = app.state.memory_store
    llm_client: LLMClient = app.state.llm_client
    rate_limiter: RateLimiter | None = getattr(app.state, "rate_limiter", None)
    analytics = getattr(app.state, "analytics_service", None)
    storage_service: StorageService = app.state.storage_service

    # Accept immediately so all failure paths can send JSON error messages
    # instead of closing an unaccepted socket (which causes HTTP 500).
    await websocket.accept()

    user_id: str = "unknown"

    # ── Auth ──────────────────────────────────────────────────────────────────
    user = await _authenticate_ws(websocket, auth_service, token)
    if user is None:
        return

    user_id = user.get("id", "unknown")

    # ── Resolve / create conversation ─────────────────────────────────────────
    resolved_conv_id: str
    is_new_conversation = False

    async with async_session() as db:
        if conversation_id:
            result = await db.execute(
                select(Conversation).where(
                    Conversation.id == conversation_id,
                    Conversation.user_id == user_id,
                    Conversation.deleted_at.is_(None),
                )
            )
            conv = result.scalar_one_or_none()
            if conv is None:
                await websocket.send_json({"type": "error", "content": "Conversation not found"})
                await websocket.close(code=4004, reason="Conversation not found")
                return
            resolved_conv_id = conv.id
        else:
            conv = Conversation(user_id=user_id)
            db.add(conv)
            await db.commit()
            await db.refresh(conv)
            resolved_conv_id = conv.id
            is_new_conversation = True

    logger.info(
        "WebSocket connected for user '%s', conversation '%s' (new=%s)",
        user_id,
        resolved_conv_id,
        is_new_conversation,
    )

    # Send conversation ID immediately so the client can update its route.
    await websocket.send_json({"type": "conversation_init", "conversation_id": resolved_conv_id})

    # ── Message loop ──────────────────────────────────────────────────────────
    try:
        while True:
            data = await websocket.receive_json()
            message_text: str = data.get("message", "")
            raw_attachments: list[dict] | None = data.get("attachments")
            is_regenerate: bool = bool(data.get("regenerate", False))

            if not message_text and not raw_attachments:
                await websocket.send_json({"type": "error", "content": "Empty message"})
                continue

            # ── Rate limiting ─────────────────────────────────────────────────
            if rate_limiter:
                try:
                    async with async_session() as db:
                        await check_rate_limit(user, rate_limiter, db)
                except HTTPException as exc:
                    if exc.status_code == 429:
                        await websocket.send_json({"type": "error", "content": exc.detail or "Rate limit exceeded"})
                        continue
                    raise

            # ── Analytics ─────────────────────────────────────────────────────
            if analytics:
                analytics.capture(
                    distinct_id=user_id,
                    event="chat_message_sent",
                    properties={
                        "message_length": len(message_text),
                        "conversation_id": resolved_conv_id,
                    },
                )

            # ── Attachment processing ─────────────────────────────────────────
            augmented_text = message_text
            if raw_attachments:
                extra_context = _process_attachments(raw_attachments)
                if extra_context:
                    augmented_text = f"{message_text}\n\n{extra_context}" if message_text else extra_context

            # ── Persist user message ──────────────────────────────────────────
            # When regenerating, the user message is already in the DB from the
            # original send — skip inserting a duplicate.
            async with async_session() as db:
                if not is_regenerate:
                    user_msg = Message(
                        conversation_id=resolved_conv_id,
                        role="user",
                        content=message_text,
                        attachments=raw_attachments or None,
                    )
                    db.add(user_msg)
                    await db.commit()

                # Load conversation history for LLM context.
                history = await _load_conversation_history(db, resolved_conv_id, limit=50)

                # If regenerate was requested but there is no history, treat it
                # as a first message to avoid sending an empty conversation to the LLM.
                if is_regenerate and not history:
                    is_regenerate = False
                    user_msg = Message(
                        conversation_id=resolved_conv_id,
                        role="user",
                        content=message_text,
                        attachments=raw_attachments or None,
                    )
                    db.add(user_msg)
                    await db.commit()
                    await db.refresh(user_msg)
                # Remove the last entry if it matches the current user message
                # (to avoid passing it twice — it will be passed as `message`).
                if history and history[-1]["role"] == "user" and history[-1]["content"] == message_text:
                    history = history[:-1]

                db_persona, db_proactivity, db_response_length = await _load_user_preferences(db, user_id)
                # Client-supplied values (from user settings at send time) take
                # precedence; fall back to DB preferences when absent.
                persona = data.get("persona") or db_persona
                proactivity = data.get("proactivity") or db_proactivity
                _VALID_RESPONSE_LENGTHS = {"concise", "detailed"}
                client_response_length = data.get("response_length")
                response_length = client_response_length if client_response_length in _VALID_RESPONSE_LENGTHS else db_response_length

            # ── Orchestrate with streaming ────────────────────────────────────
            await websocket.send_json({"type": "typing_start"})

            async with async_session() as db:
                usage_tracker = UsageTracker(session=db)
                orchestrator = Orchestrator(
                    mcp_client=mcp_client,
                    memory_store=memory_store,
                    llm_client=llm_client,
                    usage_tracker=usage_tracker,
                )

                full_content = ""
                client_action = None
                had_error = False

                try:
                    async for event in orchestrator.process_message_stream(
                        user_id=user_id,
                        message=augmented_text,
                        persona=persona,
                        proactivity=proactivity,
                        response_length=response_length,
                        db=db,
                        conversation_history=history,
                    ):
                        etype = event.get("type")

                        if etype in ("tool_start", "tool_end"):
                            await websocket.send_json(event)

                        elif etype == "stream_token":
                            full_content += event["content"]
                            await websocket.send_json(event)

                        elif etype == "stream_end":
                            full_content = event.get("content", full_content)
                            client_action = event.get("client_action")

                        elif etype == "error":
                            had_error = True
                            await websocket.send_json(event)
                            break

                except Exception as orch_exc:
                    logger.exception("Orchestrator stream error for user '%s'", user_id)
                    sentry_sdk.capture_exception(orch_exc)
                    await websocket.send_json({"type": "error", "content": f"Processing error: {orch_exc!s}"})
                    continue

                if had_error:
                    continue

            # ── Persist assistant message ─────────────────────────────────────
            async with async_session() as db:
                assistant_msg = Message(
                    conversation_id=resolved_conv_id,
                    role="assistant",
                    content=full_content,
                )
                db.add(assistant_msg)

                # Update conversation.updated_at and auto-generate title.
                conv_result = await db.execute(select(Conversation).where(Conversation.id == resolved_conv_id))
                conv_row = conv_result.scalar_one_or_none()
                if conv_row:
                    conv_row.updated_at = datetime.now(timezone.utc)

                    # Generate title on the first exchange.
                    if conv_row.title is None and message_text:
                        try:
                            title_orchestrator = Orchestrator(
                                mcp_client=mcp_client,
                                memory_store=memory_store,
                                llm_client=llm_client,
                            )
                            conv_row.title = await title_orchestrator.generate_title(message_text)
                        except Exception:
                            conv_row.title = message_text[:60] + ("…" if len(message_text) > 60 else "")

                await db.commit()
                await db.refresh(assistant_msg)
                assistant_msg_id = assistant_msg.id

            # ── Analytics ─────────────────────────────────────────────────────
            if analytics:
                analytics.capture(
                    distinct_id=user_id,
                    event="chat_response_received",
                    properties={
                        "response_length": len(full_content),
                        "had_client_action": client_action is not None,
                        "conversation_id": resolved_conv_id,
                    },
                )

            # ── Final stream_end with persisted IDs ───────────────────────────
            final_payload: dict[str, Any] = {
                "type": "stream_end",
                "content": full_content,
                "message_id": assistant_msg_id,
                "conversation_id": resolved_conv_id,
            }
            if client_action is not None:
                final_payload["client_action"] = client_action
            await websocket.send_json(final_payload)

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected for user '%s'", user_id)
    except Exception:
        logger.exception("Unexpected WebSocket error for user '%s'", user_id)


# ---------------------------------------------------------------------------
# REST — conversation list, messages, history, management
# ---------------------------------------------------------------------------


@limiter.limit("60/minute")
@router.get("/history")
async def get_chat_history(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100, description="Maximum number of conversations to return"),
    offset: int = Query(default=0, ge=0, description="Number of conversations to skip"),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    storage_service: StorageService = Depends(_get_storage_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Retrieve chat history for the authenticated user.

    Returns non-deleted conversations and their messages, ordered by most recent
    conversation first, messages chronologically. Supports pagination via
    ``limit`` (max 100, default 20) and ``offset``. Attachment signed URLs are
    refreshed on each request.

    Args:
        limit: Maximum number of conversations to return (1–100).
        offset: Number of conversations to skip (for pagination).
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        storage_service: Injected storage service for signed URLs.
        db: Injected async database session.

    Returns:
        A list of conversation dicts, each containing a list of messages.

    Raises:
        HTTPException: 401 if the token is invalid.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")

    result = await db.execute(
        select(Conversation)
        .where(
            Conversation.user_id == user_id,
            Conversation.deleted_at.is_(None),
        )
        .options(selectinload(Conversation.messages))
        .order_by(Conversation.updated_at.desc(), Conversation.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    conversations = result.scalars().unique().all()

    history = []
    for conv in conversations:
        # messages are already loaded via selectinload — no extra DB query
        messages = sorted(conv.messages, key=lambda m: m.created_at)

        msg_dicts = []
        for msg in messages:
            msg_dict = _message_to_dict(msg)
            if msg.attachments:
                msg_dict["attachments"] = await _refresh_attachment_urls(
                    msg.attachments,
                    storage_service,
                )
            msg_dicts.append(msg_dict)

        created = conv.created_at
        updated = conv.updated_at or conv.created_at
        history.append(
            {
                "id": conv.id,
                "title": conv.title,
                "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created),
                "updated_at": updated.isoformat() if hasattr(updated, "isoformat") else str(updated),
                "archived": conv.archived,
                "messages": msg_dicts,
            }
        )

    return history


@limiter.limit("60/minute")
@router.get("/conversations")
async def list_conversations(
    request: Request,
    include_archived: bool = Query(default=False),
    limit: int = Query(default=20, ge=1, le=100, description="Maximum number of conversations to return"),
    offset: int = Query(default=0, ge=0, description="Number of conversations to skip"),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """List all conversations for the authenticated user.

    Returns non-deleted conversations ordered newest (by last activity) first.
    Each entry includes a message count and a preview snippet (the last message,
    truncated to 100 characters). Supports pagination via ``limit`` (max 100,
    default 20) and ``offset``.

    Args:
        include_archived: When True, include archived conversations.
        limit: Maximum number of conversations to return (1–100).
        offset: Number of conversations to skip (for pagination).
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        A list of conversation summary dicts.

    Raises:
        HTTPException: 401 if the token is invalid.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")

    # Correlated subquery: count of messages per conversation
    msg_count_subq = (
        select(func.count(Message.id))
        .where(Message.conversation_id == Conversation.id)
        .correlate(Conversation)
        .scalar_subquery()
        .label("message_count")
    )

    # Correlated subquery: content of the most recent message (preview)
    last_msg_subq = (
        select(Message.content)
        .where(Message.conversation_id == Conversation.id)
        .correlate(Conversation)
        .order_by(Message.created_at.desc())
        .limit(1)
        .scalar_subquery()
        .label("preview_snippet")
    )

    stmt = select(Conversation, msg_count_subq, last_msg_subq).where(
        Conversation.user_id == user_id,
        Conversation.deleted_at.is_(None),
    )
    if not include_archived:
        stmt = stmt.where(Conversation.archived.is_(False))
    stmt = (
        stmt.order_by(
            Conversation.updated_at.desc(),
            Conversation.created_at.desc(),
        )
        .limit(limit)
        .offset(offset)
    )

    result = await db.execute(stmt)
    rows = result.all()

    output = []
    for conv, message_count, preview_raw in rows:
        preview_snippet: str | None = preview_raw[:100] if preview_raw else None
        created = conv.created_at
        updated = conv.updated_at or conv.created_at
        output.append(
            {
                "id": conv.id,
                "title": conv.title,
                "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created),
                "updated_at": updated.isoformat() if hasattr(updated, "isoformat") else str(updated),
                "archived": conv.archived,
                "message_count": message_count,
                "preview_snippet": preview_snippet,
            }
        )

    return output


@limiter.limit("60/minute")
@router.get("/conversations/{conversation_id}/messages")
async def get_conversation_messages(
    request: Request,
    conversation_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    storage_service: StorageService = Depends(_get_storage_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Return all messages for a specific conversation.

    Validates that the authenticated user owns the conversation.
    Attachment signed URLs are refreshed on each request.

    Args:
        conversation_id: The UUID of the conversation.
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        storage_service: Injected storage service for signed URLs.
        db: Injected async database session.

    Returns:
        A list of message dicts ordered chronologically.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 404 if the conversation does not exist or belongs
            to a different user.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")

    conv_result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
            Conversation.deleted_at.is_(None),
        )
    )
    conv = conv_result.scalar_one_or_none()
    if conv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    msg_result = await db.execute(
        select(Message).where(Message.conversation_id == conversation_id).order_by(Message.created_at.asc())
    )
    messages = msg_result.scalars().all()

    msg_dicts = []
    for msg in messages:
        msg_dict = _message_to_dict(msg)
        if msg.attachments:
            msg_dict["attachments"] = await _refresh_attachment_urls(
                msg.attachments,
                storage_service,
            )
        msg_dicts.append(msg_dict)

    return msg_dicts


# ---------------------------------------------------------------------------
# Conversation Management
# ---------------------------------------------------------------------------


class ConversationUpdateRequest(BaseModel):
    """Request body for renaming or archiving a conversation.

    Attributes:
        title: Optional new title for the conversation.
        archived: Optional flag to archive the conversation.
    """

    title: str | None = Field(default=None, max_length=200)
    archived: bool | None = None


@limiter.limit("30/minute")
@router.patch("/conversations/{conversation_id}")
async def update_conversation(
    request: Request,
    conversation_id: str,
    body: ConversationUpdateRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Rename or archive a conversation.

    Only the owner of the conversation may modify it.

    Args:
        conversation_id: The UUID of the conversation to update.
        body: Fields to update — ``title`` and/or ``archived``.
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        The updated conversation dict.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 404 if the conversation does not exist or belongs
            to a different user.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")

    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
            Conversation.deleted_at.is_(None),
        )
    )
    conv = result.scalar_one_or_none()

    if conv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    if body.title is not None:
        conv.title = body.title

    if body.archived is not None:
        try:
            conv.archived = body.archived
        except AttributeError:
            logger.warning(
                "update_conversation: 'archived' attribute missing on conversation %s — skipping",
                conversation_id,
            )

    await db.commit()
    await db.refresh(conv)

    created = conv.created_at
    try:
        updated = conv.updated_at or conv.created_at
    except AttributeError:
        updated = conv.created_at
    try:
        archived = conv.archived
    except AttributeError:
        archived = None
    return {
        "id": conv.id,
        "title": conv.title,
        "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created),
        "updated_at": updated.isoformat() if hasattr(updated, "isoformat") else str(updated),
        "archived": archived,
    }


@limiter.limit("30/minute")
@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(
    request: Request,
    conversation_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft-delete a conversation.

    Sets ``deleted_at`` to the current UTC timestamp. Only the owner may delete.

    Args:
        conversation_id: The UUID of the conversation to delete.
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        204 No Content on success.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 404 if the conversation does not exist or belongs
            to a different user.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")

    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
            Conversation.deleted_at.is_(None),
        )
    )
    conv = result.scalar_one_or_none()

    if conv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    try:
        conv.deleted_at = datetime.now(timezone.utc)  # type: ignore[assignment]
    except AttributeError:
        # Fallback: soft-delete via archived flag when deleted_at column is absent.
        logger.warning(
            "delete_conversation: 'deleted_at' attribute missing on conversation %s — falling back to archived=True",
            conversation_id,
        )
        try:
            conv.archived = True
        except AttributeError:
            logger.warning(
                "delete_conversation: 'archived' attribute also missing on conversation %s — no soft-delete applied",
                conversation_id,
            )
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
