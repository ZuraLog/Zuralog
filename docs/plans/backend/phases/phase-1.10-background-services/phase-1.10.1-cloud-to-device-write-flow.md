# Phase 1.10.1: Cloud-to-Device Write Flow

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [ ] 1.10.2 Background Sync Scheduler
- [ ] 1.10.3 Edge Agent Background Handler
- [ ] 1.10.4 Data Normalization
- [ ] 1.10.5 Source-of-Truth Hierarchy
- [ ] 1.10.6 Sync Status Tracking
- [ ] 1.10.7 Harness: Background Sync Test

---

## What
Implement a mechanism for the Cloud Brain (AI Agent) to initiate a "Write" operation to Apple Health or Health Connect on the user's device, pushing the data down via FCM.

## Why
When the AI says "I'm logging that meal for you," it runs on the server. But the Health Store lives on the phone. We need a bridge to push that action to the device.

## How
The Orchestrator identifies the user's active device (Android/iOS) and sends a specifically formatted FCM Data Message.

## Features
- **Silent Push:** Wake up app in background to process write without UI interruption (where OS allows).
- **Retry Logic:** If device is offline, FCM handles delivery when back online.

## Files
- Modify: `cloud-brain/app/agent/orchestrator.py`
- Modify: `cloud-brain/app/services/push_service.py`

## Steps

1. **Implement write flow in Orchestrator (`cloud-brain/app/agent/orchestrator.py`)**

```python
# In Orchestrator class
async def handle_write_request(self, user_id: str, data_type: str, value: dict) -> dict:
    """
    Called when LLM tools like 'apple_health_write_nutrition' are invoked.
    """
    
    # 1. Fetch user's primary device token from DB
    # user_device = await db.get_user_device(user_id)
    token = "MOCK_TOKEN" 
    
    # 2. Construct Payload
    payload = {
        "action": "write_health",
        "data_type": data_type,
        "value": json.dumps(value), # FCM data values must be strings
        "timestamp": datetime.utcnow().isoformat()
    }
    
    # 3. Send via FCM
    # success = await push_service.send_data_message(token, payload)
    
    if success:
         return {"success": True, "message": "Write request sent to device. It may take a moment to appear."}
    else:
         return {"success": False, "error": "Could not reach device."}
```

## Exit Criteria
- Orchestrator can construct and send write payloads.
