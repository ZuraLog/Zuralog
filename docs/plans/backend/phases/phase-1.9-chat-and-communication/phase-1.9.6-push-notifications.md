# Phase 1.9.6: Push Notifications (FCM)

**Parent Goal:** Phase 1.9 Chat & Communication Layer
**Checklist:**
- [x] 1.9.1 WebSocket Endpoint
- [x] 1.9.2 Edge Agent WebSocket Client
- [x] 1.9.3 Message Persistence
- [x] 1.9.4 Edge Agent Chat Repository
- [x] 1.9.5 Chat UI in Harness
- [ ] 1.9.6 Push Notifications (FCM)
- [ ] 1.9.7 Edge Agent FCM Setup

---

## What
Implement backend service to send Push Notifications via Firebase Cloud Messaging (FCM).

## Why
To re-engage users ("You haven't logged lunch yet") or notify them of async AI insights ("I noticed you walked more today!").

## How
Use `firebase-admin` python SDK. This requires a Service Account JSON file.

## Features
- **Targeting:** Send to specific `device_token`.
- **Data Payload:** Include deep links (`zuralog://chat`).

## Files
- Create: `cloud-brain/app/services/push_service.py`

## Steps

1. **Create push service (`cloud-brain/app/services/push_service.py`)**

```python
import firebase_admin
from firebase_admin import messaging, credentials
from cloudbrain.app.config import settings
# import os

# Initialize app (usually in main startup)
# cred = credentials.Certificate("path/to/serviceAccountKey.json")
# firebase_admin.initialize_app(cred)

class PushService:
    def send_notification(self, token: str, title: str, body: str, data: dict = None):
        """Send FCM notification."""
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=token,
            )
            response = messaging.send(message)
            return response
        except Exception as e:
            print(f"FCM Error: {e}")
            return None
```

## Exit Criteria
- Service can send a test notification (mocked or real if creds provided).
