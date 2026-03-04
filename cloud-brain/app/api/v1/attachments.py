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

import logging

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.conversation import Conversation
from app.models.user import User
from app.services.attachment_processor import AttachmentProcessor

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


@attachments_router.post(
    "/{conversation_id}/attachments",
    summary="Upload a file attachment for a conversation",
    response_model=dict,
    status_code=status.HTTP_200_OK,
)
async def upload_attachment(
    conversation_id: str,
    file: UploadFile,
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
        HTTPException 500: Unexpected processing error.
    """
    sentry_sdk.set_tag("api.module", "attachments")
    sentry_sdk.set_user({"id": str(user.id)})

    # ------------------------------------------------------------------
    # 1. Verify conversation ownership
    # ------------------------------------------------------------------
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == str(user.id),
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

    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    content_type: str = file.content_type or "application/octet-stream"
    filename: str = file.filename or "upload"

    # ------------------------------------------------------------------
    # 3. Process through AttachmentProcessor
    # ------------------------------------------------------------------
    try:
        processed = await AttachmentProcessor.process(
            file_bytes=file_bytes,
            filename=filename,
            content_type=content_type,
            user_id=str(user.id),
        )
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

    return processed
