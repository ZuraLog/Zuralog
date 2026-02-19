# Phase 1.11.2: Correlation Analysis

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [x] 1.11.2 Correlation Analysis
- [ ] 1.11.3 Trend Detection
- [ ] 1.11.4 Goal Tracking
- [ ] 1.11.5 Insight Generation
- [ ] 1.11.6 Edge Agent Analytics Repository
- [ ] 1.11.7 Harness: Analytics Test

---

## What
Implement statistical logic to find relationships between different health metrics (e.g., "Does higher sleep duration lead to higher active calories the next day?").

## Why
This is the "Brain" part. Users can see charts in Apple Health. We want to tell them *why* things change.

## How
Add methods to `ReasoningEngine` to calculate Pearson correlation coefficients (using `numpy` or `scipy`).

## Features
- **Lag detection:** Check correlation between Sleep (Day N) and Activity (Day N) vs Activity (Day N+1).
- **Context:** Requires at least 7-14 days of data to be meaningful.

## Files
- Modify: `cloud-brain/app/analytics/reasoning_engine.py` (Created in 1.8.4, expanding here)

## Steps

1. **Add correlation logic (`cloud-brain/app/analytics/reasoning_engine.py`)**

```python
import numpy as np

class ReasoningEngine:
    # ... existing methods ...

    def calculate_correlation(self, metric_x: list[float], metric_y: list[float]) -> dict:
        """
        Calculate Pearson correlation.
        Returns: {score: -1.0 to 1.0, significance: float}
        """
        if len(metric_x) != len(metric_y) or len(metric_x) < 5:
            return {"score": 0.0, "message": "Not enough data"}
            
        score = np.corrcoef(metric_x, metric_y)[0, 1]
        
        message = "No correlation"
        if score > 0.7: message = "Strong Positive Correlation"
        elif score < -0.7: message = "Strong Negative Correlation"
        
        return {"score": float(score), "message": message}

    def analyze_sleep_impact_on_activity(self, user_id: str):
        # Fetch data, align by date, call calculate_correlation
        pass
```

## Exit Criteria
- Logic compiles.
- Can correctly identify strong positive/negative correlations in test data.
