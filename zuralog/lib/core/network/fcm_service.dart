/// Zuralog Edge Agent — Firebase Cloud Messaging Service.
///
/// Handles FCM initialization, permission requests, token retrieval,
/// and background/foreground message handling. Scaffolded for Phase 1.9.7 —
/// requires Firebase project configuration files (GoogleService-Info.plist
/// for iOS, google-services.json for Android) to function.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/health/data/health_repository.dart';

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
  } else if (action == 'read_health') {
    // For background 'read_health', delegate to the native MethodChannel.
    // The native Swift code (HealthKitBridge.triggerSync) will read HealthKit
    // and POST to the ingest endpoint directly via URLSession — no Dart needed.
    final dataType = message.data['data_type'] as String? ?? 'all';
    try {
      const channel = MethodChannel('com.zuralog/health');
      await channel.invokeMethod('triggerSync', {'type': dataType});
    } on PlatformException catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('Background read_health failed (PlatformException): $e');
    } on MissingPluginException catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('Health plugin not available in background isolate');
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('Background read_health failed: $e');
    }
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
    const channel = MethodChannel('com.zuralog/health');

    await channel.invokeMethod('backgroundWrite', {
      'data_type': dataType,
      'value': valueJson,
    });
  } on PlatformException catch (e, stackTrace) {
    // Log but don't rethrow — background handler must not crash
    Sentry.captureException(e, stackTrace: stackTrace);
    debugPrint('Background health write failed (PlatformException): $e');
  } on MissingPluginException catch (e, stackTrace) {
    // Plugin not registered in headless isolate — expected on some platforms
    Sentry.captureException(e, stackTrace: stackTrace);
    debugPrint('Health plugin not available in background isolate');
  } catch (e, stackTrace) {
    Sentry.captureException(e, stackTrace: stackTrace);
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

  /// Stored API client for token-refresh re-registration.
  ApiClient? _apiClient;

  /// Stored health repository for 'read_health' FCM action handling.
  HealthRepository? _healthRepository;

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

    // Listen for token refresh — re-register with backend automatically.
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      debugPrint('FCM token refreshed — re-registering with backend');
      if (_apiClient != null) {
        // Fire-and-forget: update the Cloud Brain with the refreshed token.
        registerWithBackend(_apiClient!).then((success) {
          debugPrint(
            'FCM token re-registration '
            '${success ? 'succeeded' : 'failed'}',
          );
        });
      }
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
  /// Stores [apiClient] internally so that [onTokenRefresh] can automatically
  /// re-register without requiring the caller to pass the client again.
  ///
  /// [apiClient] is the REST client used for backend communication.
  ///
  /// Returns `true` if registration succeeded, `false` otherwise.
  Future<bool> registerWithBackend(ApiClient apiClient) async {
    // Store for automatic re-registration on token refresh.
    _apiClient = apiClient;

    if (_token == null) {
      debugPrint('FCM: no token available — call initialize() first');
      return false;
    }

    try {
      await apiClient.post(
        '/api/v1/devices/register',
        data: {
          'fcm_token': _token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
      debugPrint('FCM: device registered with backend');
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('FCM: device registration failed: $e');
      return false;
    }
  }

  /// Sets the [HealthRepository] used to handle 'read_health' FCM actions.
  ///
  /// Call this after app initialization so the FCM service can delegate
  /// 'read_health' push messages to the native HealthKit bridge.
  ///
  /// [healthRepository] must not be null when 'read_health' messages
  /// are expected from the Cloud Brain.
  void setHealthRepository(HealthRepository healthRepository) {
    _healthRepository = healthRepository;
  }

  /// Handles messages received while the app is in the foreground.
  ///
  /// Supported actions:
  /// - `'write_health'`: Delegates to the native platform channel write handler.
  /// - `'read_health'`: Reads the requested data type from HealthKit and triggers
  ///   a native background sync to push fresh data to the Cloud Brain ingest endpoint.
  ///
  /// [message] is the incoming FCM remote message.
  void _handleForegroundMessage(RemoteMessage message) {
    final action = message.data['action'];
    if (action == 'write_health') {
      _handleBackgroundHealthWrite(message.data);
    } else if (action == 'read_health') {
      _handleReadHealthAction(message.data);
    }
  }

  /// Handles a 'read_health' FCM push from the Cloud Brain.
  ///
  /// The Cloud Brain sends this to request a fresh read of a specific health
  /// data type. This method reads the latest data from HealthKit via the
  /// native bridge and posts it to the ingest endpoint.
  ///
  /// [data] is the FCM message data map with optional key:
  /// - 'data_type': The health type to sync (e.g. 'steps', 'workouts').
  ///   If absent, triggers a full daily metrics sync.
  void _handleReadHealthAction(Map<String, dynamic> data) {
    final dataType = data['data_type'] as String? ?? 'all';
    debugPrint('[FCMService] read_health action received — type: $dataType');

    if (_healthRepository != null) {
      // Use triggerSync which calls notifyOfChange() natively — this reads
      // HealthKit and POSTs directly to the Cloud Brain via URLSession.
      _healthRepository!.triggerSync(dataType).then((success) {
        debugPrint(
          '[FCMService] read_health triggerSync($dataType): '
          '${success ? 'dispatched' : 'failed'}',
        );
      });
    } else {
      debugPrint(
        '[FCMService] read_health: no HealthRepository set — '
        'call setHealthRepository() during app initialization',
      );
    }
  }
}
