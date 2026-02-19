# Phase 1.10.2: Background Sync Scheduler

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [x] 1.10.2 Background Sync Scheduler
- [ ] 1.10.3 Edge Agent Background Handler
- [ ] 1.10.4 Data Normalization
- [ ] 1.10.5 Source-of-Truth Hierarchy
- [ ] 1.10.6 Sync Status Tracking
- [ ] 1.10.7 Harness: Background Sync Test

---

## What
Implement a server-side scheduler (using Celery/Beat) to periodically pull data from cloud integrations (Strava, Fitbit, Oura).

## Why
We shouldn't wait for the user to open the app to get their latest Strava run. The AI should "know" about it automatically.

## How
Celery Beat kicks off a `sync_user_data` task every 15 minutes.

## Features
- **Rate Limit Aware:** Respects Strava API limits (100 req/15min).
- **Concurrency Control:** Ensures we don't start a sync if one is already running for that user.

## Files
- Create: `cloud-brain/app/services/sync_scheduler.py`
- Modify: `cloud-brain/app/worker.py` (Celery app)

## Steps

1. **Create sync scheduler (`cloud-brain/app/services/sync_scheduler.py`)**

```python
from celery import Celery
from cloudbrain.app.config import settings

celery_app = Celery("life_logger", broker=settings.redis_url)

@celery_app.task
def sync_user_data(user_id: str):
    """
    Periodic task to sync user data from cloud sources (Strava).
    does NOT sync Apple Health (that's push from device).
    """
    print(f"Syncing data for {user_id}...")
    # 1. Get user integrations
    # 2. If Strava connected:
    #    latest_activities = strava_service.get_recent_activities(user_id)
    #    db.save(latest_activities)
    pass

@celery_app.task
def refresh_integration_tokens():
    """Check for expiring OAuth tokens and refresh them."""
    pass

# Schedule: sync every 15 minutes
celery_app.conf.beat_schedule = {
    'sync-active-users-15m': {
        'task': 'sync_user_data',
        'schedule': 900.0,
        'args': ('user_123',), # In reality, we'd iterate active users or trigger via a master task
    },
}
```

## Exit Criteria
- Celery configured and tasks defined.
- Worker can be started adjacent to fastapi app.
