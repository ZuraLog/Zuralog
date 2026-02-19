# Phase 1.8.4: Cross-App Reasoning Engine

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [ ] 1.8.4 Cross-App Reasoning Engine
- [ ] 1.8.5 Voice Input
- [ ] 1.8.6 User Profile & Preferences
- [ ] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Implement specific analytical logic that compares data from *different* MCP servers (e.g., Apple Health vs. Strava vs. CalAI) to synthesize higher-level insights.

## Why
Standard tool calling lets the AI get data separately. But structured reasoning ("User exercised hard but ate little, risking injury") needs either very good prompting or dedicated analytical helpers. This engine provides pre-calculated insights to the AI.

## How
Create a `ReasoningEngine` service that the Orchestrator can call *proactively* or as a tool. It pulls data from multiple sources and returns a synthesized summary.

## Features
- **Correlation:** "Your sleep quality drops 15% on days you run late."
- **Goal Tracking:** "You are tracking 500 kcal behind your weekly goal."

## Files
- Create: `cloud-brain/app/analytics/reasoning_engine.py`

## Steps

1. **Create reasoning engine logic (`cloud-brain/app/analytics/reasoning_engine.py`)**

```python
import statistics

class ReasoningEngine:
    """Analyzes cross-app data to generate higher-order insights."""
    
    def analyze_deficit(
        self,
        nutrition_calories: int,
        active_burn: int,
        bmr: int = 1800
    ) -> dict:
        """Calculate caloric deficit/surplus."""
        total_out = bmr + active_burn
        net = nutrition_calories - total_out
        
        status = "deficit" if net < 0 else "surplus"
        size = abs(net)
        
        return {
            "net_calories": net,
            "status": status,
            "magnitude": size,
            "recommendation": "Eat more." if net < -500 else "Good job."
        }

    def correlate_sleep_and_activity(
        self,
        sleep_data: list[dict],
        activity_data: list[dict]
    ) -> str:
        """
        Simple heuristic: Do I sleep more after heavy activity?
        Mocks a statistical correlation.
        """
        # Logic to align dates and compare series
        return "No significant correlation found yet. Keep tracking!"
```

## Exit Criteria
- Reasoning engine compiles.
- Unit tests verify the calculation logic.
