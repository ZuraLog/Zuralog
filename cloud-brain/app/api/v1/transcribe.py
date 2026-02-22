"""
Life Logger Cloud Brain — Voice Transcription Endpoint.

Accepts audio file uploads and returns transcribed text.
Currently uses a mock transcription; the real Whisper STT
integration will be added when infrastructure is ready.

Requires Bearer token authentication.

Supported formats: .webm, .m4a, .wav, .mp3
"""

import logging
import os

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

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
    and returns the transcribed text. Currently uses a mock
    transcription response.

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

    # --- Mock transcription ---
    # TODO(phase-1.8): Replace with real Whisper API call when ready
    text = "[Mock transcription] Audio received and would be transcribed here."

    return {"text": text}
