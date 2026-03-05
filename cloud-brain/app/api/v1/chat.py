"""
Zuralog Cloud Brain — Chat API Router.

WebSocket endpoint for real-time AI chat streaming and REST endpoints
for chat history retrieval. Handles authentication, message routing
through the Orchestrator, and message persistence.
"""

import logging
from typing import Any

import sentry_sdk
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from openai import AsyncOpenAI
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
                    audio_bytes, att.get("filename", "voice_note"),
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


@router.websocket("/ws")
async def websocket_chat(
    websocket: WebSocket,
    token: str | None = Query(default=None),
) -> None:
    """WebSocket endpoint for real-time AI chat.

    Authenticates via a `token` query parameter, then enters a
    message loop: receives user messages, routes them through the
    Orchestrator, and streams responses back.

    Protocol:
        Client sends: ``{"message": "Hello", "attachments": [...]}``
        Server replies: ``{"type": "message", "content": "...", "role": "assistant"}``
        Server errors: ``{"type": "error", "content": "..."}``

    Args:
        websocket: The WebSocket connection.
        token: JWT access token passed as a query parameter.
    """
    app = websocket.app
    auth_service: AuthService = app.state.auth_service
    mcp_client: MCPClient = app.state.mcp_client
    memory_store: MemoryStore = app.state.memory_store
    llm_client: LLMClient = app.state.llm_client
    rate_limiter: RateLimiter | None = getattr(app.state, "rate_limiter", None)

    # Authenticate before accepting the connection
    user = await _authenticate_ws(websocket, auth_service, token)
    if user is None:
        return

    user_id = user.get("id", "unknown")
    await websocket.accept()
    logger.info("WebSocket connected for user '%s'", user_id)

    try:
        while True:
            data = await websocket.receive_json()
            message_text = data.get("message", "")
            raw_attachments = data.get("attachments")

            if not message_text and not raw_attachments:
                await websocket.send_json(
                    {
                        "type": "error",
                        "content": "Empty message",
                    }
                )
                continue

            analytics = getattr(app.state, "analytics_service", None)

            # Enforce per-user rate limit before processing
            if rate_limiter:
                try:
                    async with async_session() as db:
                        await check_rate_limit(user, rate_limiter, db)
                except HTTPException as exc:
                    if exc.status_code == 429:
                        await websocket.send_json(
                            {
                                "type": "error",
                                "content": exc.detail or "Rate limit exceeded",
                            }
                        )
                        continue
                    raise

            # Only count messages that pass the rate-limit gate
            if analytics:
                _sent_props: dict[str, Any] = {"message_length": len(message_text)}
                analytics.capture(
                    distinct_id=user_id,
                    event="chat_message_sent",
                    properties=_sent_props,
                )

            # Process attachments (transcribe audio, note images for LLM)
            augmented_text = message_text
            if raw_attachments:
                storage_service: StorageService = app.state.storage_service
                extra_context = await _process_attachments(raw_attachments, storage_service)
                if extra_context:
                    augmented_text = f"{message_text}\n\n{extra_context}" if message_text else extra_context

            # Build orchestrator with a fresh DB session for usage tracking
            async with async_session() as db:
                usage_tracker = UsageTracker(session=db)
                orchestrator = Orchestrator(
                    mcp_client=mcp_client,
                    memory_store=memory_store,
                    llm_client=llm_client,
                    usage_tracker=usage_tracker,
                )

                # Process through the Orchestrator
                try:
                    agent_response = await orchestrator.process_message(user_id, augmented_text, db=db)
                    if analytics:
                        analytics.capture(
                            distinct_id=user_id,
                            event="chat_response_received",
                            properties={
                                "response_length": len(agent_response.message),
                                "had_client_action": agent_response.client_action is not None,
                            },
                        )
                    ws_payload: dict[str, Any] = {
                        "type": "message",
                        "content": agent_response.message,
                        "role": "assistant",
                    }
                    if agent_response.client_action is not None:
                        ws_payload["client_action"] = agent_response.client_action
                    await websocket.send_json(ws_payload)
                except Exception as e:
                    logger.exception("Orchestrator error for user '%s'", user_id)
                    sentry_sdk.capture_exception(e)
                    await websocket.send_json(
                        {
                            "type": "error",
                            "content": f"Processing error: {e!s}",
                        }
                    )

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected for user '%s'", user_id)
    except Exception:
        logger.exception("Unexpected WebSocket error for user '%s'", user_id)


@router.get("/history")
async def get_chat_history(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    storage_service: StorageService = Depends(_get_storage_service),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Retrieve chat history for the authenticated user.

    Returns all conversations and their messages, ordered by
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
        select(Conversation).where(Conversation.user_id == user_id).order_by(Conversation.created_at.desc())
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
            msg_dict: dict[str, Any] = {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            }
            if msg.attachments:
                msg_dict["attachments"] = await _refresh_attachment_urls(
                    msg.attachments, storage_service,
                )
            msg_dicts.append(msg_dict)

        history.append(
            {
                "id": conv.id,
                "title": conv.title,
                "created_at": conv.created_at.isoformat() if conv.created_at else None,
                "messages": msg_dicts,
            }
        )

    return history
