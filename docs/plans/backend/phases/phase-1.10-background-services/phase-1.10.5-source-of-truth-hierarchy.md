# Phase 1.10.5: Source-of-Truth Hierarchy

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [x] 1.10.2 Background Sync Scheduler
- [x] 1.10.3 Edge Agent Background Handler
- [x] 1.10.4 Data Normalization
- [x] 1.10.5 Source-of-Truth Hierarchy
- [ ] 1.10.6 Sync Status Tracking
- [ ] 1.10.7 Harness: Background Sync Test

---

## What
Implement logic to detect and resolve conflicting data points (e.g., a Run recorded by *both* Apple Watch and Strava).

## Why
Double counting calories is bad. "You burned 1000 calories!" (True: 500).

## How
Time-based overlap detection + Priority assignments.
Hierarchy: Device Hardware (Apple Watch, Oura) > Aggregators (Health Connect) > User Input > Third Party Apps (Strava).
*Wait, actually Strava might clear up "What" the activity was better, but Apple Watch has better HR data.*
Let's stick to a simple priority for MVP.

## Features
- **Overlap Detection:** If start/end times overlap by > 50%, consider it the same event.
- **Priority Merge:** Take "Type" from Strava but "Calories" from Apple Watch (Advanced) or just pick one record (MVP).

## Files
- Create: `cloud-brain/app/analytics/deduplication.py`

## Steps

1. **Create deduplication logic (`cloud-brain/app/analytics/deduplication.py`)**

```python
class SourceOfTruth:
    """Determine which source takes precedence for overlapping data."""
    
    # Higher number = higher priority
    PRIORITY = {
        "apple_health": 10,  # Sensor data usually best
        "health_connect": 10,
        "strava": 8,         # Good for maps/social, but data comes from device anyway
        "manual": 5,
    }
    
    @staticmethod
    def resolve_conflicts(activities: list[dict]) -> list[dict]:
        """
        Input: Raw list of normalized activities.
        Output: Deduplicated list.
        """
        # 1. Sort by start time
        sorted_acts = sorted(activities, key=lambda x: x['start_time'])
        
        merged = []
        if not sorted_acts:
            return []
            
        current = sorted_acts[0]
        
        for next_act in sorted_acts[1:]:
            if SourceOfTruth._is_overlap(current, next_act):
                # Conflict! Pick winner.
                current = SourceOfTruth._pick_winner(current, next_act)
            else:
                merged.append(current)
                current = next_act
        
        merged.append(current)
        return merged

    @staticmethod
    def _is_overlap(a, b) -> bool:
        # Simplified overlap check
        # Real logic needs proper datetime parsing
        return False 

    @staticmethod
    def _pick_winner(a, b):
        p_a = SourceOfTruth.PRIORITY.get(a['source'], 0)
        p_b = SourceOfTruth.PRIORITY.get(b['source'], 0)
        return a if p_a >= p_b else b
```

## Exit Criteria
- Deduplication logic correctly prioritizes sources.
- Unit tests cover overlap scenarios.
