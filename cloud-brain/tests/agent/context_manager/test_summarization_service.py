"""Tests for the rolling summarization service."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.agent.context_manager.summarization_service import summarize_oldest_messages


def _make_message(role: str, content: str, is_summarized: bool = False) -> MagicMock:
    msg = MagicMock()
    msg.id = str(uuid.uuid4())
    msg.role = role
    msg.content = content
    msg.is_summarized = is_summarized
    msg.created_at = datetime.now(timezone.utc)
    return msg


class TestSummarizeOldestMessages:
    @pytest.mark.asyncio
    async def test_skips_when_fewer_than_15_eligible(self) -> None:
        """Does nothing when there are fewer than 15 summarizable messages."""
        mock_llm = AsyncMock()

        with patch(
            "app.agent.context_manager.summarization_service.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            # Simulate: recent_ids query returns 10 recent IDs,
            # eligible query returns only 5 messages (< 15 threshold)
            recent_scalars = MagicMock()
            recent_scalars.all.return_value = [str(uuid.uuid4()) for _ in range(10)]
            mock_db.execute.side_effect = [
                MagicMock(scalars=lambda: recent_scalars),  # recent IDs query
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=lambda: [_make_message("user", f"msg {i}") for i in range(5)]))),  # eligible query
            ]

            await summarize_oldest_messages("conv-123", mock_llm)

        mock_llm.chat.assert_not_called()

    @pytest.mark.asyncio
    async def test_calls_llm_and_stores_summary_when_eligible(self) -> None:
        """Calls LLM and writes summary when >= 15 eligible messages exist."""
        mock_llm = AsyncMock()
        mock_response = MagicMock()
        mock_response.choices[0].message.content = "User is training for a marathon. Has knee injury."
        mock_llm.chat.return_value = mock_response

        eligible_msgs = [_make_message("user" if i % 2 == 0 else "assistant", f"message {i}") for i in range(20)]

        with patch(
            "app.agent.context_manager.summarization_service.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            recent_scalars = MagicMock()
            recent_scalars.all.return_value = []  # No recent IDs to exclude
            mock_db.execute.side_effect = [
                MagicMock(scalars=lambda: recent_scalars),
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=lambda: eligible_msgs))),
                MagicMock(scalar_one_or_none=MagicMock(return_value=MagicMock())),  # Conversation fetch
            ]

            await summarize_oldest_messages("conv-123", mock_llm)

        mock_llm.chat.assert_called_once()
        # All eligible messages should be marked as summarized
        for msg in eligible_msgs:
            assert msg.is_summarized is True

    @pytest.mark.asyncio
    async def test_does_not_raise_on_llm_failure(self) -> None:
        """Service logs the error and returns without raising."""
        mock_llm = AsyncMock()
        mock_llm.chat.side_effect = RuntimeError("LLM unavailable")

        eligible_msgs = [_make_message("user", f"msg {i}") for i in range(20)]

        with patch(
            "app.agent.context_manager.summarization_service.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            recent_scalars = MagicMock()
            recent_scalars.all.return_value = []
            mock_db.execute.side_effect = [
                MagicMock(scalars=lambda: recent_scalars),
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=lambda: eligible_msgs))),
            ]

            # Should not raise
            await summarize_oldest_messages("conv-123", mock_llm)
