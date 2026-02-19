# Phase 1.11.5: Insight Generation

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [x] 1.11.2 Correlation Analysis
- [x] 1.11.3 Trend Detection
- [x] 1.11.4 Goal Tracking
- [x] 1.11.5 Insight Generation
- [ ] 1.11.6 Edge Agent Analytics Repository
- [ ] 1.11.7 Harness: Analytics Test

---

## What
Synthesize all the analytics (Trends, Correlations, Goals) into a single, highly relevant "Insight of the Day" text for the Dashboard.

## Why
Users don't want to read raw charts. They want the "So what?". Even without chatting with the AI, the dashboard should show a "Smart" insight.

## How
Rule-Based Heuristics (initially) -> LLM Synthesis (later). We'll start with Python logic to pick the "most urgent" fact.

## Features
- **Prioritization:** Urgent Health Warnings > Goal Completion > Positive Trends > Correlations.
- **Tone Matching:** Uses User Persona (Tough vs Gentle).

## Files
- Modify: `cloud-brain/app/analytics/reasoning_engine.py`

## Steps

1. **Add insight generation (`cloud-brain/app/analytics/reasoning_engine.py`)**

```python
    def generate_dashboard_insight(self, user_id: str, goal_status: list[dict], trends: dict) -> str:
        """
        Generate a single-sentence insight for the dashboard header.
        """
        # 1. Check for Goal Near-Misses (Urgent)
        for goal in goal_status:
            if not goal["is_met"] and goal["progress_pct"] > 80:
                remaining = goal["remaining"]
                return f"So close! Just {remaining} more steps to hit your goal. Go for a walk?"
        
        # 2. Check for Negative Trends
        if trends.get("steps") == "down":
            return "Your activity is trending down this week. Let's pick it up."
            
        # 3. Check for Positive Trends
        if trends.get("steps") == "up":
            return "You're crushing it! Activity is up 15% this week."
            
        return "Consistency is key. Keep logging your meals."
```

## Exit Criteria
- Logic returns a string string based on input data.
