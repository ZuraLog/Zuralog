# Phase 1.10.4: Data Normalization

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [x] 1.10.2 Background Sync Scheduler
- [x] 1.10.3 Edge Agent Background Handler
- [x] 1.10.4 Data Normalization
- [ ] 1.10.5 Source-of-Truth Hierarchy
- [ ] 1.10.6 Sync Status Tracking
- [ ] 1.10.7 Harness: Background Sync Test

---

## What
Create a service that transforms incoming data from Strava, HealthKit, Health Connect, etc., into a uniform internal schema (e.g., `UnifiedActivity`, `UnifiedSleep`).

## Why
Strava calls it `moving_time`, Apple calls it `duration`. The AI Brain shouldn't care. It should just query `UnifiedActivity.duration_seconds`.

## How
Implement `DataNormalizer` class with static methods for each data type.

## Features
- **Unit Conversion:** Distances to meters, weight to kg, energy to kcal.
- **Type Mapping:** "Run" (Strava) -> `ActivityType.RUN`.

## Files
- Create: `cloud-brain/app/analytics/normalizer.py`

## Steps

1. **Create normalizer (`cloud-brain/app/analytics/normalizer.py`)**

```python
from enum import Enum
from typing import Dict, Any

class ActivityType(str, Enum):
    RUN = "run"
    CYCLE = "cycle"
    WALK = "walk"
    UNKNOWN = "unknown"

class DataNormalizer:
    """Normalize data from different sources to common format."""
    
    @staticmethod
    def normalize_activity(source: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize activity data to common format."""
        
        normalized = {
            "source": source,
            "original_id": str(data.get("id")),
            "type": ActivityType.UNKNOWN,
            "duration_seconds": 0,
            "distance_meters": 0.0,
            "calories": 0.0,
            "start_time": None
        }
        
        if source == "strava":
             normalized["type"] = DataNormalizer._map_strava_type(data.get("type"))
             normalized["duration_seconds"] = data.get("moving_time", 0)
             normalized["distance_meters"] = data.get("distance", 0.0)
             normalized["calories"] = data.get("calories", 0) # Often missing in list view
             normalized["start_time"] = data.get("start_date")
        
        elif source == "apple_health":
             normalized["type"] = DataNormalizer._map_apple_type(data.get("workoutActivityType"))
             normalized["duration_seconds"] = data.get("duration", 0)
             normalized["distance_meters"] = data.get("totalDistance", 0.0)
             normalized["calories"] = data.get("totalEnergyBurned", 0.0)
             normalized["start_time"] = data.get("startDate")
             
        return normalized

    @staticmethod
    def _map_strava_type(strava_type: str) -> ActivityType:
        mapping = {"Run": ActivityType.RUN, "Ride": ActivityType.CYCLE, "Walk": ActivityType.WALK}
        return mapping.get(strava_type, ActivityType.UNKNOWN)

    @staticmethod
    def _map_apple_type(apple_type: str) -> ActivityType:
        # Apple Health types are HKWorkoutActivityTypeRun, etc.
        mapping = {"HKWorkoutActivityTypeRunning": ActivityType.RUN, "HKWorkoutActivityTypeCycling": ActivityType.CYCLE}
        return mapping.get(apple_type, ActivityType.UNKNOWN)
```

## Exit Criteria
- Normalizer handles Strava and Apple Health formats.
- Returns dictionary matching the `UnifiedActivity` model structure (from Phase 1.5.6).
