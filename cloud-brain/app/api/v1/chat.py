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
  - {"type": "thinking_token", "content": str}             — reasoning token
  - {"type": "stream_token", "content": str}               — partial token
  - {"type": "stream_end",   "content": str,
     "message_id": str, "conversation_id": str,
     "client_action": dict|null}                           — final response
  - {"type": "error", "content": str}                      — error

WebSocket Protocol (client → server):
  - {"message": str, "attachments": [...], "persona": str, "proactivity": str}
"""

import asyncio
import json
import logging
import time
from datetime import datetime, timezone
from typing import Annotated, Any

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
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.agent.orchestrator import Orchestrator
from app.api.deps import _get_auth_service, check_rate_limit, get_authenticated_user_id
from app.config import settings
from app.database import async_session, get_db
from app.limiter import limiter
from app.models.conversation import Conversation, Message
from app.models.user import User
from app.models.user_preferences import UserPreferences
from app.services.auth_service import AuthService
from app.services.rate_limiter import RateLimiter
from app.services.storage_service import StorageService
from app.services.usage_tracker import UsageTracker
from app.utils.sanitize import sanitize_for_llm

logger = logging.getLogger(__name__)

# Fix 6.6 (H-2): Allowlist for client-supplied preference values
_VALID_PERSONAS = {"tough_love", "balanced", "gentle"}
_VALID_PROACTIVITY = {"low", "medium", "high"}
_VALID_RESPONSE_LENGTHS = {"concise", "detailed"}

# Fix 6.7 (H-3): History character budget
MAX_HISTORY_CHARS = 40_000


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "chat")


router = APIRouter(
    prefix="/chat",
    tags=["chat"],
    dependencies=[Depends(_set_sentry_module)],
)


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
    Attachment text is sanitized against prompt injection (Fix 6.17 / C-11).

    Args:
        attachments: List of attachment dicts from the client.

    Returns:
        Combined text fragments to append to the user message.
    """
    # Fix 6.15 (M-6): Validate attachment refs and cap count
    if len(attachments) > 3:
        logger.warning("_process_attachments: more than 3 attachments received, truncating to 3")
        attachments = attachments[:3]

    parts: list[str] = []
    for att in attachments:
        # Fix 6.15 (M-6): Validate required fields
        if not isinstance(att, dict):
            logger.warning("_process_attachments: skipping invalid attachment (not a dict)")
            continue
        if not att.get("filename") and not att.get("url") and not att.get("path"):
            logger.warning("_process_attachments: skipping attachment missing filename/url/path")
            continue

        if att.get("type") == "image":
            parts.append(f"[User attached image: {att.get('filename', 'image')}]")
        elif att.get("context_message"):
            # Fix 6.17 (C-11): Sanitize extracted attachment text before LLM injection
            safe_context = sanitize_for_llm(att["context_message"])[:2000]
            parts.append(safe_context)
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
    exclude_message_id: str | None = None,
    user_id: str | None = None,
) -> list[dict[str, Any]]:
    """Load recent messages for LLM context injection.

    Fetches the last ``limit`` messages for the given conversation, ordered
    oldest-first, and maps them to the OpenAI message format.

    Args:
        db: Async database session.
        conversation_id: The conversation to fetch history for.
        limit: Maximum number of messages to load (caps token usage).
        exclude_message_id: If provided, exclude this specific message ID
            (used to avoid passing the just-persisted user message twice).
        user_id: If provided, verify the conversation belongs to this user
            before returning any messages.

    Returns:
        A list of ``{"role": str, "content": str}`` dicts.
    """
    # Ownership verification
    if user_id:
        conv_check = await db.execute(
            select(Conversation.id).where(
                Conversation.id == conversation_id,
                Conversation.user_id == user_id,
            )
        )
        if conv_check.scalar_one_or_none() is None:
            return []

    query = select(Message).where(Message.conversation_id == conversation_id)
    if exclude_message_id is not None:
        query = query.where(Message.id != exclude_message_id)
    query = query.order_by(Message.created_at.desc()).limit(limit)
    result = await db.execute(query)
    messages = result.scalars().all()
    messages = list(reversed(messages))
    # Only pass user/assistant roles to the LLM; skip tool/system rows.
    return [{"role": m.role, "content": (m.content or "")[:8000]} for m in messages if m.role in ("user", "assistant")]


