"""
Life Logger Cloud Brain — Chat API Router.

WebSocket endpoint for real-time AI chat streaming and REST endpoints
for chat history retrieval. Handles authentication, message routing
through the Orchestrator, and message persistence.
"""

import logging

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
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.agent.orchestrator import Orchestrator
from app.api.deps import check_rate_limit
from app.database import async_session, get_db
from app.models.conversation import Conversation, Message
from app.services.auth_service import AuthService
from app.services.rate_limiter import RateLimiter
from app.services.usage_tracker import UsageTracker

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])
security = HTTPBearer()


def _get_auth_service(request: Request) -> AuthService:
    """FastAPI dependency that retrieves the shared AuthService.

    Args:
        request: The incoming FastAPI request.

    Returns:
        The shared AuthService instance.
    """
    return request.app.state.auth_service


def _get_orchestrator(request: Request) -> Orchestrator:
    """FastAPI dependency that builds an Orchestrator from app state.

    The Orchestrator is constructed per-request using the shared
    MCP client and memory store from the application lifespan.

    Args:
        request: The incoming FastAPI request.

    Returns:
        A configured Orchestrator instance.
    """
    return Orchestrator(
        mcp_client=request.app.state.mcp_client,
        memory_store=request.app.state.memory_store,
        llm_client=request.app.state.llm_client,
    )


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
        Client sends: ``{"message": "Hello"}``
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

            if not message_text:
                await websocket.send_json(
                    {
                        "type": "error",
                        "content": "Empty message",
                    }
                )
                continue

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
                    response = await orchestrator.process_message(user_id, message_text)
                    await websocket.send_json(
                        {
                            "type": "message",
                            "content": response,
                            "role": "assistant",
                        }
                    )
                except Exception as e:
                    logger.exception("Orchestrator error for user '%s'", user_id)
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
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Retrieve chat history for the authenticated user.

    Returns all conversations and their messages, ordered by
    most recent conversation first, messages chronologically.

    Args:
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
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

        history.append(
            {
                "id": conv.id,
                "title": conv.title,
                "created_at": conv.created_at.isoformat() if conv.created_at else None,
                "messages": [
                    {
                        "id": msg.id,
                        "role": msg.role,
                        "content": msg.content,
                        "created_at": msg.created_at.isoformat() if msg.created_at else None,
                    }
                    for msg in messages
                ],
            }
        )

    return history
