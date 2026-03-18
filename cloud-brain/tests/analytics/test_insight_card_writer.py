import pytest
import json
from unittest.mock import AsyncMock, MagicMock, patch
from app.analytics.insight_signal_detector import InsightSignal
from app.analytics.user_focus_profile import UserFocusProfile
from app.analytics.insight_card_writer import InsightCardWriter


def _signal():
    return InsightSignal(
        signal_type="trend_decline",
        category="A",
        metrics=["steps"],
        values={"pct_change": -37.5, "recent_avg": 5000.0},
        severity=3,
        actionable=True,
        focus_relevant=True,
        title_hint="Steps declining",
        data_payload={"metric": "steps"},
    )


def _focus():
    return UserFocusProfile(
        stated_goals=["fitness"],
        inferred_focus="performance",
        focus_metrics=["steps"],
        deprioritised_metrics=[],
        coach_persona="balanced",
        fitness_level="active",
        units_system="metric",
    )


def _mock_llm_response(content: str):
    mock = MagicMock()
    mock.choices = [MagicMock(message=MagicMock(content=content))]
    return mock


@pytest.mark.asyncio
async def test_llm_success_returns_cards():
    cards_json = json.dumps(
        [
            {
                "type": "trend_decline",
                "title": "Steps falling",
                "body": "Your steps dropped 37%.",
                "priority": 3,
                "reasoning": "Trend detected.",
            }
        ]
    )
    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(return_value=_mock_llm_response(cards_json))
        writer = InsightCardWriter(signals=[_signal()], focus=_focus(), target_date="2026-03-18")
        cards = await writer.write_cards()
    assert len(cards) == 1
    assert cards[0]["title"] == "Steps falling"


@pytest.mark.asyncio
async def test_malformed_json_falls_back_to_rule_based():
    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(return_value=_mock_llm_response("Not valid JSON!"))
        writer = InsightCardWriter(signals=[_signal()], focus=_focus(), target_date="2026-03-18")
        cards = await writer.write_cards()
    assert len(cards) >= 1
    assert "title" in cards[0]
    assert "body" in cards[0]


@pytest.mark.asyncio
async def test_api_error_falls_back_to_rule_based():
    from openai import APIError

    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(side_effect=APIError("timeout", request=MagicMock(), body=None))
        writer = InsightCardWriter(signals=[_signal()], focus=_focus(), target_date="2026-03-18")
        cards = await writer.write_cards()
    assert len(cards) >= 1


@pytest.mark.asyncio
async def test_minimum_card_guarantee_on_total_failure():
    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(side_effect=Exception("total failure"))
        # Patch rule_based too to force level 3
        with patch("app.analytics.insight_card_writer._rule_based_card", side_effect=Exception("also broken")):
            writer = InsightCardWriter(signals=[_signal()], focus=_focus(), target_date="2026-03-18")
            cards = await writer.write_cards()
    assert len(cards) == 1
    assert cards[0]["type"] == "welcome"


@pytest.mark.asyncio
async def test_empty_signals_returns_minimum_card():
    writer = InsightCardWriter(signals=[], focus=_focus(), target_date="2026-03-18")
    cards = await writer.write_cards()
    assert len(cards) == 1
    assert cards[0]["type"] == "welcome"


@pytest.mark.asyncio
async def test_markdown_fenced_json_is_parsed():
    """LLM sometimes wraps JSON in ```json ... ``` fences."""
    content = '```json\n[{"type":"trend_decline","title":"T","body":"B","priority":3,"reasoning":"R"}]\n```'
    with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
        MockLLM.return_value.chat = AsyncMock(return_value=_mock_llm_response(content))
        writer = InsightCardWriter(signals=[_signal()], focus=_focus(), target_date="2026-03-18")
        cards = await writer.write_cards()
    assert len(cards) == 1
    assert cards[0]["title"] == "T"


class TestInsightCardWriterValidation:
    """Tests for per-card validation in _call_llm()."""

    @pytest.mark.asyncio
    async def test_partial_valid_cards_returns_valid_only(self):
        """When LLM returns mixed valid/invalid cards, only valid ones are returned."""
        mixed_response = [
            {
                "type": "trend_decline",
                "title": "Sleep declining",
                "body": "Down 15%.",
                "priority": 3,
                "reasoning": "Trend.",
            },
            {"type": "broken_card"},  # Missing title, body, priority — should be skipped
        ]
        content = json.dumps(mixed_response)
        with patch("app.analytics.insight_card_writer.LLMClient") as MockLLM:
            MockLLM.return_value.chat = AsyncMock(return_value=_mock_llm_response(content))
            writer = InsightCardWriter(signals=[_signal()], focus=_focus(), target_date="2026-03-18")
            result = await writer._call_llm()

        assert result is not None
        assert len(result) == 1
        assert result[0]["title"] == "Sleep declining"
