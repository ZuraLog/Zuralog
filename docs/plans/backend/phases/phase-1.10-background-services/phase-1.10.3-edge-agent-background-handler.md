# Phase 1.10.3: Edge Agent Background Handler

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [x] 1.10.2 Background Sync Scheduler
- [x] 1.10.3 Edge Agent Background Handler
- [ ] 1.10.4 Data Normalization
- [ ] 1.10.5 Source-of-Truth Hierarchy
- [ ] 1.10.6 Sync Status Tracking
- [ ] 1.10.7 Harness: Background Sync Test

---

## What
Implement the client-side Dart logic to receive the "Write" FCM message and execute the HealthKit/HealthConnect write operation *while the app is in the background*.

## Why
Seamless experience. If the AI says "I logged it," it should be logged, without the user needing to open the app to "finish" the process.

## How
Flutter's `FirebaseMessaging.onBackgroundMessage` handler. This runs in a separate isolate (headless).

## Features
- **Headless Execution:** Must initialize necessary plugins (Health) without a UI context.
- **Silent Failure:** If permission is missing, log locally; don't crash or show UI.

## Files
- Modify: `zuralog/lib/core/network/fcm_service.dart`
- Modify: `zuralog/lib/main.dart` (to register bg handler)

## Steps

1. **Handle background messages (`zuralog/lib/core/network/fcm_service.dart`)**

```dart
// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize plugins if needed
  // await Firebase.initializeApp();
  
  print("Handling a background message: ${message.messageId}");
  
  if (message.data['action'] == 'write_health') {
      try {
          final dataType = message.data['data_type'];
          // final value = jsonDecode(message.data['value']);
          
          // Use HealthRepository (or direct platform channel) to write
          // Note: Full Riverpod dependency injection might not be available here.
          // Direct MethodChannel call is safer for background isolates.
          
          // await HealthChannel.write(dataType, value);
      } catch (e) {
          print("Background write failed: $e");
      }
  }
}
```

2. **Register handler (`zuralog/lib/main.dart`)**

```dart
void main() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(MyApp());
}
```

## Exit Criteria
- Background handler registered.
- Can receive data payload in console when app is minimized.
