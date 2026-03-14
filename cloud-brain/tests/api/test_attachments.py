"""
Tests for file attachment routes:
  POST /api/v1/chat/{conversation_id}/attachments

Tests cover:
- Upload JPEG succeeds
- Upload oversized file returns 413
- Upload unsupported type returns 415
- More than 3 files returns 400
- Text extraction from TXT file
- Auth guard returns 401
"""

from __future__ import annotations

import io
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.main import app

USER_ID = "user-attach-001"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}
CONVO_ID = "convo-abc-123"
ENDPOINT = f"/api/v1/chat/{CONVO_ID}/attachments"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def authed_client():
    """TestClient with authentication bypassed."""
    app.dependency_overrides[get_authenticated_user_id] = lambda: USER_ID
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


class TestUploadAttachment:
    def test_upload_jpeg_succeeds(self, authed_client):
        """Valid JPEG under size limit → 200 with attachment metadata."""
        # 1x1 white JPEG (tiny valid JPEG)
        tiny_jpeg = (
            b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
            b"\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t"
            b"\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a"
            b"\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342\x1e"
            b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f"
            b"\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00"
            b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01"
            b"\x00\x00?\x00\xfb\x26\x8a(\x03\xff\xd9"
        )

        mock_result = {
            "extracted_facts": ["A small white image."],
            "food_data": None,
            "size_bytes": len(tiny_jpeg),
            "content_type": "image/jpeg",
            "filename": "test.jpg",
        }

        with patch(
            "app.api.v1.attachments._processor.process",
            new_callable=AsyncMock,
            return_value=mock_result,
        ):
            resp = authed_client.post(
                ENDPOINT,
                files=[("files", ("test.jpg", io.BytesIO(tiny_jpeg), "image/jpeg"))],
                headers=AUTH_HEADERS,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["filename"] == "test.jpg"
        assert data[0]["content_type"] == "image/jpeg"

    def test_upload_txt_succeeds(self, authed_client):
        """Plain text file → 200."""
        content = b"Health log: slept 8 hours, steps 9000."
        mock_result = {
            "extracted_facts": ["Sleep: 8 hours, Steps: 9000."],
            "food_data": None,
            "size_bytes": len(content),
            "content_type": "text/plain",
            "filename": "health.txt",
        }

        with patch(
            "app.api.v1.attachments._processor.process",
            new_callable=AsyncMock,
            return_value=mock_result,
        ):
            resp = authed_client.post(
                ENDPOINT,
                files=[("files", ("health.txt", io.BytesIO(content), "text/plain"))],
                headers=AUTH_HEADERS,
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data[0]["extracted_facts"] == ["Sleep: 8 hours, Steps: 9000."]


# ---------------------------------------------------------------------------
# Error cases
# ---------------------------------------------------------------------------


class TestUploadErrors:
    def test_oversized_file_returns_413(self, authed_client):
        """File exceeding 10MB → 413."""
        # 11MB of zeros
        big_content = b"\x00" * (11 * 1024 * 1024)
        resp = authed_client.post(
            ENDPOINT,
            files=[("files", ("big.txt", io.BytesIO(big_content), "text/plain"))],
            headers=AUTH_HEADERS,
        )
        assert resp.status_code == 413

    def test_unsupported_type_returns_415(self, authed_client):
        """MIME type not in ALLOWED_TYPES → 415."""
        content = b"<html>not allowed</html>"
        resp = authed_client.post(
            ENDPOINT,
            files=[("files", ("page.html", io.BytesIO(content), "text/html"))],
            headers=AUTH_HEADERS,
        )
        assert resp.status_code == 415

    def test_more_than_three_files_returns_400(self, authed_client):
        """More than 3 files in one request → 400."""
        files = [("files", (f"file{i}.txt", io.BytesIO(b"content"), "text/plain")) for i in range(4)]
        resp = authed_client.post(ENDPOINT, files=files, headers=AUTH_HEADERS)
        assert resp.status_code == 400
        assert "Maximum" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------


class TestAttachmentAuthGuard:
    def test_unauthenticated_upload_returns_401(self):
        """No auth header → 401."""
        app.dependency_overrides.clear()
        with TestClient(app, raise_server_exceptions=False) as c:
            content = b"some text"
            resp = c.post(
                ENDPOINT,
                files=[("files", ("test.txt", io.BytesIO(content), "text/plain"))],
            )
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Text extraction integration test (processor-level)
# ---------------------------------------------------------------------------


class TestAttachmentProcessorTextExtraction:
    @pytest.mark.asyncio
    async def test_extract_txt_content(self):
        """AttachmentProcessor extracts text from plain text files."""
        from app.services.attachment_processor import AttachmentProcessor

        processor = AttachmentProcessor()
        content = b"Today I walked 8000 steps and slept well."
        result = await processor._extract_text(content, "text/plain")
        assert "8000 steps" in result

    @pytest.mark.asyncio
    async def test_extract_csv_content(self):
        """AttachmentProcessor extracts text from CSV files."""
        from app.services.attachment_processor import AttachmentProcessor

        processor = AttachmentProcessor()
        csv_content = b"date,steps,sleep_hours\n2026-03-04,9000,7.5\n2026-03-05,8500,8.0\n"
        result = await processor._extract_text(csv_content, "text/csv")
        assert "steps" in result.lower()
        assert "9000" in result

    def test_is_food_image_detects_food_keywords(self):
        """_is_food_image returns True for descriptions with food keywords."""
        from app.services.attachment_processor import AttachmentProcessor

        processor = AttachmentProcessor()
        assert processor._is_food_image("A plate of pasta with tomato sauce") is True
        assert processor._is_food_image("A person running on a track") is False