async def _load_user_preferences(db: AsyncSession, user_id: str) -> tuple[str, str, str]:
    """Load the user's coach persona, proactivity, and response_length preferences.

    Args:
        db: Async database session.
        user_id: The authenticated user's ID.

    Returns:
        A (persona, proactivity, response_length) tuple; defaults to ("balanced", "medium", "concise").
    """
    try:
        result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
        prefs = result.scalar_one_or_none()
        if prefs:
            return (
                prefs.coach_persona or "balanced",
                prefs.proactivity_level or "medium",
                prefs.response_length or "concise",
            )
    except Exception as e:  # noqa: BLE001
        logger.warning("Failed to load user preferences for user %s: %s", user_id[:8], e)
    return ("balanced", "medium", "concise")


async def _generate_and_save_title(
    db_url: str,
    conversation_id: str,
    message_text: str,
    mcp_client: MCPClient,
    memory_store: MemoryStore,
    llm_client: LLMClient | None,
) -> None:
    """Generate a conversation title and persist it asynchronously (fire-and-forget).

    Creates its own DB session, generates a title via the Orchestrator's
    lightweight title model, and saves it. Wrapped entirely in try/except
    since failure is non-critical (a fallback truncated title is set before
    this task is created).

    Args:
        db_url: Not used (uses async_session factory directly).
        conversation_id: The conversation to update.
        message_text: The first user message to generate a title from.
        mcp_client: MCP client for Orchestrator construction.
        memory_store: Memory store for Orchestrator construction.
        llm_client: LLM client for Orchestrator construction.
    """
    try:
        title_orchestrator = Orchestrator(
            mcp_client=mcp_client,
            memory_store=memory_store,
            llm_client=llm_client,
        )
        generated_title = await title_orchestrator.generate_title(message_text)
        async with async_session() as db:
            result = await db.execute(select(Conversation).where(Conversation.id == conversation_id))
            conv = result.scalar_one_or_none()
            if conv is not None:
                conv.title = generated_title
                await db.commit()
    except Exception:
        logger.warning("Background title generation failed for conv %s", conversation_id)


# ---------------------------------------------------------------------------
# WebSocket — real-time AI chat with streaming
# ---------------------------------------------------------------------------


