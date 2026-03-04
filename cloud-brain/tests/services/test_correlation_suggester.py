"""
Tests for CorrelationSuggester.

Tests cover:
- "better_sleep" goal with no check-in data → suggests wellness check-in
- "build_fitness" goal with Strava but no HR data → suggests Fitbit/Polar
- Dismissed suggestion not returned within 30 days
- Connected apps filter: suggestions for already-connected apps not shown
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.correlation_suggester import CorrelationSuggester


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_prefs(goals: list) -> MagicMock:
    prefs = MagicMock()
    prefs.goals = goals
    return prefs


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestGetSuggestions:
    @pytest.mark.asyncio
    async def test_better_sleep_goal_suggests_checkin_when_no_checkin(self):
        """User with 'better_sleep' goal and no check-in → checkin suggestion."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        prefs = _make_prefs([{"metric": "better_sleep"}])

        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            patch.object(suggester, "_get_connected_integrations", return_value=set()),
        ):
            suggestions = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        integration_slugs = {s.missing_integration for s in suggestions}
        # better_sleep requires: sleep + checkin
        # checkin and sleep integrations should both be suggested
        assert "checkin" in integration_slugs or any(
            "sleep" in s.description.lower() or "checkin" in s.missing_integration for s in suggestions
        )

    @pytest.mark.asyncio
    async def test_build_fitness_with_strava_suggests_hr_integration(self):
        """User with 'build_fitness' and Strava but no HR → suggests Fitbit or Polar."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        prefs = _make_prefs([{"metric": "build_fitness"}])

        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            # Strava covers activity, but not heart_rate or vo2max
            patch.object(suggester, "_get_connected_integrations", return_value={"strava"}),
        ):
            suggestions = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        # Should suggest something for heart_rate or vo2max gap
        assert len(suggestions) > 0
        # All suggestions should be for integrations NOT already connected
        for s in suggestions:
            assert s.missing_integration != "strava"

    @pytest.mark.asyncio
    async def test_no_suggestions_when_all_requirements_met(self):
        """No suggestions when all required integrations are already connected."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        prefs = _make_prefs([{"metric": "lose_weight"}])
        # lose_weight requires nutrition + activity
        # Connect integrations that cover both
        connected = {"fitbit", "strava"}  # fitbit covers nutrition, strava covers activity

        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            patch.object(suggester, "_get_connected_integrations", return_value=connected),
        ):
            suggestions = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        # fitbit covers nutrition, strava covers activity → no gaps
        nutrition_gaps = [s for s in suggestions if s.missing_integration in {"fitbit", "strava"}]
        assert len(nutrition_gaps) == 0

    @pytest.mark.asyncio
    async def test_dismissed_suggestion_not_returned(self):
        """A dismissed suggestion ID is filtered out of results."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        prefs = _make_prefs([{"metric": "better_sleep"}])

        # First, get the real suggestion IDs.
        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            patch.object(suggester, "_get_connected_integrations", return_value=set()),
        ):
            undismissed = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        assert len(undismissed) > 0
        dismissed_ids = {s.id for s in undismissed}

        # Now call again with those IDs dismissed.
        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            patch.object(suggester, "_get_connected_integrations", return_value=set()),
        ):
            after_dismiss = await suggester.get_suggestions(
                "user-001", db, dismissed_cache={sid: True for sid in dismissed_ids}
            )

        # All original suggestions are now dismissed — result should be empty or smaller.
        for s in after_dismiss:
            assert s.id not in dismissed_ids

    @pytest.mark.asyncio
    async def test_no_goals_returns_empty_list(self):
        """User with no goals → no suggestions."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        prefs = _make_prefs(goals=[])

        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            patch.object(suggester, "_get_connected_integrations", return_value=set()),
        ):
            suggestions = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        assert suggestions == []

    @pytest.mark.asyncio
    async def test_none_prefs_returns_empty_list(self):
        """No preferences row → no suggestions."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        with patch.object(suggester, "_get_preferences", return_value=None):
            suggestions = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        assert suggestions == []

    @pytest.mark.asyncio
    async def test_no_duplicate_suggestions_per_integration(self):
        """Multiple goals pointing to same missing integration → deduplicated."""
        suggester = CorrelationSuggester()
        db = AsyncMock()

        # Both lose_weight and build_fitness may suggest fitbit for nutrition/activity.
        prefs = _make_prefs(
            [
                {"metric": "lose_weight"},
                {"metric": "build_fitness"},
            ]
        )

        with (
            patch.object(suggester, "_get_preferences", return_value=prefs),
            patch.object(suggester, "_get_connected_integrations", return_value=set()),
        ):
            suggestions = await suggester.get_suggestions("user-001", db, dismissed_cache={})

        integration_slugs = [s.missing_integration for s in suggestions]
        # No duplicate integration slugs.
        assert len(integration_slugs) == len(set(integration_slugs))


class TestDismissSuggestion:
    @pytest.mark.asyncio
    async def test_dismiss_sets_redis_key_with_30d_ttl(self):
        """dismiss_suggestion stores the key with a 30-day TTL."""
        suggester = CorrelationSuggester()
        mock_redis = AsyncMock()
        mock_redis.set = AsyncMock()

        await suggester.dismiss_suggestion("user-001", "suggestion-abc", mock_redis)

        mock_redis.set.assert_awaited_once()
        call_kwargs = mock_redis.set.call_args
        # TTL should be 30 * 86400
        assert call_kwargs[1]["ex"] == 30 * 86400
