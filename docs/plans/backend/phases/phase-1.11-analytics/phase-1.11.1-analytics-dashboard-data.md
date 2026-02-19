# Phase 1.11.1: Analytics Dashboard Data

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [ ] 1.11.2 Correlation Analysis
- [ ] 1.11.3 Trend Detection
- [ ] 1.11.4 Goal Tracking
- [ ] 1.11.5 Insight Generation
- [ ] 1.11.6 Edge Agent Analytics Repository
- [ ] 1.11.7 Harness: Analytics Test

---

## What
Create API endpoints that provide pre-aggregated daily summaries and weekly trend data for the mobile dashboard.

## Why
The mobile app shouldn't have to download thousands of raw activity records to show a "Steps this week" chart. The backend should do the heavy lifting (aggregating normalized data).

## How
Use SQL queries (via SQLAlchemy) to sum/average data grouped by date.

## Features
- **Fast Response:** Pre-calculate or cache results if heavy. (MVP: On-demand SQL aggregation).
- **Date Ranging:** Support specific date ranges (e.g., "last 7 days", "this month").

## Files
- Create: `cloud-brain/app/api/v1/analytics.py`

## Steps

1. **Create analytics endpoints (`cloud-brain/app/api/v1/analytics.py`)**

```python
from fastapi import APIRouter, Depends
from datetime import date, timedelta
from cloudbrain.app.db.base import get_db

router = APIRouter()

@router.get("/analytics/daily-summary")
async def get_daily_summary(
    user_id: str, 
    date_str: str = None,
    db = Depends(get_db)
):
    """
    Get aggregated Health/Fitness summary for a specific day.
    """
    target_date = date.fromisoformat(date_str) if date_str else date.today()
    
    # query = select(func.sum(UnifiedActivity.steps)).where( ... )
    # MVP Mock:
    return {
        "date": target_date.isoformat(),
        "steps": 8500,
        "calories_consumed": 1850,
        "calories_burned": 2450, # BMR + Active
        "workouts_count": 1,
        "sleep_hours": 7.5,
    }

@router.get("/analytics/weekly-trends")
async def get_weekly_trends(user_id: str):
    """
    Get last 7 days of data for charts.
    """
    # Logic to fetch last 7 days
    return {
        "dates": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        "steps": [8500, 9200, 7800, 10500, 8900, 6500, 8100],
        "calories_in": [1800, 1950, 2100, 1850, 1750, 2200, 1900],
        "calories_out": [2200, 2300, 2100, 2400, 2250, 2000, 2200],
    }
```

## Exit Criteria
- Endpoints return structured JSON data suitable for UI charts.
