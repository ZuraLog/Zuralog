"""Tests for image attachment handling on the coach chat path.

Covers:
- _process_attachments splits image URLs from text context
- Orchestrator._build_messages emits a multimodal content array when
  image URLs are present (OpenAI / OpenRouter vision format)
"""

from unittest.mock import AsyncMock, MagicMock

from app.api.v1.chat import _process_attachments
from app.agent.orchestrator import Orchestrator


class TestProcessAttachmentsImageHandling:
    def test_returns_empty_when_no_attachments(self):
        text, images = _process_attachments([])
        assert text == ""
        assert images == []

    def test_image_https_url_captured(self):
        atts = [{
            "type": "image",
            "filename": "photo.jpg",
            "signed_url": "https://cdn.example.com/photo.jpg",
        }]
        text, images = _process_attachments(atts)
        assert images == ["https://cdn.example.com/photo.jpg"]
        # Image no longer injected as a text placeholder in the message body.
        assert "[User attached image" not in text

    def test_non_https_url_dropped(self):
        atts = [{
            "type": "image",
            "filename": "bad.jpg",
            "signed_url": "http://not-secure.example.com/bad.jpg",
        }]
        text, images = _process_attachments(atts)
        assert images == []

    def test_missing_url_dropped(self):
        atts = [{
            "type": "image",
            "filename": "stub.jpg",
        }]
        text, images = _process_attachments(atts)
        assert images == []

    def test_url_fallback_used_when_signed_url_missing(self):
        atts = [{
            "type": "image",
            "filename": "photo.jpg",
            "url": "https://cdn.example.com/photo.jpg",
        }]
        _, images = _process_attachments(atts)
        assert images == ["https://cdn.example.com/photo.jpg"]

    def test_attachment_cap_enforced(self):
        atts = [
            {"type": "image", "filename": f"p{i}.jpg", "signed_url": f"https://cdn/x{i}.jpg"}
            for i in range(5)
        ]
        _, images = _process_attachments(atts)
        assert len(images) == 3

    def test_context_message_still_appended(self):
        atts = [{
            "type": "document",
            "filename": "notes.txt",
            "url": "https://cdn/notes.txt",
            "context_message": "some extracted text",
        }]
        text, images = _process_attachments(atts)
        assert "some extracted text" in text
        assert images == []


class TestBuildMessagesMultimodal:
    def _orchestrator(self) -> Orchestrator:
        return Orchestrator(
            mcp_client=MagicMock(),
            memory_store=AsyncMock(),
            llm_client=MagicMock(),
            usage_tracker=None,
        )

    def test_plain_text_builds_string_content(self):
        o = self._orchestrator()
        msgs = o._build_messages("sys", "hello", None, image_urls=None)
        user_msg = msgs[-1]
        assert user_msg["role"] == "user"
        assert user_msg["content"] == "hello"

    def test_with_image_urls_builds_multimodal_array(self):
        o = self._orchestrator()
        msgs = o._build_messages(
            "sys",
            "what is this?",
            None,
            image_urls=["https://cdn/a.jpg", "https://cdn/b.jpg"],
        )
        user_msg = msgs[-1]
        assert user_msg["role"] == "user"
        assert isinstance(user_msg["content"], list)
        # text block present
        assert any(
            item.get("type") == "text" and item.get("text") == "what is this?"
            for item in user_msg["content"]
        )
        # two image blocks in order
        image_items = [i for i in user_msg["content"] if i.get("type") == "image_url"]
        assert len(image_items) == 2
        assert image_items[0]["image_url"]["url"] == "https://cdn/a.jpg"
        assert image_items[1]["image_url"]["url"] == "https://cdn/b.jpg"

    def test_image_without_text_still_builds_array(self):
        o = self._orchestrator()
        msgs = o._build_messages(
            "sys",
            "",
            None,
            image_urls=["https://cdn/a.jpg"],
        )
        user_msg = msgs[-1]
        assert isinstance(user_msg["content"], list)
        # No text item when the message is empty.
        assert all(i.get("type") != "text" for i in user_msg["content"])
        assert user_msg["content"][0]["image_url"]["url"] == "https://cdn/a.jpg"

    def test_history_preserved(self):
        o = self._orchestrator()
        history = [{"role": "user", "content": "prior"}, {"role": "assistant", "content": "prior reply"}]
        msgs = o._build_messages("sys", "new", history, image_urls=["https://cdn/a.jpg"])
        assert msgs[0]["role"] == "system"
        assert msgs[1] == history[0]
        assert msgs[2] == history[1]
        assert msgs[3]["role"] == "user"
        assert isinstance(msgs[3]["content"], list)
