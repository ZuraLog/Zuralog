"""Tests for the message classifier."""
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.agent.classifier import MessageTier, _compute_signals, classify_message


class TestComputeSignals:
    def test_short_simple(self):
        signals = _compute_signals("hi")
        assert signals["word_count"] == 1
        assert signals["has_plan_keyword"] is False

    def test_plan_keyword(self):
        signals = _compute_signals("create a training plan for me")
        assert signals["has_plan_keyword"] is True

    def test_question_mark(self):
        signals = _compute_signals("what were my steps yesterday?")
        assert signals["has_question_mark"] is True


class TestClassifyMessage:
    def _mock_response(self, content: str):
        msg = MagicMock()
        msg.content = content
        choice = MagicMock()
        choice.message = msg
        resp = MagicMock()
        resp.choices = [choice]
        return resp

    @pytest.mark.asyncio
    async def test_short_message_bypass(self):
        """Short messages with no plan keywords skip the LLM entirely."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            result = await classify_message("hi there")
            mock_client_cls.assert_not_called()
        assert result == MessageTier.standard

    @pytest.mark.asyncio
    async def test_short_with_plan_keyword_calls_llm(self):
        """Short message with a plan keyword still calls the LLM."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            mock_client = MagicMock()
            mock_client_cls.return_value = mock_client
            mock_client.chat = MagicMock()
            mock_client.chat.completions = MagicMock()
            mock_client.chat.completions.create = AsyncMock(
                return_value=self._mock_response("deep_analysis")
            )
            result = await classify_message("make a plan")
        assert result == MessageTier.deep_analysis

    @pytest.mark.asyncio
    async def test_llm_returns_deep_analysis(self):
        """Long message → LLM returns deep_analysis → deep_analysis."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            mock_client = MagicMock()
            mock_client_cls.return_value = mock_client
            mock_client.chat.completions.create = AsyncMock(
                return_value=self._mock_response("deep_analysis")
            )
            result = await classify_message(
                "analyze my training load and HRV correlation over the past 3 months"
            )
        assert result == MessageTier.deep_analysis

    @pytest.mark.asyncio
    async def test_llm_returns_standard(self):
        """Long message → LLM returns standard → standard."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            mock_client = MagicMock()
            mock_client_cls.return_value = mock_client
            mock_client.chat.completions.create = AsyncMock(
                return_value=self._mock_response("standard")
            )
            result = await classify_message(
                "how many calories should I eat today based on my activity level"
            )
        assert result == MessageTier.standard

    @pytest.mark.asyncio
    async def test_llm_returns_garbage_falls_back(self):
        """Unknown LLM output falls back to standard."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            mock_client = MagicMock()
            mock_client_cls.return_value = mock_client
            mock_client.chat.completions.create = AsyncMock(
                return_value=self._mock_response("maybe_deep")
            )
            result = await classify_message(
                "what is my weekly training volume trend analysis"
            )
        assert result == MessageTier.standard

    @pytest.mark.asyncio
    async def test_timeout_falls_back(self):
        """Timeout falls back to standard."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            mock_client = MagicMock()
            mock_client_cls.return_value = mock_client
            mock_client.chat.completions.create = AsyncMock(
                side_effect=asyncio.TimeoutError()
            )
            result = await classify_message(
                "analyze my sleep quality and recovery correlation over the last month"
            )
        assert result == MessageTier.standard

    @pytest.mark.asyncio
    async def test_api_error_falls_back(self):
        """Any API error falls back to standard."""
        with patch("app.agent.classifier.AsyncOpenAI") as mock_client_cls:
            mock_client = MagicMock()
            mock_client_cls.return_value = mock_client
            mock_client.chat.completions.create = AsyncMock(
                side_effect=Exception("connection refused")
            )
            result = await classify_message(
                "build me a 12 week training program for a half marathon"
            )
        assert result == MessageTier.standard
