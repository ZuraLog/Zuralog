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
