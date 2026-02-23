"""
Zuralog Cloud Brain — Source-of-Truth & Deduplication Engine.

Detects and resolves conflicting activity records from multiple
data sources (e.g., a run recorded by both Apple Watch and Strava).

Uses time-based overlap detection (>50% of shorter activity) and
a source priority hierarchy to determine which record to keep.

Priority hierarchy (higher = more trusted):
- Hardware sensors (Apple Health, Health Connect): 10
- Third-party apps (Strava): 8
- User manual input: 5
"""

import logging
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)


class SourceOfTruth:
    """Resolves conflicts between overlapping activity records.

    Uses a combination of time-overlap detection and source-priority
    to deduplicate activities that represent the same real-world event.

    Attributes:
        PRIORITY: Source priority map (higher number = more trusted).
        OVERLAP_THRESHOLD: Minimum overlap ratio to consider two
            activities as duplicates (0.5 = 50%).
    """

    PRIORITY: dict[str, int] = {
        "apple_health": 10,
        "health_connect": 10,
        "strava": 8,
        "manual": 5,
    }

    OVERLAP_THRESHOLD: float = 0.5

    def resolve_conflicts(self, activities: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Deduplicate a list of normalized activities.

        Sorts by start time, then sweeps through comparing adjacent
        activities for time overlap. When overlap exceeds the threshold,
        the lower-priority record is discarded.

        Args:
            activities: List of normalized activity dicts. Each must
                have 'source', 'start_time' (ISO 8601 or None), and
                'duration_seconds' keys.

        Returns:
            A deduplicated list of activities, preserving chronological order.
        """
        if not activities:
            return []

        timed = [a for a in activities if a.get("start_time") is not None]
        untimed = [a for a in activities if a.get("start_time") is None]

        sorted_acts = sorted(timed, key=lambda x: x["start_time"])

        merged: list[dict[str, Any]] = []
        if not sorted_acts:
            return untimed

        current = sorted_acts[0]

        for next_act in sorted_acts[1:]:
            if self._is_overlap(current, next_act):
                current = self._pick_winner(current, next_act)
            else:
                merged.append(current)
                current = next_act

        merged.append(current)
        merged.extend(untimed)
        return merged

    def _is_overlap(self, a: dict[str, Any], b: dict[str, Any]) -> bool:
        """Determine if two activities overlap by more than the threshold.

        Computes the intersection of the two time intervals and compares
        it against the shorter activity's duration. If the overlap ratio
        exceeds ``OVERLAP_THRESHOLD``, the activities are considered
        duplicates of the same real-world event.

        Args:
            a: First activity (must have 'start_time' and 'duration_seconds').
            b: Second activity (must have 'start_time' and 'duration_seconds').

        Returns:
            True if the overlap ratio exceeds OVERLAP_THRESHOLD.
        """
        try:
            start_a = self._parse_time(a["start_time"])
            start_b = self._parse_time(b["start_time"])
        except (ValueError, TypeError):
            return False

        dur_a = a.get("duration_seconds", 0)
        dur_b = b.get("duration_seconds", 0)

        if dur_a <= 0 or dur_b <= 0:
            return False

        end_a = start_a.timestamp() + dur_a
        end_b = start_b.timestamp() + dur_b

        overlap_start = max(start_a.timestamp(), start_b.timestamp())
        overlap_end = min(end_a, end_b)
        overlap_seconds = max(0, overlap_end - overlap_start)

        if overlap_seconds == 0:
            return False

        shorter_duration = min(dur_a, dur_b)
        overlap_ratio = overlap_seconds / shorter_duration

        return overlap_ratio > self.OVERLAP_THRESHOLD

    def _pick_winner(self, a: dict[str, Any], b: dict[str, Any]) -> dict[str, Any]:
        """Choose the higher-priority activity in a conflict.

        Compares the source priority of both activities. On a tie the
        first activity (earlier in the original sorted order) wins,
        preserving stable insertion order.

        Args:
            a: First conflicting activity.
            b: Second conflicting activity.

        Returns:
            The activity with higher source priority. On tie, returns
            the first activity (preserving insertion order).
        """
        priority_a = self.PRIORITY.get(a.get("source", ""), 0)
        priority_b = self.PRIORITY.get(b.get("source", ""), 0)

        winner = a if priority_a >= priority_b else b
        loser = b if winner is a else a
        logger.info(
            "Conflict resolved: kept '%s' (priority %d), discarded '%s' (priority %d)",
            winner.get("source"),
            max(priority_a, priority_b),
            loser.get("source"),
            min(priority_a, priority_b),
        )
        return winner

    @staticmethod
    def _parse_time(time_str: str) -> datetime:
        """Parse an ISO 8601 timestamp string to a timezone-aware datetime.

        Handles the ``Z`` suffix by replacing it with ``+00:00`` for
        compatibility with ``datetime.fromisoformat``. If the parsed
        datetime is naive (no timezone info), UTC is assumed.

        Args:
            time_str: ISO 8601 formatted timestamp string.

        Returns:
            A timezone-aware datetime object (UTC if no tz specified).

        Raises:
            ValueError: If the string cannot be parsed.
        """
        dt = datetime.fromisoformat(time_str.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
