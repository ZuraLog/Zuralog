"""
Zuralog Cloud Brain — Chat Attachment Upload Endpoint.

Allows users to upload files (images, PDFs, plain-text) during a chat
session. The file is validated and processed in memory; no permanent
storage is performed. The resulting metadata and extracted context are
returned to the client for inclusion in the next LLM message payload.

Route
-----
POST /chat/{conversation_id}/attachments
    Upload and process a file attachment for an existing conversation.

Notes
-----
- This router uses the prefix ``/chat`` to align with the existing chat
  router, but it is registered as a **separate** ``APIRouter`` instance
  (``attachments_router``) to avoid conflicts with ``chat.router``.
- Auth is provided by ``get_current_user`` from ``app.api.deps``.
- A maximum of ``AttachmentProcessor.MAX_PER_MESSAGE`` files are enforced
  by the processor layer; callers should communicate this limit to end users.
"""

from __future__ import annotations

import asyncio
import base64
import logging

import filetype  # Fix 7.4 (C-10): Server-side MIME type detection from magic bytes
import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_rate_limit, get_current_user
from app.database import get_db
from app.limiter import limiter
from app.models.conversation import Conversation
from app.models.user import User
from app.services.attachment_processor import AttachmentProcessor, _safe_extract_health_facts
from app.services.rate_limiter import RateLimiter

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Router — separate instance so it does not conflict with chat.router
# ---------------------------------------------------------------------------

attachments_router = APIRouter(
    prefix="/chat",
    tags=["attachments"],
)


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@limiter.limit("10/minute")  # Fix 7.1 (H-16): Rate limit on upload endpoint
@attachments_router.post(
    "/{conversation_id}/attachments",
    summary="Upload a file attachment for a conversation",
    response_model=dict,
    status_code=status.HTTP_200_OK,
)
async def upload_attachment(
    conversation_id: str,
    file: UploadFile,
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Upload and process a file attachment for an existing conversation.

    Validates that the conversation belongs to the authenticated user,
    then passes the file bytes through ``AttachmentProcessor.process()``.
    The processed metadata (including extracted text and health facts) is
    returned directly; nothing is persisted to storage.

    The returned ``context_message`` field is designed to be injected into
    the LLM conversation context so the AI can reference the attachment's
    content in its next reply.

    Args:
        conversation_id: UUID of the target conversation.
        file: Multipart-form file upload (``UploadFile``).
        user: Authenticated user resolved by ``get_current_user``.
        db: Async database session.

    Returns:
        Processed attachment metadata dict containing:
            - ``type``: ``"image"`` or ``"document"``
            - ``filename``: Original upload filename
            - ``content_type``: Detected/declared MIME type
            - ``size_bytes``: File size in bytes
            - ``extracted_text``: Text content (``None`` for images)
            - ``is_food_image``: Boolean food heuristic flag
            - ``health_facts``: List of detected health fact strings
            - ``context_message``: LLM-ready context injection text

    Raises:
        HTTPException 404: Conversation not found or does not belong to user.
        HTTPException 400: File type not allowed, or file exceeds size limit,
            or no file was provided.
        HTTPException 413: File exceeds 10 MB size limit.
        HTTPException 500: Unexpected processing error.
    """
    sentry_sdk.set_tag("api.module", "attachments")
    sentry_sdk.set_user({"id": str(user.id)})

    # ------------------------------------------------------------------
    # 0. Rate limit check
    # ------------------------------------------------------------------
    rate_limiter: RateLimiter | None = getattr(request.app.state, "rate_limiter", None)
    if rate_limiter:
        await check_rate_limit(str(user.id), rate_limiter, db)

    # ------------------------------------------------------------------
    # 1. Verify conversation ownership (Fix 7.3 H-18: filter deleted)
    # ------------------------------------------------------------------
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == str(user.id),
            Conversation.deleted_at.is_(None),  # Fix 7.3 (H-18): Filter deleted conversations
        )
    )
    conversation = result.scalar_one_or_none()

    if conversation is None:
        logger.warning(
            "upload_attachment: conversation %s not found for user %s",
            conversation_id,
            user.id,
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    # ------------------------------------------------------------------
    # 2. Read file bytes
    # ------------------------------------------------------------------
    if file is None or file.filename is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No file provided.",
        )

    # Fix 7.2 (H-17): Check file size before reading (if available from header)
    if file.size and file.size > 10 * 1024 * 1024:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="File too large (max 10 MB)")

    try:
        file_bytes = await file.read()
    except Exception:
        logger.exception(
            "upload_attachment: failed to read file for user=%s conversation=%s",
            user.id,
            conversation_id,
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to read uploaded file.",
        )

    # Fix 7.2 (H-17): Also check after reading (Starlette may not populate file.size)
    if len(file_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File too large (max 10 MB)",
        )

    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    declared_mime: str = file.content_type or "application/octet-stream"
    filename: str = file.filename or "upload"

    # ------------------------------------------------------------------
    # Fix 7.4 (C-10): Detect MIME type from file content (magic bytes)
    # ------------------------------------------------------------------
    kind = filetype.guess(file_bytes[:262])  # Only needs first 262 bytes
    actual_mime = kind.mime if kind else None

    # For text/plain and text/csv: verify content is valid UTF-8
    if declared_mime in ("text/plain", "text/csv"):
        try:
            file_bytes.decode("utf-8")
        except UnicodeDecodeError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File content is not valid UTF-8 text",
            )

    # For binary types: verify actual_mime matches declared prefix
    if actual_mime and declared_mime.split("/")[0] in ("image", "application"):
        declared_maintype = declared_mime.split("/")[0]
        actual_maintype = actual_mime.split("/")[0] if actual_mime else None
        if actual_maintype and actual_maintype != declared_maintype:
            logger.warning(
                "upload_attachment: MIME mismatch for user=%s: declared=%s actual=%s",
                user.id,
                declared_mime,
                actual_mime,
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File content does not match declared type '{declared_mime}'.",
            )

    # Use the actual detected MIME if available and declared is generic
    content_type = declared_mime

    # ------------------------------------------------------------------
    # 3. Process through AttachmentProcessor
    # ------------------------------------------------------------------
    try:
        processed = await asyncio.to_thread(
            AttachmentProcessor.process,
            file_bytes=file_bytes,
            filename=filename,
            content_type=content_type,
            user_id=str(user.id),
        )
        # Override health_facts with the async safe version (timeout-protected,
        # non-blocking) if there is extracted text to scan.
        if processed.get("extracted_text"):
            processed["health_facts"] = await _safe_extract_health_facts(processed["extracted_text"])
    except ValueError as exc:
        logger.info(
            "upload_attachment: validation error for user=%s: %s",
            user.id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )
    except Exception:
        logger.exception(
            "upload_attachment: unexpected error processing file for user=%s",
            user.id,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred while processing the file.",
        )

    logger.info(
        "upload_attachment: processed attachment for user=%s conversation=%s "
        "filename=%r type=%s size=%d health_facts=%d",
        user.id,
        conversation_id,
        filename,
        processed["type"],
        processed["size_bytes"],
        len(processed["health_facts"]),
    )

    # For images, return a base64 data URI the mobile client can forward to
    # the WebSocket. The LLM orchestrator then threads this into the vision
    # model's image_url block. We do this inline (no persistent storage) so
    # the upload → chat round-trip has no external dependencies.
    if processed.get("type") == "image":
        image_mime = actual_mime or content_type or "image/jpeg"
        b64 = base64.b64encode(file_bytes).decode("ascii")
        processed["data_url"] = f"data:{image_mime};base64,{b64}"

    return processed
