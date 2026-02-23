"""
Zuralog Cloud Brain — Transcribe Endpoint Tests.

Tests for the voice transcription endpoint. Uses mock STT
since the endpoint is scaffolded with mock transcription.
Validates Bearer token authentication is enforced.
"""

import io
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.transcribe import _get_auth_service
from app.main import app
from app.services.auth_service import AuthService


@pytest.fixture
def mock_auth_service():
    """Create a mocked AuthService that returns a valid user."""
    service = AsyncMock(spec=AuthService)
    service.get_user.return_value = {
        "id": "user-123",
        "email": "test@example.com",
    }
    return service


@pytest.fixture
def client(mock_auth_service):
    """Create a test client with mocked auth."""
    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service

    with TestClient(app, raise_server_exceptions=False) as c:
        # Override app.state for lifespan-created services
        app.state.auth_service = mock_auth_service
        yield c

    app.dependency_overrides.clear()


AUTH_HEADERS = {"Authorization": "Bearer valid-token"}


def test_transcribe_valid_audio(client):
    """Valid audio upload with auth should return transcription text."""
    audio_content = b"fake-audio-data"
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("test.wav", io.BytesIO(audio_content), "audio/wav")},
        headers=AUTH_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert "text" in data
    assert isinstance(data["text"], str)
    assert len(data["text"]) > 0


def test_transcribe_invalid_format(client):
    """Invalid file format should return 400."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("test.txt", io.BytesIO(b"not audio"), "text/plain")},
        headers=AUTH_HEADERS,
    )
    assert response.status_code == 400


def test_transcribe_mp3_accepted(client):
    """MP3 format should be accepted."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("voice.mp3", io.BytesIO(b"mp3-data"), "audio/mpeg")},
        headers=AUTH_HEADERS,
    )
    assert response.status_code == 200


def test_transcribe_webm_accepted(client):
    """WebM format should be accepted."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("voice.webm", io.BytesIO(b"webm-data"), "audio/webm")},
        headers=AUTH_HEADERS,
    )
    assert response.status_code == 200


def test_transcribe_m4a_accepted(client):
    """M4A format should be accepted."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("voice.m4a", io.BytesIO(b"m4a-data"), "audio/m4a")},
        headers=AUTH_HEADERS,
    )
    assert response.status_code == 200


def test_transcribe_no_auth_returns_401_or_403(client):
    """Transcribe without auth should return 401 or 403."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("test.wav", io.BytesIO(b"audio-data"), "audio/wav")},
    )
    assert response.status_code in (401, 403)
