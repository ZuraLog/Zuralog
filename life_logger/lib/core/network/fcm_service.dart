/// Life Logger Edge Agent — Firebase Cloud Messaging Service.
///
/// Handles FCM initialization, permission requests, token retrieval,
/// and background/foreground message handling. Scaffolded for Phase 1.9.7 —
/// requires Firebase project configuration files (GoogleService-Info.plist
/// for iOS, google-services.json for Android) to function.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:life_logger/core/network/api_client.dart';

/// Handles top-level background messages from FCM.
///
/// This must be a top-level function (not a class method) because
/// Flutter runs it in a separate isolate. It processes 'write_health'
/// actions by delegating to the platform-specific health bridge.
///
/// [message] is the incoming FCM remote message containing the
/// action type and data payload from the Cloud Brain.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final action = message.data['action'];

  if (action == 'write_health') {
    await _handleBackgroundHealthWrite(message.data);
  }
}

/// Processes a background health write request from the Cloud Brain.
///
/// Extracts the data type and value from the FCM payload, then
/// delegates to the native platform channel for the actual
/// HealthKit/Health Connect write operation.
///
/// This runs in a headless isolate — no UI context is available.
/// Errors are logged locally but never shown to the user.
///
/// [data] is the FCM message data map with keys:
/// - 'data_type': The health data category (e.g., 'nutrition', 'steps')
/// - 'value': JSON-encoded data payload to write
Future<void> _handleBackgroundHealthWrite(Map<String, dynamic> data) async {
  try {
    final dataType = data['data_type'] as String?;
    final valueJson = data['value'] as String?;

    if (dataType == null || valueJson == null) {
      return;
    }

    // In a background isolate, full Riverpod DI is not available.
    // Use a direct MethodChannel call for reliability.
    const channel = MethodChannel('com.lifelogger/health');

    await channel.invokeMethod('backgroundWrite', {
      'data_type': dataType,
      'value': valueJson,
    });
  } on PlatformException catch (e) {
    // Log but don't rethrow — background handler must not crash
    debugPrint('Background health write failed (PlatformException): $e');
  } on MissingPluginException catch (_) {
    // Plugin not registered in headless isolate — expected on some platforms
    debugPrint('Health plugin not available in background isolate');
  } catch (e) {
    debugPrint('Background health write failed: $e');
  }
}

/// Firebase Cloud Messaging service for push notifications.
///
/// Manages:
/// - Requesting notification permissions (iOS)
/// - Retrieving the device FCM token
/// - Handling foreground messages
/// - Registering the background message handler
class FCMService {
  /// The Firebase Messaging instance.
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// The device's current FCM token, if available.
  String? _token;

  /// The device's FCM registration token.
  ///
  /// Returns null if [initialize] has not been called or
  /// permission was denied.
  String? get token => _token;

  /// Initializes FCM: requests permissions, retrieves token,
  /// and sets up message handlers.
  ///
  /// Should be called once during app initialization, after
  /// Firebase.initializeApp().
  ///
  /// Returns the FCM token on success, or null if permission
  /// was denied.
  Future<String?> initialize() async {
    // Request notification permissions (primarily for iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return null;
    }

    // Get the FCM token for this device
    _token = await _messaging.getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      // TODO(phase-1.9): Re-register updated token with backend
      debugPrint('FCM token refreshed — re-register with backend to stay current');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    return _token;
  }

  /// Registers this device's FCM token with the Cloud Brain backend.
  ///
  /// Call this after [initialize] returns a non-null token. Posts the token
  /// to `POST /api/v1/devices/register` so the backend can send push
  /// notifications to this specific device.
  ///
  /// [apiClient] is the REST client used for backend communication.
  ///
  /// Returns `true` if registration succeeded, `false` otherwise.
  Future<bool> registerWithBackend(ApiClient apiClient) async {
    if (_token == null) {
      debugPrint('FCM: no token available — call initialize() first');
      return false;
    }

    try {
      await apiClient.post('/api/v1/devices/register', data: {
        'fcm_token': _token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      debugPrint('FCM: device registered with backend');
      return true;
    } catch (e) {
      debugPrint('FCM: device registration failed: $e');
      return false;
    }
  }

  /// Handles messages received while the app is in the foreground.
  ///
  /// For 'write_health' actions, delegates to the same write handler.
  /// For other messages, logs for debugging.
  ///
  /// [message] is the incoming FCM remote message.
  void _handleForegroundMessage(RemoteMessage message) {
    final action = message.data['action'];
    if (action == 'write_health') {
      _handleBackgroundHealthWrite(message.data);
    }
  }
}