@router.websocket("/ws")
async def websocket_chat(
    websocket: WebSocket,
    conversation_id: str | None = Query(default=None, alias="conversation_id"),
) -> None:
    """WebSocket endpoint for real-time AI chat with token streaming.

    On connect:
      1. Reads the first message as an auth frame: {"type":"auth","token":"..."}.
      2. Validates the JWT token from the auth frame.
      3. Resolves or creates the conversation (returns its UUID to the client).
      4. Enters a message loop: receives user messages, runs them through
         the Orchestrator with streaming, persists both messages, and updates
         the conversation title on first exchange.

    Args:
        websocket: The WebSocket connection.
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

    # Fix 6.8 (H-4): Per-user WebSocket connection count limit via Redis
    redis_client: object | None = getattr(websocket.app.state, "redis", None)

    # Accept immediately so all failure paths can send JSON error messages
    # instead of closing an unaccepted socket (which causes HTTP 500).
    await websocket.accept()

    # Fix 6.10 (M-1): Initialize user_id and token before auth block
    user_id: str | None = None
    token: str | None = None

    # ── Auth ──────────────────────────────────────────────────────────────────
    # Read token from the first WebSocket message (auth frame).
    # The Flutter client sends {"type":"auth","token":"..."} as its first message.
    try:
        raw_auth = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
        if len(raw_auth.encode("utf-8")) > 4096:
            await websocket.send_json({"type": "error", "content": "Auth payload too large"})
            await websocket.close(code=4001)
            return
        first_data = json.loads(raw_auth)
        if first_data.get("type") != "auth":
            await websocket.send_json({"type": "error", "content": "Auth failed"})
            await websocket.close(code=4001)
            return
        token = first_data.get("token")
        if not token:
            await websocket.send_json({"type": "error", "content": "Auth failed"})
            await websocket.close(code=4001)
            return
    except (asyncio.TimeoutError, json.JSONDecodeError, Exception):
        await websocket.send_json({"type": "error", "content": "Auth failed"})
        await websocket.close(code=4001)
        return

    user = await _authenticate_ws(websocket, auth_service, token)
    if user is None:
        return

    user_id = user.get("id", "")
    if not user_id or user_id == "unknown":
        await websocket.close(code=4001)
        return

    # Fix 6.8 (H-4): Track per-user WebSocket connection count
    # _counter_incremented tracks whether we successfully incremented the Redis
    # counter WITHOUT immediately decrementing it (i.e. the >3 branch was NOT
    # taken).  The finally block below uses this flag to avoid a double-decr on
    # the >3 early-return path and to guarantee a decr on all other exit paths
    # that occur after the incr (fix for WS connection counter leak).
    _counter_incremented = False
    if redis_client and user_id:
        conn_key = f"ws_connections:{user_id}"
        try:
            conn_count = await redis_client.incr(conn_key)
            await redis_client.expire(conn_key, 3600)
            if conn_count > 3:
                await redis_client.decr(conn_key)
                await websocket.send_json({"type": "error", "content": "Too many active connections"})
                await websocket.close(code=1008)
                return
            _counter_incremented = True
        except Exception as redis_exc:
            logger.warning("WebSocket connection tracking failed (fail-open): %s", redis_exc)

    try:
        # ── Resolve / create conversation ──────────────────────────────────────
        resolved_conv_id: str
        is_new_conversation = False

        user_subscription_tier: str = "free"

        async with async_session() as db:
            if conversation_id:
                # Fix 6.11 (M-2): Wrap conversation lookup to handle invalid UUIDs
                try:
                    result = await db.execute(
                        select(Conversation).where(
                            Conversation.id == conversation_id,
                            Conversation.user_id == user_id,
                            Conversation.deleted_at.is_(None),
                        )
                    )
                    conv = result.scalar_one_or_none()
                except Exception as db_exc:
                    logger.warning("Conversation lookup failed for id=%s: %s", conversation_id, db_exc)
                    await websocket.send_json({"type": "error", "content": "Invalid conversation ID"})
                    await websocket.close(code=4004, reason="Invalid conversation ID")
                    return
                if conv is None:
                    await websocket.send_json({"type": "error", "content": "Conversation not found"})
                    await websocket.close(code=4004, reason="Conversation not found")
                    return
                resolved_conv_id = conv.id
                # Fetch tier so burst_limit can use it for existing-conversation connections.
                tier_result = await db.execute(select(User.subscription_tier).where(User.id == user_id))
                user_subscription_tier = tier_result.scalar_one_or_none() or "free"
            else:
                # S4: Enforce per-user conversation count limit based on subscription tier
                tier_result = await db.execute(select(User.subscription_tier).where(User.id == user_id))
                user_subscription_tier = tier_result.scalar_one_or_none() or "free"
                conv_limit = (
                    settings.max_conversations_premium
                    if user_subscription_tier != "free"
                    else settings.max_conversations_free
                )
                conv_count_result = await db.execute(
                    select(func.count()).select_from(Conversation).where(
                        Conversation.user_id == user_id,
                        Conversation.deleted_at.is_(None),
                    )
                )
                conv_count = conv_count_result.scalar() or 0
                if conv_count >= conv_limit:
                    await websocket.send_json({
                        "type": "error",
                        "content": "You've reached the maximum number of conversations. Please delete some old ones to continue.",
                    })
                    await websocket.close(code=1008)
                    return

                conv = Conversation(user_id=user_id)
                conv.updated_at = datetime.now(timezone.utc)
                db.add(conv)
                await db.commit()
                await db.refresh(conv)
                resolved_conv_id = conv.id
                is_new_conversation = True

        logger.info(
            "WebSocket connected for user '%s', conversation '%s' (new=%s)",
            user_id[:8] if user_id else "?",
            resolved_conv_id,
            is_new_conversation,
        )

        # Send conversation ID immediately so the client can update its route.
        await websocket.send_json({"type": "conversation_init", "conversation_id": resolved_conv_id})

        # ── Message loop ────────────────────────────────────────────────────────
        # S2: Tracking variables for periodic JWT re-validation
        last_revalidation = time.time()
        messages_since_revalidation = 0

        while True:
            try:
                raw = await asyncio.wait_for(websocket.receive_text(), timeout=300.0)
            except asyncio.TimeoutError:
                await websocket.close(code=1001)
                break
            if len(raw.encode("utf-8")) > 65536:
                await websocket.send_json({"type": "error", "content": "Message payload too large"})
                continue
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "content": "Invalid message format"})
                continue
            message_text: str = data.get("message", "")

            # S2: Periodic JWT re-validation (every 15 minutes or 50 messages)
            messages_since_revalidation += 1
            if time.time() - last_revalidation > 900 or messages_since_revalidation >= 50:
                try:
                    user_check = await auth_service.get_user(token)
                    if not user_check:
                        await websocket.send_json({"type": "error", "content": "Session expired."})
                        await websocket.close(code=4003)
                        return
                except Exception:
                    # On any auth error (expired, revoked, Supabase unreachable), close gracefully
                    await websocket.send_json({"type": "error", "content": "Session expired. Please reconnect."})
                    await websocket.close(code=4003)
                    return
                last_revalidation = time.time()
                messages_since_revalidation = 0
            raw_attachments: list[dict] | None = data.get("attachments")
            is_regenerate: bool = bool(data.get("regenerate", False))

            if not message_text and not raw_attachments:
                await websocket.send_json({"type": "error", "content": "Empty message"})
                continue

            # Fix 6.1 (C-1): Message size cap
            if message_text and len(message_text) > 4000:
                await websocket.send_json({"type": "error", "content": "Message too long (max 4,000 characters)"})
                continue

            # Fix 6.2 (C-2): Attachment count cap
            if raw_attachments and len(raw_attachments) > 3:
                await websocket.send_json({"type": "error", "content": "Too many attachments (max 3)"})
                continue

            # Refresh the connection-counter TTL on each valid message so it
            # stays alive for the duration of an active session.
            if redis_client and user_id:
                conn_key = f"ws_connections:{user_id}"
                try:
                    await redis_client.expire(conn_key, 3600)
                except Exception as redis_ttl_exc:
                    logger.warning("Failed to refresh WebSocket connection TTL: %s", redis_ttl_exc)

            # Soft-deleted conversation guard (catch race conditions per message)
            async with async_session() as db:
                conv_check = await db.execute(
                    select(Conversation.deleted_at).where(Conversation.id == resolved_conv_id)
                )
                if conv_check.scalar_one_or_none() is not None:
                    await websocket.send_json({"type": "error", "content": "This conversation has been deleted."})
                    await websocket.close(code=4004)
                    return

            # Fix 6.12 (M-3): Audit log for regenerate
            if is_regenerate:
                logger.info("regenerate_request", extra={"user_id": user_id, "conv_id": resolved_conv_id})

            # Fix 17 (MEDIUM): Validate regenerate flag server-side before burning LLM tokens.
            # A regenerate is only valid when the last message in the conversation is an
            # assistant message (i.e. there is something to regenerate from).
            if is_regenerate:
                async with async_session() as db:
                    last_msg_result = await db.execute(
                        select(Message)
                        .where(Message.conversation_id == resolved_conv_id)
                        .order_by(Message.created_at.desc())
                        .limit(1)
                    )
                    last_msg = last_msg_result.scalar_one_or_none()
                if last_msg is None or last_msg.role == "user":
                    await websocket.send_json({
                        "type": "error",
                        "content": "Nothing to regenerate: conversation must end with an assistant message.",
                    })
                    continue

            # Fix 6.5 (H-1): Per-minute burst limit check before daily rate limit
            if rate_limiter:
                try:
                    normalized_tier = "premium" if user_subscription_tier and user_subscription_tier not in ("", "free") else "free"
                    burst_result = await rate_limiter.check_burst_limit(user_id, tier=normalized_tier)
                    if not burst_result.allowed:
                        await websocket.send_json({
                            "type": "error",
                            "content": "Too many messages. Please wait a moment.",
                            "limit": burst_result.limit,
                            "remaining": burst_result.remaining,
                            "reset_seconds": burst_result.reset_seconds,
                        })
                        continue
                except Exception as burst_exc:
                    logger.warning("Burst limit check failed (fail-open): %s", burst_exc)

            # ── Rate limiting ─────────────────────────────────────────────────
            if rate_limiter:
                try:
                    async with async_session() as db:
                        await check_rate_limit(user_id, rate_limiter, db)
                except HTTPException as exc:
                    if exc.status_code == 429:
                        rate_headers = exc.headers or {}
                        await websocket.send_json({
                            "type": "rate_limit",
                            "content": exc.detail or "Rate limit exceeded",
                            "reset_seconds": int(rate_headers.get("X-RateLimit-Reset", 0)),
                            "limit": int(rate_headers.get("X-RateLimit-Limit", 0)),
                            "remaining": 0,
                        })
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

            # Sanitize user input before passing to the LLM or persisting to DB.
            message_text = sanitize_for_llm(message_text)

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
                persisted_user_msg_id: str | None = None
                if not is_regenerate:
                    sanitized_attachments = []
                    for att in (raw_attachments or []):
                        if isinstance(att, dict) and "context_message" in att:
                            att = {**att, "context_message": sanitize_for_llm(att["context_message"])}
                        sanitized_attachments.append(att)
                    user_msg = Message(
                        conversation_id=resolved_conv_id,
                        role="user",
                        content=message_text or "[attachment]",
                        attachments=sanitized_attachments or None,
                    )
                    db.add(user_msg)
                    await db.commit()
                    await db.refresh(user_msg)
                    persisted_user_msg_id = str(user_msg.id)

                    # Update conversation.updated_at when a new user message is added
                    conv_upd = await db.execute(select(Conversation).where(Conversation.id == resolved_conv_id))
                    conversation = conv_upd.scalar_one_or_none()
                    if conversation:
                        conversation.updated_at = datetime.now(timezone.utc)
                        await db.commit()

                # Load conversation history for LLM context, excluding the
                # just-persisted user message (passed separately as `message`).
                history = await _load_conversation_history(
                    db, resolved_conv_id, limit=50, exclude_message_id=persisted_user_msg_id, user_id=user_id
                )

                # Fix 6.7 (H-3): Cap history to MAX_HISTORY_CHARS to bound token usage
                total_chars = sum(len(m.get("content") or "") for m in history)
                if total_chars > MAX_HISTORY_CHARS:
                    excess = total_chars - MAX_HISTORY_CHARS
                    removed = 0
                    trim_count = 0
                    while trim_count < len(history) - 1 and removed < excess:
                        removed += len(str(history[trim_count].get("content") or ""))
                        trim_count += 1
                    history = history[trim_count:]

                db_persona, db_proactivity, db_response_length = await _load_user_preferences(db, user_id)
                # Fix 6.6 (H-2): Validate client-supplied persona/proactivity against allowlist
                client_persona = data.get("persona")
                persona = client_persona if client_persona in _VALID_PERSONAS else db_persona
                client_proactivity = data.get("proactivity")
                proactivity = client_proactivity if client_proactivity in _VALID_PROACTIVITY else db_proactivity
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

                        elif etype == "thinking_token":
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
                            await websocket.send_json({"type": "stream_end", "content": "", "message_id": "", "conversation_id": str(resolved_conv_id), "client_action": None})
                            break

                except Exception as orch_exc:
                    # Fix 6.13 (M-4): Hide exception detail from client; log server-side
                    logger.exception("Orchestrator stream error for user '%s'", user_id[:8])
                    sentry_sdk.capture_exception(orch_exc)
                    await websocket.send_json({"type": "error", "content": "Something went wrong. Please try again."})
                    await websocket.send_json({"type": "stream_end", "content": "", "message_id": "", "conversation_id": str(resolved_conv_id), "client_action": None})
                    continue

                if had_error:
                    continue

            # ── Persist assistant message ─────────────────────────────────────
            # Fix 6.4 (C-4): Skip persisting blank assistant messages
            if not full_content.strip():
                await websocket.send_json({"type": "stream_end", "content": "", "message_id": "", "conversation_id": str(resolved_conv_id), "client_action": None})
                continue

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

                    # Issue B: Non-blocking title generation.
                    # Set a fallback title immediately, then kick off an async
                    # background task to generate a better one with the LLM.
                    if conv_row.title is None and message_text:
                        safe_title = sanitize_for_llm(message_text)
                        conv_row.title = safe_title[:60] + ("..." if len(safe_title) > 60 else "")
                        try:
                            asyncio.create_task(
                                _generate_and_save_title(
                                    db_url=settings.database_url,
                                    conversation_id=str(resolved_conv_id),
                                    message_text=message_text,
                                    mcp_client=mcp_client,
                                    memory_store=memory_store,
                                    llm_client=llm_client,
                                )
                            )
                        except Exception:
                            pass  # Fallback title already set above

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
                "message_id": str(assistant_msg_id),
                "conversation_id": str(resolved_conv_id),
                "client_action": client_action,
            }
            await websocket.send_json(final_payload)

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected for user '%s'", user_id[:8] if user_id else "?")
    except Exception:
        logger.exception("Unexpected WebSocket error for user '%s'", user_id[:8] if user_id else "?")
        # Fix 6.3 (C-3): Close WebSocket on unexpected exception
        try:
            await websocket.close(code=1011)
        except Exception:
            pass
    finally:
        # Fix 6.8 (H-4): Decrement per-user connection count on disconnect.
        # Only decrement if we successfully incremented the counter and did NOT
        # take the >3 early-return path (which does its own decr before returning).
        if redis_client and user_id and _counter_incremented:
            conn_key = f"ws_connections:{user_id}"
            try:
                await redis_client.decr(conn_key)
            except Exception as redis_exc:
                logger.warning("Failed to decrement WebSocket connection count: %s", redis_exc)


# ---------------------------------------------------------------------------
# REST — conversation list, messages, history, management
# ---------------------------------------------------------------------------


@limiter.limit("60/minute")
@router.get("/history")
async def get_chat_history(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100, description="Maximum number of conversations to return"),
    offset: int = Query(default=0, ge=0, description="Number of conversations to skip"),
    user_id: Annotated[str, Depends(get_authenticated_user_id)] = ...,
    storage_service: StorageService = Depends(_get_storage_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Retrieve chat history for the authenticated user.

    Returns non-deleted conversations ordered by most recent first.
    Supports pagination via ``limit`` (max 100, default 20) and ``offset``.

    Args:
        limit: Maximum number of conversations to return (1–100).
        offset: Number of conversations to skip (for pagination).
        user_id: Authenticated user ID from the Bearer token.
        storage_service: Injected storage service for signed URLs.
        db: Injected async database session.

    Returns:
        A list of conversation metadata dicts.

    Raises:
        HTTPException: 401 if the token is invalid.
    """
    result = await db.execute(
        select(Conversation)
        .where(
            Conversation.user_id == user_id,
            Conversation.deleted_at.is_(None),
        )
        .order_by(Conversation.updated_at.desc(), Conversation.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    conversations = result.scalars().unique().all()

    history = []
    for conv in conversations:
        created = conv.created_at
        updated = conv.updated_at or conv.created_at
        history.append(
            {
                "id": conv.id,
                "title": conv.title,
                "created_at": created.isoformat() if hasattr(created, "isoformat") else str(created),
                "updated_at": updated.isoformat() if hasattr(updated, "isoformat") else str(updated),
                "archived": conv.archived,
                "messages": [],
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
    user_id: Annotated[str, Depends(get_authenticated_user_id)] = ...,
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
        user_id: Authenticated user ID from the Bearer token.
        db: Injected async database session.

    Returns:
        A list of conversation summary dicts.

    Raises:
        HTTPException: 401 if the token is invalid.
    """

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
        preview_snippet: str | None = sanitize_for_llm(preview_raw[:100]) if preview_raw else None
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
    limit: int = Query(100, le=200),
    offset: int = Query(0, ge=0),
    user_id: Annotated[str, Depends(get_authenticated_user_id)] = ...,
    storage_service: StorageService = Depends(_get_storage_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Return all messages for a specific conversation.

    Validates that the authenticated user owns the conversation.
    Attachment signed URLs are refreshed on each request.

    Args:
        conversation_id: The UUID of the conversation.
        user_id: Authenticated user ID from the Bearer token.
        storage_service: Injected storage service for signed URLs.
        db: Injected async database session.

    Returns:
        A list of message dicts ordered chronologically.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 404 if the conversation does not exist or belongs
            to a different user.
    """

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

    # Fix 6.14 (M-5): Apply pagination to message query
    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.asc())
        .limit(limit)
        .offset(offset)
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


@limiter.limit("30/minute")
@router.patch("/conversations/{conversation_id}")
async def update_conversation(
    request: Request,
    conversation_id: str,
    body: ConversationUpdateRequest,
    user_id: Annotated[str, Depends(get_authenticated_user_id)] = ...,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Rename or archive a conversation.

    Only the owner of the conversation may modify it.

    Args:
        conversation_id: The UUID of the conversation to update.
        body: Fields to update — ``title`` and/or ``archived``.
        user_id: Authenticated user ID from the Bearer token.
        db: Injected async database session.

    Returns:
        The updated conversation dict.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 404 if the conversation does not exist or belongs
            to a different user.
    """

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
        stripped_title = body.title.strip()
        if not stripped_title:
            raise HTTPException(status_code=422, detail="Title cannot be empty")
        safe_title = sanitize_for_llm(stripped_title)[:200]
        conv.title = safe_title

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
    user_id: Annotated[str, Depends(get_authenticated_user_id)] = ...,
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft-delete a conversation.

    Sets ``deleted_at`` to the current UTC timestamp. Only the owner may delete.

    Args:
        conversation_id: The UUID of the conversation to delete.
        user_id: Authenticated user ID from the Bearer token.
        db: Injected async database session.

    Returns:
        204 No Content on success.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 404 if the conversation does not exist or belongs
            to a different user.
    """

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
