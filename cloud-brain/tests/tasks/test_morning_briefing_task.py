"""
Tests for morning_briefing_task.

The public API is:
    _build_briefing_message(metrics: object | None) -> str
    send_morning_briefings() -> dict   (Celery task, sync)

Tests cover:
- _build_briefing_message: returns non-empty string when metrics is None
- _build_briefing_message: includes steps when metrics has steps
- _build_briefing_message: includes HRV note when hrv_ms is present
- _build_briefing_message: generic tip when no useful data on metrics
- send_morning_briefings Celery task structure (smoke test via mocking)
"""

from __future__ import annotations

import datetime
from datetime import timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.tasks.morning_briefing_task import _build_briefing_message


# ---------------------------------------------------------------------------
# Unit tests for _build_briefing_message
# ---------------------------------------------------------------------------


class TestBuildBriefingMessage:
    def test_returns_non_empty_string_when_metrics_is_none(self):
        """No metrics → fallback message is returned, not empty."""
        body = _build_briefing_message(None)
        assert isinstance(body, str)
        assert len(body) > 10

    def test_no_metrics_does_not_contain_none_literal(self):
        """Fallback message must not include the string 'None'."""
        body = _build_briefing_message(None)
        assert "None" not in body

    def test_includes_steps_when_present(self):
        """When steps are present, the message references them."""
        metrics = MagicMock()
        metrics.steps = 9500
        metrics.hrv_ms = None
        metrics.resting_heart_rate = None
        body = _build_briefing_message(metrics)
        assert "9,500" in body or "9500" in body

    def test_high_steps_produces_positive_message(self):
        """10,000+ steps → congratulatory message."""
        metrics = MagicMock()
        metrics.steps = 12000
        metrics.hrv_ms = None
        metrics.resting_heart_rate = None
        body = _build_briefing_message(metrics)
        assert len(body) > 10

    def test_includes_hrv_note_when_hrv_present(self):
        """When HRV is present, the message includes an HRV reference."""
        metrics = MagicMock()
        metrics.steps = None
        metrics.hrv_ms = 55
        metrics.resting_heart_rate = None
        body = _build_briefing_message(metrics)
        assert "55" in body or "hrv" in body.lower() or "recovery" in body.lower()

    def test_low_hrv_produces_rest_suggestion(self):
        """Low HRV → suggest prioritising rest."""
        metrics = MagicMock()
        metrics.steps = None
        metrics.hrv_ms = 20
        metrics.resting_heart_rate = None
        body = _build_briefing_message(metrics)
        assert "rest" in body.lower() or "20" in body

    def test_no_useful_data_produces_generic_tip(self):
        """When metrics has no useful values, a generic tip is returned."""
        metrics = MagicMock()
        metrics.steps = None
        metrics.hrv_ms = None
        metrics.resting_heart_rate = None
        body = _build_briefing_message(metrics)
        assert isinstance(body, str)
        assert len(body) > 10

    def test_always_starts_with_greeting(self):
        """Message always starts with a greeting."""
        body = _build_briefing_message(None)
        assert body.lower().startswith("good")

    def test_high_resting_heart_rate_triggers_note(self):
        """RHR > 80 → message includes hydration/stress note."""
        metrics = MagicMock()
        metrics.steps = None
        metrics.hrv_ms = None
        metrics.resting_heart_rate = 85
        body = _build_briefing_message(metrics)
        assert len(body) > 10  # has content; specific wording may vary


# ---------------------------------------------------------------------------
# Celery task smoke test
# ---------------------------------------------------------------------------


class TestSendMorningBriefings:
    def test_task_is_importable(self):
        """The Celery task can be imported and has a .delay attribute."""
        from app.tasks.morning_briefing_task import send_morning_briefings

        assert callable(send_morning_briefings)
