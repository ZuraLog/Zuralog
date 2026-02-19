# Phase 1.11.3: Trend Detection

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [x] 1.11.2 Correlation Analysis
- [x] 1.11.3 Trend Detection
- [ ] 1.11.4 Goal Tracking
- [ ] 1.11.5 Insight Generation
- [ ] 1.11.6 Edge Agent Analytics Repository
- [ ] 1.11.7 Harness: Analytics Test

---

## What
Identify if specific metrics are trending Up, Down, or Stable over defined time windows (7-day, 30-day).

## Why
"You've been walking less this week compared to last week" is a powerful, actionable insight.

## How
Compare Moving Averages (e.g., Average(Last 7 days) vs Average(Previous 7 days)).

## Features
- **Sensitivity:** Ignore micro-fluctuations (e.g., < 5% change).
- **Directionality context:** "Steps going Down" is Bad. "Weight going Down" is (usually) Good (depending on goal).

## Files
- Modify: `cloud-brain/app/analytics/reasoning_engine.py`

## Steps

1. **Add trend detection (`cloud-brain/app/analytics/reasoning_engine.py`)**

```python
    def detect_trend(self, values: list[float], window_size: int = 7) -> dict:
        """
        Compare most recent window avg against previous window avg.
        """
        if len(values) < window_size * 2:
            return {"trend": "insufficient_data"}
            
        recent = values[-window_size:]
        previous = values[-window_size*2 : -window_size]
        
        avg_recent = sum(recent) / len(recent)
        avg_prev = sum(previous) / len(previous)
        
        if avg_prev == 0:
            return {"percent_change": 100.0, "trend": "up"}
            
        pct_change = ((avg_recent - avg_prev) / avg_prev) * 100
        
        trend = "stable"
        if pct_change > 10: trend = "up"
        elif pct_change < -10: trend = "down"
        
        return {
            "percent_change": round(pct_change, 1),
            "trend": trend,
            "recent_avg": avg_recent
        }
```

## Exit Criteria
- Trend logic compiles.
- Returns correct up/down/stable classification.
