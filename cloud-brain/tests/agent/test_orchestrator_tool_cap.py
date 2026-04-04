"""Tests for the per-turn tool call cap in the Orchestrator."""

from __future__ import annotations

import pytest

from app.agent.orchestrator import MAX_TOOL_TURNS, MAX_TOOLS_PER_TURN


class TestMaxToolsPerTurn:
    def test_constant_exists_and_is_reasonable(self):
        assert isinstance(MAX_TOOLS_PER_TURN, int)
        assert 1 <= MAX_TOOLS_PER_TURN <= 10

    def test_max_tool_turns_unchanged(self):
        assert MAX_TOOL_TURNS == 5
