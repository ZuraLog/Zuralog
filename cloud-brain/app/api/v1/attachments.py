"""
Zuralog Cloud Brain — File Attachment Routes.

Endpoint:
  POST /api/v1/chat/{conversation_id}/attachments

Accepts multipart/form-data file uploads, processes them via
AttachmentProcessor, and returns extracted health facts. No permanent
file storage — we extract knowledge only.

Constraints:
  - Max 10MB per file
  - Max 3 files per message
  - Supported types: JPEG, PNG, HEIC, PDF, TXT, CSV
"""

from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status

from app.api.v1.deps import get_authenticated_user_id
from app.services.attachment_processor import AttachmentProcessor

logger = logging.getLogger(__name__)

router = APIRouter(tags=["attachments"])

_processor = AttachmentProcessor()

_MAX_FILES_PER_MESSAGE = 3


@router.post("/chat/{conversation_id}/attachments")
async def upload_attachment(
    conversation_id: str,
    request: Request,
    files: list[UploadFile] = File(..., description="Files to upload (max 3)"),
    user_id: str = Depends(get_authenticated_user_id),
) -> list[dict]:
    """Upload and process file attachments for a chat message.

    Processes each file via AttachmentProcessor:
    - Images: LLM describes the image; food photos get a nutrition estimate.
    - PDF/TXT/CSV: Text extracted and summarised for health facts.
    - Extracted knowledge is stored in the vector memory store.
    - Raw files are NOT stored permanently.

    Args:
        conversation_id: UUID of the chat conversation (for context).
        files: List of uploaded files (multipart/form-data).

    Returns:
        List of attachment metadata dicts, one per file.

    Raises:
        400 if more than 3 files are submitted.
        413 if any file exceeds 10MB.
        415 if any file has an unsupported MIME type.
    """
    if len(files) > _MAX_FILES_PER_MESSAGE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum {_MAX_FILES_PER_MESSAGE} files per message. Got {len(files)}.",
        )

    # Retrieve shared services from app state (may be None in test env).
    memory_store = getattr(request.app.state, "memory_store", None)
    llm_client = getattr(request.app.state, "llm_client", None)

    results: list[dict] = []

    for upload in files:
        content_type = upload.content_type or "application/octet-stream"
        filename = upload.filename or "unnamed"

        # Check MIME type before reading the full content.
        if content_type not in _processor.ALLOWED_TYPES:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=(
                    f"Unsupported file type '{content_type}' for '{filename}'. "
                    f"Allowed types: {sorted(_processor.ALLOWED_TYPES)}"
                ),
            )

        file_bytes = await upload.read()

        # Size check.
        if len(file_bytes) > _processor.MAX_SIZE_BYTES:
            size_mb = len(file_bytes) / (1024 * 1024)
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=(
                    f"File '{filename}' is {size_mb:.1f}MB. "
                    f"Maximum allowed is {_processor.MAX_SIZE_BYTES // (1024 * 1024)}MB."
                ),
            )

        try:
            processed = await _processor.process(
                file_content=file_bytes,
                content_type=content_type,
                filename=filename,
                user_id=user_id,
                memory_store=memory_store,
                llm_client=llm_client,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc
        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Attachment processing failed for user %s file '%s': %s",
                user_id,
                filename,
                exc,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Processing failed for '{filename}'",
            ) from exc

        results.append(
            {
                "id": str(uuid.uuid4()),
                "filename": filename,
                "content_type": content_type,
                "size_bytes": processed["size_bytes"],
                "extracted_facts": processed["extracted_facts"],
                "food_data": processed.get("food_data"),
                "conversation_id": conversation_id,
            }
        )

    return results
