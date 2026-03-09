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
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.agent.orchestrator import Orchestrator
from app.api.deps import check_rate_limit
from app.config import settings
from app.database import async_session, get_db
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


def _get_auth_service(request: Request) -> AuthService:
    """FastAPI dependency that retrieves the shared AuthService."""
    return request.app.state.auth_service


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
        await websocket.close(code=4001, reason="Missing auth token")
        return None

    try:
        user = await auth_service.get_user(token)
        return user
    except HTTPException:
        await websocket.close(code=4003, reason="Invalid or expired token")
        return None


async def _transcribe_audio(content: bytes, filename: str) -> str:
    """Transcribe audio bytes via OpenAI Whisper.

    Args:
        content: Raw audio file bytes.
        filename: Original filename for the Whisper API.

    Returns:
        The transcription text, or a fallback message on failure.
    """
    if not settings.openai_api_key:
        return "[Voice note — transcription unavailable]"
    try:
        from openai import AsyncOpenAI  # noqa: PLC0415

        client = AsyncOpenAI(api_key=settings.openai_api_key)
        transcription = await client.audio.transcriptions.create(
            model="whisper-1",
            file=(filename, content),
            response_format="text",
        )
        return str(transcription).strip()
    except Exception:
        logger.exception("Whisper transcription failed for '%s'", filename)
        return "[Voice note — transcription failed]"


async def _process_attachments(
    attachments: list[dict],
    storage_service: StorageService,
) -> str:
    """Process attachments and return text to augment the user message.

    Audio attachments are downloaded and transcribed via Whisper.
    Image attachments are noted as metadata for the LLM.

    Args:
        attachments: List of attachment dicts from the client.
        storage_service: Storage service for downloading files.

    Returns:
        Combined text fragments to append to the user message.
    """
    parts: list[str] = []
    for att in attachments:
        if att.get("type") == "audio" and att.get("storage_path"):
            bucket, _, obj_path = att["storage_path"].partition("/")
            audio_bytes = await storage_service.download_file(bucket, obj_path)
            if audio_bytes:
                transcription = await _transcribe_audio(
                    audio_bytes,
                    att.get("filename", "voice_note"),
                )
                parts.append(f"[Voice note transcription]: {transcription}")
            else:
                parts.append("[Voice note — could not download audio]")
        elif att.get("type") == "image":
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


async def _load_user_preferences(db: AsyncSession, user_id: str) -> tuple[str, str]:
    """Load the user's coach persona and proactivity preferences.

    Args:
        db: Async database session.
        user_id: The authenticated user's ID.

    Returns:
        A (persona, proactivity) tuple; defaults to ("balanced", "medium").
    """
    try:
        result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
        prefs = result.scalar_one_or_none()
        if prefs:
            return (prefs.coach_persona or "balanced", prefs.proactivity_level or "medium")
    except Exception as e:  # noqa: BLE001
        logger.warning("Failed to load user preferences for user %s: %s", user_id, e)
    return ("balanced", "medium")


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

    # ── Auth ──────────────────────────────────────────────────────────────────
    user = await _authenticate_ws(websocket, auth_service, token)
    if user is None:
        return

    user_id: str = user.get("id", "unknown")

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

    await websocket.accept()
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
                extra_context = await _process_attachments(raw_attachments, storage_service)
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
                # Remove the last entry if it matches the current user message
                # (to avoid passing it twice — it will be passed as `message`).
                if history and history[-1]["role"] == "user" and history[-1]["content"] == message_text:
                    history = history[:-1]

                db_persona, db_proactivity = await _load_user_preferences(db, user_id)
                # Client-supplied values (from user settings at send time) take
                # precedence; fall back to DB preferences when absent.
                persona = data.get("persona") or db_persona
                proactivity = data.get("proactivity") or db_proactivity

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


@router.get("/history")
async def get_chat_history(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    storage_service: StorageService = Depends(_get_storage_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Retrieve chat history for the authenticated user.

    Returns all non-deleted conversations and their messages, ordered by
    most recent conversation first, messages chronologically.
    Attachment signed URLs are refreshed on each request.

    Args:
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
        .order_by(Conversation.updated_at.desc(), Conversation.created_at.desc())
    )
    conversations = result.scalars().all()

    history = []
    for conv in conversations:
        msg_result = await db.execute(
            select(Message).where(Message.conversation_id == conv.id).order_by(Message.created_at.asc())
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


@router.get("/conversations")
async def list_conversations(
    include_archived: bool = Query(default=False),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """List all conversations for the authenticated user.

    Returns non-deleted conversations ordered newest (by last activity) first.
    Each entry includes a message count and a preview snippet (the last message,
    truncated to 100 characters).

    Args:
        include_archived: When True, include archived conversations.
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

    stmt = select(Conversation).where(
        Conversation.user_id == user_id,
        Conversation.deleted_at.is_(None),
    )
    if not include_archived:
        stmt = stmt.where(Conversation.archived.is_(False))

    stmt = stmt.order_by(
        Conversation.updated_at.desc(),
        Conversation.created_at.desc(),
    )

    result = await db.execute(stmt)
    conversations = result.scalars().all()

    output = []
    for conv in conversations:
        msg_result = await db.execute(
            select(Message).where(Message.conversation_id == conv.id).order_by(Message.created_at.desc())
        )
        messages = msg_result.scalars().all()

        message_count = len(messages)
        preview_snippet: str | None = None
        if messages:
            last_body = messages[0].content or ""
            preview_snippet = last_body[:100]

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


@router.get("/conversations/{conversation_id}/messages")
async def get_conversation_messages(
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

    title: str | None = None
    archived: bool | None = None


@router.patch("/conversations/{conversation_id}")
async def update_conversation(
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
        conv.archived = body.archived

    await db.commit()
    await db.refresh(conv)

    created = conv.created_at
    updated = conv.updated_at or conv.created_at
    return {
        "id": conv.id,
        "title": conv.title,
        "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created),
        "updated_at": updated.isoformat() if hasattr(updated, "isoformat") else str(updated),
        "archived": conv.archived,
    }


@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(
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

    conv.deleted_at = datetime.now(timezone.utc)  # type: ignore[assignment]
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
