# Phase 1.11.4: Goal Tracking

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [x] 1.11.2 Correlation Analysis
- [x] 1.11.3 Trend Detection
- [x] 1.11.4 Goal Tracking
- [ ] 1.11.5 Insight Generation
- [ ] 1.11.6 Edge Agent Analytics Repository
- [ ] 1.11.7 Harness: Analytics Test

---

## What
Implement logic to compare current normalized totals against user-defined targets (e.g., "10,000 steps/day", "Lose 0.5kg/week").

## Why
Goals provide context. "8,000 steps" is good if the goal is 5,000, but bad if the goal is 15,000. The AI needs this context to give "Tough Love".

## How
Create `GoalTracker` service that fetches `UserProfile` goals and compares with `Analytics` data.

## Features
- **Daily vs Weekly:** Some goals are daily (steps), some weekly (workouts), some long-term (weight).
- **Streak Calculation:** "You've hit your step goal 5 days in a row!"

## Files
- Create: `cloud-brain/app/analytics/goal_tracker.py`

## Steps

1. **Create goal tracker (`cloud-brain/app/analytics/goal_tracker.py`)**

```python
class GoalTracker:
    def __init__(self, db_session):
        self.db = db_session
    
    async def check_progress(self, user_id: str) -> list[dict]:
        """
        Compare current day's stats against user goals.
        """
        # 1. Fetch User Goals (from UserProfile)
        # user = await self.db.get(User, user_id)
        # step_goal = user.profile.goals.get("steps", 10000)
        step_goal = 10000 # Mock
        
        # 2. Fetch User Stats (from Analytics Service)
        current_steps = 8500 # Mock
        
        return [{
            "metric": "steps",
            "period": "daily",
            "target": step_goal,
            "current": current_steps,
            "progress_pct": (current_steps / step_goal) * 100,
            "is_met": current_steps >= step_goal,
            "remaining": max(0, step_goal - current_steps)
        }]
```

## Exit Criteria
- Tracker returns structured progress objects.
