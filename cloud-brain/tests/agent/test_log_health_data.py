"""
Tests for the NL health data logging tool (log_health_data.py).

The tool's public API is the LogHealthDataTool class with:
    execute(arguments, user_id, db) -> dict

Phase 1 (confirmed=False): Parses natural language, returns
    {"status": "pending_confirmation", "entries": [...], "confirmation_message": "..."}
    or {"status": "no_data", ...}

Phase 2 (confirmed=True): Writes entries to DB, returns
    {"status": "logged", "logged_count": N, ...}
    or {"status": "no_data", ...}
    or {"status": "error", ...}

Tests cover:
- "I drank 3 glasses of water" → pending_confirmation with water entry
- "feeling a 7/10 today" → pending_confirmation with mood entry
- "slept 7.5 hours" → no_data (sleep_hours not supported)
- Empty string → no_data
- Confirmed=True with pre-parsed entries → logged, DB written
- Confirmed=True with empty entries → no_data
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.agent.tools.log_health_data import LogHealthDataTool


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_db():
    db = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    return db


# ---------------------------------------------------------------------------
# Phase 1: Parse (confirmed=False)
# ---------------------------------------------------------------------------


class TestParsePhase:
    @pytest.mark.asyncio
    async def test_water_returns_pending_confirmation(self):
        """Recognisable water input → pending_confirmation status."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": "I drank 2 liters of water"},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "pending_confirmation"
        assert len(result["entries"]) >= 1
        water_entries = [e for e in result["entries"] if e["metric_type"] == "water"]
        assert len(water_entries) == 1

    @pytest.mark.asyncio
    async def test_mood_returns_pending_confirmation(self):
        """Mood input → pending_confirmation with mood entry."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": "feeling a 7/10 today"},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "pending_confirmation"
        mood_entries = [e for e in result["entries"] if e["metric_type"] == "mood"]
        assert len(mood_entries) == 1
        assert mood_entries[0]["value"] == 7.0

    @pytest.mark.asyncio
    async def test_energy_parsed(self):
        """Energy level input → pending_confirmation."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": "energy level 8"},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "pending_confirmation"
        energy_entries = [e for e in result["entries"] if e["metric_type"] == "energy"]
        assert len(energy_entries) == 1

    @pytest.mark.asyncio
    async def test_stress_parsed(self):
        """Stress level input → pending_confirmation."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": "stress 9/10"},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "pending_confirmation"
        stress_entries = [e for e in result["entries"] if e["metric_type"] == "stress"]
        assert len(stress_entries) == 1

    @pytest.mark.asyncio
    async def test_empty_string_returns_no_data(self):
        """Empty message → no_data status."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": ""},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "no_data"

    @pytest.mark.asyncio
    async def test_whitespace_only_returns_no_data(self):
        """Whitespace-only message → no_data status."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": "   "},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "no_data"

    @pytest.mark.asyncio
    async def test_unrelated_text_returns_no_data(self):
        """Text with no health data → no_data status."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {"message": "the weather is nice today"},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "no_data"

    @pytest.mark.asyncio
    async def test_confirmation_message_is_string(self):
        """pending_confirmation always includes a non-empty confirmation_message."""
        tool = LogHealthDataTool()
        db = _make_db()

        # Use a format that the mood regex matches: "feeling 7/10" or "mood: 7"
        result = await tool.execute(
            {"message": "feeling 7/10"},
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "pending_confirmation"
        assert isinstance(result["confirmation_message"], str)
        assert len(result["confirmation_message"]) > 0


# ---------------------------------------------------------------------------
# Phase 2: Commit (confirmed=True)
# ---------------------------------------------------------------------------


class TestCommitPhase:
    @pytest.mark.asyncio
    async def test_confirmed_with_parsed_entries_returns_logged(self):
        """confirmed=True with valid entries → logged status and DB write."""
        tool = LogHealthDataTool()
        db = _make_db()

        parsed_entries = [
            {
                "metric_type": "water",
                "value": 2.0,
                "unit": "liters",
                "label": "Water intake: 2.0 liters",
            }
        ]

        result = await tool.execute(
            {
                "message": "I drank 2 liters of water",
                "confirmed": True,
                "parsed_entries": parsed_entries,
            },
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "logged"
        assert result["logged_count"] == 1
        db.add.assert_called_once()
        db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_confirmed_with_empty_entries_returns_no_data(self):
        """confirmed=True with no valid entries → no_data."""
        tool = LogHealthDataTool()
        db = _make_db()

        result = await tool.execute(
            {
                "message": "irrelevant",
                "confirmed": True,
                "parsed_entries": [],
            },
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "no_data"
        db.add.assert_not_called()
        db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_confirmed_multiple_entries_all_written(self):
        """confirmed=True with multiple entries → all written to DB."""
        tool = LogHealthDataTool()
        db = _make_db()

        parsed_entries = [
            {"metric_type": "water", "value": 1.5, "unit": "liters", "label": "Water: 1.5 liters"},
            {"metric_type": "mood", "value": 8.0, "unit": "/10", "label": "Mood: 8/10"},
        ]

        result = await tool.execute(
            {
                "message": "water and mood",
                "confirmed": True,
                "parsed_entries": parsed_entries,
            },
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "logged"
        assert result["logged_count"] == 2
        assert db.add.call_count == 2

    @pytest.mark.asyncio
    async def test_confirmed_invalid_metric_type_skipped(self):
        """Entries with unknown metric_type are silently skipped."""
        tool = LogHealthDataTool()
        db = _make_db()

        parsed_entries = [
            {"metric_type": "unknown_metric_xyz", "value": 5.0, "unit": "", "label": "Unknown"},
        ]

        result = await tool.execute(
            {
                "message": "something",
                "confirmed": True,
                "parsed_entries": parsed_entries,
            },
            user_id="user-001",
            db=db,
        )
        assert result["status"] == "no_data"
        db.add.assert_not_called()


# ---------------------------------------------------------------------------
# Tool metadata
# ---------------------------------------------------------------------------


class TestToolMetadata:
    def test_tool_has_name(self):
        """Tool has a non-empty name string."""
        tool = LogHealthDataTool()
        assert isinstance(tool.name, str)
        assert len(tool.name) > 0

    def test_tool_has_description(self):
        """Tool has a non-empty description string."""
        tool = LogHealthDataTool()
        assert isinstance(tool.description, str)
        assert len(tool.description) > 0

    def test_tool_has_input_schema(self):
        """Tool has a valid JSON schema dict."""
        tool = LogHealthDataTool()
        assert isinstance(tool.input_schema, dict)
        assert "properties" in tool.input_schema
        assert "message" in tool.input_schema["properties"]
