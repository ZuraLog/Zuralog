"""
Zuralog Cloud Brain — Voice Transcription Endpoint.

Accepts audio file uploads and returns transcribed text via
OpenAI's Whisper model. Requires OPENAI_API_KEY to be set
in the environment.

Requires Bearer token authentication.

Supported formats: .webm, .m4a, .wav, .mp3
"""

import logging
import os

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from openai import AsyncOpenAI

from app.config import settings
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(tags=["transcribe"])
security = HTTPBearer()

ALLOWED_EXTENSIONS = {".webm", ".m4a", ".wav", ".mp3"}
MAX_FILE_SIZE = 25 * 1024 * 1024  # 25 MB (Whisper limit)


def _get_auth_service(request: Request) -> AuthService:
    """FastAPI dependency that retrieves the shared AuthService.

    Args:
        request: The incoming FastAPI request.

    Returns:
        The shared AuthService instance.
    """
    return request.app.state.auth_service


@router.post("/transcribe")
async def transcribe_audio(
    file: UploadFile,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, str]:
    """Transcribe an audio file to text.

    Accepts audio uploads in common formats, validates the file,
    and returns the transcribed text using OpenAI's Whisper model.

    Requires a valid Bearer token in the Authorization header.

    Args:
        file: The uploaded audio file.
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.

    Returns:
        A dict with 'text' key containing the transcription.

    Raises:
        HTTPException: 400 if file format is invalid or file is too large.
        HTTPException: 401 if the token is invalid or expired.
    """
    # Validate authentication
    await auth_service.get_user(credentials.credentials)
    # Validate file extension
    filename = file.filename or ""
    ext = os.path.splitext(filename)[1].lower()

    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file format '{ext}'. Accepted: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    # Read file content
    content = await file.read()

    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size: {MAX_FILE_SIZE // (1024 * 1024)} MB",
        )

    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file uploaded",
        )

    logger.info(
        "Transcription request: filename=%s, size=%d bytes, format=%s",
        filename,
        len(content),
        ext,
    )

    try:
        if not settings.openai_api_key:
            logger.error("openai_api_key is not configured in settings.")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Transcription service is not properly configured.",
            )

        client = AsyncOpenAI(api_key=settings.openai_api_key)

        # Whisper expects a tuple of (filename, file_content) or a file-like object
        # with a name attribute. We'll use the tuple format.
        file_tuple = (filename, content)

        transcription = await client.audio.transcriptions.create(
            model="whisper-1", file=file_tuple, response_format="text"
        )

        # When response_format="text", the API returns a string directly
        text = str(transcription)

    except Exception as e:
        logger.exception("Error during OpenAI transcription")
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Error processing audio transcription. Please try again later.",
        )

    return {"text": text}
