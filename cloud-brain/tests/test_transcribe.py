"""
Life Logger Cloud Brain — Transcribe Endpoint Tests.

Tests for the voice transcription endpoint. Uses mock STT
since the endpoint is scaffolded with mock transcription.
"""

import io

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """Create a test client."""
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


def test_transcribe_valid_audio(client):
    """Valid audio upload should return transcription text."""
    audio_content = b"fake-audio-data"
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("test.wav", io.BytesIO(audio_content), "audio/wav")},
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
    )
    assert response.status_code == 400


def test_transcribe_mp3_accepted(client):
    """MP3 format should be accepted."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("voice.mp3", io.BytesIO(b"mp3-data"), "audio/mpeg")},
    )
    assert response.status_code == 200


def test_transcribe_webm_accepted(client):
    """WebM format should be accepted."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("voice.webm", io.BytesIO(b"webm-data"), "audio/webm")},
    )
    assert response.status_code == 200


def test_transcribe_m4a_accepted(client):
    """M4A format should be accepted."""
    response = client.post(
        "/api/v1/transcribe",
        files={"file": ("voice.m4a", io.BytesIO(b"m4a-data"), "audio/m4a")},
    )
    assert response.status_code == 200
