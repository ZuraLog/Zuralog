# Phase 1.9.7: Edge Agent FCM Setup

**Parent Goal:** Phase 1.9 Chat & Communication Layer
**Checklist:**
- [x] 1.9.1 WebSocket Endpoint
- [x] 1.9.2 Edge Agent WebSocket Client
- [x] 1.9.3 Message Persistence
- [x] 1.9.4 Edge Agent Chat Repository
- [x] 1.9.5 Chat UI in Harness
- [x] 1.9.6 Push Notifications (FCM)
- [ ] 1.9.7 Edge Agent FCM Setup

---

## What
Configure the Flutter app to receive FCM messages.

## Why
To handle incoming notifications, show system tray alerts, and update the app state.

## How
Use `firebase_messaging` package. Requires `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

## Features
- **Background Handling:** Wake up app to process data messages.
- **Foreground Handling:** Show in-app banner or toast.

## Files
- Modify: `life_logger/pubspec.yaml`
- Create: `life_logger/lib/core/network/fcm_service.dart`

## Steps

1. **Configure FCM Service (`life_logger/lib/core/network/fcm_service.dart`)**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  Future<void> initialize() async {
    // Request permission (iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get token
      String? token = await _messaging.getToken();
      print("FCM Token: $token");
      // Send token to backend API to register device
    }
  }
  
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
      print("Handling a background message: ${message.messageId}");
  }
}
```

## Exit Criteria
- App prompts for notification permission on iOS.
- Prints FCM token to console.
