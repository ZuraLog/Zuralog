/// Life Logger Edge Agent — Firebase Cloud Messaging Service.
///
/// Handles FCM initialization, permission requests, token retrieval,
/// and background/foreground message handling. Scaffolded for Phase 1.9.7 —
/// requires Firebase project configuration files (GoogleService-Info.plist
/// for iOS, google-services.json for Android) to function.
library;

import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles top-level background messages from FCM.
///
/// This must be a top-level function (not a class method) because
/// Flutter runs it in a separate isolate.
///
/// [message] is the incoming FCM remote message.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // TODO(phase-1.9): Process background data messages (e.g., sync triggers)
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
      // TODO(phase-1.9): Send updated token to backend
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    return _token;
  }

  /// Handles messages received while the app is in the foreground.
  ///
  /// [message] is the incoming FCM remote message.
  void _handleForegroundMessage(RemoteMessage message) {
    // TODO(phase-1.9): Show in-app notification banner or toast
  }
}
