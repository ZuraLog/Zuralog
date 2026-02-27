/// Zuralog Edge Agent — Deep Link Handler (Phase 1.6).
///
/// Listens for incoming custom URL scheme links (`zuralog://`) and
/// dispatches them to the appropriate handler. Currently handles Strava
/// and Fitbit OAuth callbacks; additional integrations can be added here
/// in future phases by extending the switch on [Uri.pathSegments].
///
/// Usage: call [DeeplinkHandler.init] once from the root screen's
/// [State.initState] so the subscription is active for the app lifetime.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';

/// Handles incoming deep links for OAuth callback interception.
///
/// Subscribes to the [AppLinks] URI stream and routes recognised
/// `zuralog://` links to the correct handler method.
class DeeplinkHandler {
  DeeplinkHandler._();

  static StreamSubscription<Uri>? _subscription;

  /// Start listening for deep links.
  ///
  /// Must be called once (e.g. from the harness or root screen's
  /// [State.initState]). Safe to call multiple times — subsequent calls
  /// cancel the previous subscription before creating a new one.
  ///
  /// Args:
  ///   ref: A [WidgetRef] used to read Riverpod providers for dispatching.
  ///   onLog: Callback invoked with human-readable status messages so
  ///     the harness screen can display progress without coupling this
  ///     handler to any specific UI widget.
  static void init(WidgetRef ref, {required void Function(String) onLog}) {
    _subscription?.cancel();
    _subscription = AppLinks().uriLinkStream.listen(
      (uri) => _handleUri(uri, ref, onLog: onLog),
      onError: (Object error) => onLog('❌ Deep link error: $error'),
    );
  }

  /// Cancel the active deep link subscription.
  ///
  /// Call from [State.dispose] if the subscribing widget is removed.
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ------------------------------------------------------------------
  // Private dispatch
  // ------------------------------------------------------------------

  /// Route a received [uri] to the correct handler based on host.
  static Future<void> _handleUri(
    Uri uri,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    if (uri.scheme != 'zuralog') return;

    switch (uri.host) {
      case 'oauth':
        await _handleOAuth(uri, ref, onLog: onLog);
      default:
        onLog('⚠️ Unrecognised deep link: $uri');
    }
  }

  /// Handle `zuralog://oauth/<provider>?code=XXX` callbacks.
  ///
  /// Extracts the `code` (and optional `state`) query parameters and
  /// dispatches to the appropriate OAuth repository based on the path segment.
  static Future<void> _handleOAuth(
    Uri uri,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    final provider = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final code = uri.queryParameters['code'];

    if (code == null || code.isEmpty) {
      onLog('⚠️ OAuth callback missing code param: $uri');
      return;
    }

    switch (provider) {
      case 'strava':
        await _handleStravaCallback(code, ref, onLog: onLog);
      case 'fitbit':
        final state = uri.queryParameters['state'] ?? '';
        await _handleFitbitCallback(code, state, ref, onLog: onLog);
      default:
        onLog('⚠️ Unknown OAuth provider in deep link: $provider');
    }
  }

  /// Exchange the Strava authorization code for tokens via the Cloud Brain.
  ///
  /// Reads the stored user ID from [SecureStorage] so the backend can
  /// associate the token with the correct account.
  static Future<void> _handleStravaCallback(
    String code,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    onLog('🔗 Strava OAuth callback received, exchanging code...');

    final storage = ref.read(secureStorageProvider);
    final userId = await storage.read('user_id');

    if (userId == null) {
      onLog('❌ Cannot exchange Strava code — no user_id in secure storage. Log in first.');
      return;
    }

    final oauthRepo = ref.read(oauthRepositoryProvider);
    final success = await oauthRepo.handleStravaCallback(code, userId);

    if (success) {
      onLog('✅ Strava connected successfully!');
    } else {
      onLog('❌ Strava token exchange failed. Check server logs.');
    }
  }

  /// Exchange the Fitbit authorization code and PKCE state for tokens via
  /// the Cloud Brain.
  ///
  /// Reads the stored user ID from [SecureStorage] so the backend can
  /// associate the token with the correct account.
  ///
  /// Args:
  ///   code: The short-lived authorization code from Fitbit.
  ///   state: The PKCE state parameter used by the backend to retrieve the
  ///     stored code verifier.
  static Future<void> _handleFitbitCallback(
    String code,
    String state,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    onLog('🔗 Fitbit OAuth callback received, exchanging code...');

    final storage = ref.read(secureStorageProvider);
    final userId = await storage.read('user_id');

    if (userId == null) {
      onLog('❌ Cannot exchange Fitbit code — no user_id in secure storage. Log in first.');
      return;
    }

    final oauthRepo = ref.read(oauthRepositoryProvider);
    final success = await oauthRepo.handleFitbitCallback(code, state, userId);

    if (success) {
      onLog('✅ Fitbit connected successfully!');
    } else {
      onLog('❌ Fitbit token exchange failed. Check server logs.');
    }
  }
}
