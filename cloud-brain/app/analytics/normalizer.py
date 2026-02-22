"""
Life Logger Cloud Brain — Cross-Source Data Normalizer.

Transforms incoming activity data from Strava, Apple HealthKit,
Google Health Connect, and other sources into a uniform internal
schema (UnifiedActivity). This allows the AI Brain and analytics
engine to reason across data sources without caring about origin.

The normalizer handles:
- Field name mapping (moving_time -> duration_seconds)
- Unit conversion (milliseconds -> seconds, etc.)
- Activity type classification (source-specific -> ActivityType enum)
"""

import logging
from enum import Enum
from typing import Any

logger = logging.getLogger(__name__)


class ActivityType(str, Enum):
    """Canonical activity types used across the entire system.

    Maps source-specific activity names to a unified set.
    """

    RUN = "run"
    CYCLE = "cycle"
    WALK = "walk"
    SWIM = "swim"
    STRENGTH = "strength"
    UNKNOWN = "unknown"


# Health Connect exercise type constants (from Android SDK).
_HC_EXERCISE_TYPE_RUNNING = 56
_HC_EXERCISE_TYPE_BIKING = 8
_HC_EXERCISE_TYPE_WALKING = 79
_HC_EXERCISE_TYPE_SWIMMING_POOL = 74
_HC_EXERCISE_TYPE_SWIMMING_OPEN_WATER = 73


class DataNormalizer:
    """Normalizes activity data from any source into a unified format.

    All methods are stateless and operate on provided data dictionaries.
    No database or API calls are made.
    """

    def normalize_activity(self, source: str, data: dict[str, Any]) -> dict[str, Any]:
        """Normalize a single activity record to the unified schema.

        Args:
            source: Data source identifier ('strava', 'apple_health',
                'health_connect', etc.).
            data: Raw activity data dictionary from the source.

        Returns:
            A dictionary matching the UnifiedActivity schema with keys:
            source, original_id, type, duration_seconds, distance_meters,
            calories, start_time.
        """
        normalized: dict[str, Any] = {
            "source": source,
            "original_id": str(data.get("id", "")),
            "type": ActivityType.UNKNOWN,
            "duration_seconds": 0,
            "distance_meters": 0.0,
            "calories": 0.0,
            "start_time": None,
        }

        if source == "strava":
            self._normalize_strava(data, normalized)
        elif source == "apple_health":
            self._normalize_apple_health(data, normalized)
        elif source == "health_connect":
            self._normalize_health_connect(data, normalized)
        else:
            logger.warning("Unknown source '%s' — using raw defaults", source)

        return normalized

    def _normalize_strava(self, data: dict[str, Any], out: dict[str, Any]) -> None:
        """Apply Strava-specific field mappings.

        Args:
            data: Raw Strava activity dict.
            out: Mutable normalized dict to populate.
        """
        out["type"] = self._map_strava_type(data.get("type"))
        out["duration_seconds"] = data.get("moving_time", 0)
        out["distance_meters"] = data.get("distance", 0.0)
        out["calories"] = data.get("calories", 0.0)
        out["start_time"] = data.get("start_date")

    def _normalize_apple_health(self, data: dict[str, Any], out: dict[str, Any]) -> None:
        """Apply Apple HealthKit-specific field mappings.

        Args:
            data: Raw Apple Health activity dict.
            out: Mutable normalized dict to populate.
        """
        out["type"] = self._map_apple_type(data.get("workoutActivityType"))
        out["duration_seconds"] = data.get("duration", 0)
        out["distance_meters"] = data.get("totalDistance", 0.0)
        out["calories"] = data.get("totalEnergyBurned", 0.0)
        out["start_time"] = data.get("startDate")

    def _normalize_health_connect(self, data: dict[str, Any], out: dict[str, Any]) -> None:
        """Apply Google Health Connect-specific field mappings.

        Health Connect durations come in milliseconds; we convert to seconds.

        Args:
            data: Raw Health Connect exercise dict.
            out: Mutable normalized dict to populate.
        """
        out["type"] = self._map_health_connect_type(data.get("exerciseType"))
        duration_ms = data.get("duration_ms", 0)
        out["duration_seconds"] = duration_ms // 1000 if duration_ms else 0
        out["distance_meters"] = data.get("distance_meters", 0.0)
        out["calories"] = data.get("energy_calories", 0.0)
        out["start_time"] = data.get("startTime")

    @staticmethod
    def _map_strava_type(strava_type: str | None) -> ActivityType:
        """Map a Strava activity type string to our canonical enum.

        Args:
            strava_type: Strava's activity type (e.g., 'Run', 'Ride').

        Returns:
            The corresponding ActivityType, or UNKNOWN if unrecognized.
        """
        mapping = {
            "Run": ActivityType.RUN,
            "Ride": ActivityType.CYCLE,
            "Walk": ActivityType.WALK,
            "Swim": ActivityType.SWIM,
            "WeightTraining": ActivityType.STRENGTH,
        }
        return mapping.get(strava_type or "", ActivityType.UNKNOWN)

    @staticmethod
    def _map_apple_type(apple_type: str | None) -> ActivityType:
        """Map an Apple HealthKit workout type to our canonical enum.

        Args:
            apple_type: HKWorkoutActivityType string identifier.

        Returns:
            The corresponding ActivityType, or UNKNOWN if unrecognized.
        """
        mapping = {
            "HKWorkoutActivityTypeRunning": ActivityType.RUN,
            "HKWorkoutActivityTypeCycling": ActivityType.CYCLE,
            "HKWorkoutActivityTypeWalking": ActivityType.WALK,
            "HKWorkoutActivityTypeSwimming": ActivityType.SWIM,
        }
        return mapping.get(apple_type or "", ActivityType.UNKNOWN)

    @staticmethod
    def _map_health_connect_type(exercise_type: int | None) -> ActivityType:
        """Map a Health Connect exercise type integer to our canonical enum.

        Args:
            exercise_type: Android Health Connect EXERCISE_TYPE_* constant.

        Returns:
            The corresponding ActivityType, or UNKNOWN if unrecognized.
        """
        mapping = {
            _HC_EXERCISE_TYPE_RUNNING: ActivityType.RUN,
            _HC_EXERCISE_TYPE_BIKING: ActivityType.CYCLE,
            _HC_EXERCISE_TYPE_WALKING: ActivityType.WALK,
            _HC_EXERCISE_TYPE_SWIMMING_POOL: ActivityType.SWIM,
            _HC_EXERCISE_TYPE_SWIMMING_OPEN_WATER: ActivityType.SWIM,
        }
        return mapping.get(exercise_type or -1, ActivityType.UNKNOWN)
