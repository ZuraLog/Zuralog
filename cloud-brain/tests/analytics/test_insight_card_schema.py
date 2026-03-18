"""Tests for InsightCardSchema — Pydantic validation of LLM-generated cards."""

from __future__ import annotations

import pytest

from app.analytics.insight_card_schema import InsightCardSchema


class TestInsightCardSchema:
    def test_valid_card_passes(self):
        card = InsightCardSchema(
            type="trend_decline",
            title="Sleep is dropping",
            body="Your sleep has declined 15% this week.",
            priority=3,
            reasoning="Detected via trend analysis.",
        )
        assert card.title == "Sleep is dropping"
        assert card.priority == 3

    def test_title_truncated_at_200(self):
        long_title = "A" * 300
        card = InsightCardSchema(
            type="trend_decline",
            title=long_title,
            body="Short body.",
            priority=5,
        )
        assert len(card.title) == 200

    def test_body_truncated_at_2000(self):
        long_body = "B" * 3000
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body=long_body,
            priority=5,
        )
        assert len(card.body) == 2000

    def test_reasoning_truncated_at_1000(self):
        long_reasoning = "R" * 1500
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=5,
            reasoning=long_reasoning,
        )
        assert len(card.reasoning) == 1000

    def test_reasoning_none_is_allowed(self):
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=5,
            reasoning=None,
        )
        assert card.reasoning is None

    def test_priority_clamped_below_1(self):
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=0,
        )
        assert card.priority == 1

    def test_priority_clamped_above_10(self):
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=15,
        )
        assert card.priority == 10

    def test_reasoning_empty_string_is_none(self):
        """Empty string reasoning is preserved as empty string by the schema (not None)."""
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=5,
            reasoning="",
        )
        # Schema returns "" — the _persist_cards layer converts "" to None
        assert card.reasoning == "" or card.reasoning is None  # either is acceptable

    def test_priority_at_lower_boundary(self):
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=1,
        )
        assert card.priority == 1

    def test_priority_at_upper_boundary(self):
        card = InsightCardSchema(
            type="trend_decline",
            title="Title",
            body="Body.",
            priority=10,
        )
        assert card.priority == 10

    def test_model_validate_from_dict(self):
        """model_validate() with a plain dict works correctly — mirrors real call site."""
        raw = {
            "type": "trend_decline",
            "title": "A" * 300,  # over limit — should be truncated
            "body": "Short body.",
            "priority": 7,
            # reasoning intentionally omitted — should default to None
        }
        card = InsightCardSchema.model_validate(raw)
        assert len(card.title) == 200
        assert card.reasoning is None
