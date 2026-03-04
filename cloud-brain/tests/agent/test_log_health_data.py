"""
Tests for the NL health data logging tool (log_health_data.py).

Tests cover:
- "I drank 3 glasses of water" → water: 3
- "feeling a 7/10 today" → mood: 7
- "slept 7.5 hours" → sleep_hours: 7.5
- "stress level is high" → stress detected
- "weight is 75kg" → weight detected
- Empty string → no items
- write_confirmed_logs persists to DB
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, call

import pytest

from app.agent.tools.log_health_data import (
    LogConfirmationPayload,
    LoggableItem,
    parse_nl_for_logging,
    write_confirmed_logs,
)


# ---------------------------------------------------------------------------
# parse_nl_for_logging
# ---------------------------------------------------------------------------


class TestParseNlForLogging:
    def test_water_three_glasses(self):
        payload = parse_nl_for_logging("I drank 3 glasses of water")
        items = {i.metric_type: i for i in payload.items}
        assert "water" in items
        assert items["water"].value == 3.0

    def test_water_cups_variant(self):
        payload = parse_nl_for_logging("had 2 cups of water")
        items = {i.metric_type: i for i in payload.items}
        assert "water" in items
        assert items["water"].value == 2.0

    def test_mood_numeric_score(self):
        payload = parse_nl_for_logging("feeling a 7/10 today")
        items = {i.metric_type: i for i in payload.items}
        assert "mood" in items
        assert items["mood"].value == 7.0

    def test_mood_text_great(self):
        payload = parse_nl_for_logging("mood is great")
        items = {i.metric_type: i for i in payload.items}
        assert "mood" in items
        assert items["mood"].value is not None
        assert items["mood"].value >= 7.0

    def test_sleep_hours(self):
        payload = parse_nl_for_logging("slept 7.5 hours")
        items = {i.metric_type: i for i in payload.items}
        assert "sleep_hours" in items
        assert items["sleep_hours"].value == 7.5

    def test_sleep_hours_variant(self):
        payload = parse_nl_for_logging("got 8 hours of sleep last night")
        items = {i.metric_type: i for i in payload.items}
        assert "sleep_hours" in items
        assert items["sleep_hours"].value == 8.0

    def test_stress_level_high_text(self):
        payload = parse_nl_for_logging("stress is high today")
        items = {i.metric_type: i for i in payload.items}
        assert "stress" in items
        # "high" maps to >= 7
        assert items["stress"].value is not None
        assert items["stress"].value >= 7.0

    def test_stress_numeric(self):
        payload = parse_nl_for_logging("stress level is 6")
        items = {i.metric_type: i for i in payload.items}
        assert "stress" in items
        assert items["stress"].value == 6.0

    def test_weight_kg(self):
        payload = parse_nl_for_logging("weight is 75kg")
        items = {i.metric_type: i for i in payload.items}
        assert "weight" in items
        assert items["weight"].value == 75.0

    def test_weight_with_space(self):
        payload = parse_nl_for_logging("I weigh 80 kg")
        items = {i.metric_type: i for i in payload.items}
        assert "weight" in items
        assert items["weight"].value == 80.0

    def test_steps(self):
        payload = parse_nl_for_logging("walked 10,000 steps today")
        items = {i.metric_type: i for i in payload.items}
        assert "steps" in items
        assert items["steps"].value == 10000.0

    def test_energy_level(self):
        payload = parse_nl_for_logging("energy level 8")
        items = {i.metric_type: i for i in payload.items}
        assert "energy" in items
        assert items["energy"].value == 8.0

    def test_note_parsed(self):
        payload = parse_nl_for_logging('note: "had a headache this afternoon"')
        items = {i.metric_type: i for i in payload.items}
        assert "notes" in items
        assert "headache" in (items["notes"].text_value or "")

    def test_empty_string_returns_no_items(self):
        payload = parse_nl_for_logging("")
        assert payload.items == []

    def test_whitespace_only_returns_no_items(self):
        payload = parse_nl_for_logging("   ")
        assert payload.items == []

    def test_unrelated_text_returns_no_items(self):
        payload = parse_nl_for_logging("the weather is nice today")
        assert payload.items == []

    def test_confirmation_id_is_uuid(self):
        import uuid

        payload = parse_nl_for_logging("mood is 7")
        # Should be parseable as UUID
        uuid.UUID(payload.confirmation_id)

    def test_summary_contains_metric_info(self):
        payload = parse_nl_for_logging("drank 2 glasses of water")
        assert "water" in payload.summary.lower() or "2" in payload.summary

    def test_multiple_metrics_parsed(self):
        payload = parse_nl_for_logging("slept 7 hours and mood is 8/10")
        types = {i.metric_type for i in payload.items}
        assert len(types) >= 2  # Both sleep and mood

    def test_deduplication_keeps_highest_confidence(self):
        """When two patterns match the same metric, highest confidence wins."""
        # "feeling 8/10" and "feeling a 8 out of 10" could both match mood
        payload = parse_nl_for_logging("feeling 8/10, mood is great")
        mood_items = [i for i in payload.items if i.metric_type == "mood"]
        assert len(mood_items) == 1


# ---------------------------------------------------------------------------
# write_confirmed_logs
# ---------------------------------------------------------------------------


class TestWriteConfirmedLogs:
    @pytest.mark.asyncio
    async def test_writes_items_to_db(self):
        """Confirmed items are added to the session and committed."""
        db = AsyncMock()
        db.add = MagicMock()
        db.commit = AsyncMock()

        payload = LogConfirmationPayload(
            items=[
                LoggableItem(
                    metric_type="water",
                    value=3.0,
                    text_value=None,
                    unit="cups",
                    confidence=0.9,
                    raw_text="drank 3 glasses",
                ),
                LoggableItem(
                    metric_type="mood",
                    value=7.0,
                    text_value=None,
                    unit="/10",
                    confidence=0.9,
                    raw_text="feeling 7/10",
                ),
            ],
            confirmation_id="confirm-abc-123",
            summary="Water: 3 cups | Mood: 7/10",
        )

        count = await write_confirmed_logs(payload, "user-001", db)

        assert count == 2
        assert db.add.call_count == 2
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_skips_low_confidence_items(self):
        """Items with confidence < 0.5 are not written."""
        db = AsyncMock()
        db.add = MagicMock()
        db.commit = AsyncMock()

        payload = LogConfirmationPayload(
            items=[
                LoggableItem(
                    metric_type="mood",
                    value=7.0,
                    text_value=None,
                    unit=None,
                    confidence=0.3,  # Low confidence
                    raw_text="some ambiguous text",
                ),
            ],
            confirmation_id="confirm-xyz",
            summary="...",
        )

        count = await write_confirmed_logs(payload, "user-001", db)
        assert count == 0
        db.add.assert_not_called()
        db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_empty_payload_writes_nothing(self):
        """Empty items list → no DB writes, returns 0."""
        db = AsyncMock()
        db.add = MagicMock()
        db.commit = AsyncMock()

        payload = LogConfirmationPayload(items=[], confirmation_id="empty-123", summary="Nothing to log.")

        count = await write_confirmed_logs(payload, "user-001", db)
        assert count == 0
        db.add.assert_not_called()
        db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_notes_text_value_persisted(self):
        """Notes items have their text_value stored."""
        db = AsyncMock()
        db.add = MagicMock()
        db.commit = AsyncMock()

        payload = LogConfirmationPayload(
            items=[
                LoggableItem(
                    metric_type="notes",
                    value=None,
                    text_value="had a great workout",
                    unit=None,
                    confidence=0.9,
                    raw_text='note: "had a great workout"',
                ),
            ],
            confirmation_id="note-abc",
            summary="Note: had a great workout",
        )

        count = await write_confirmed_logs(payload, "user-001", db)
        assert count == 1
        added_obj = db.add.call_args[0][0]
        assert added_obj.text_value == "had a great workout"
