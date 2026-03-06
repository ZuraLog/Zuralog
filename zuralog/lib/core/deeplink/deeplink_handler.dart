/// Zuralog Edge Agent — Deep Link Handler (Phase 1.6).
///
/// Listens for incoming custom URL scheme links (`zuralog://`) and
/// dispatches them to the appropriate handler. Currently handles Strava,
/// Fitbit, Oura Ring, and Withings OAuth callbacks; additional integrations
/// can be added here by extending the switch on [Uri.pathSegments].
///
/// Usage: call [DeeplinkHandler.init] once from the root screen's
/// [State.initState] so the subscription is active for the app lifetime.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';

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
      onError: (Object error) => onLog('Deep link error: $error'),
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
        onLog('Unrecognised deep link: $uri');
    }
  }

  /// Handle `zuralog://oauth/<provider>?...` callbacks.
  ///
  /// Most providers send `?code=XXX&state=YYY` for client-side exchange.
  /// Withings uses a server-side callback and sends only `?success=true/false`.
  static Future<void> _handleOAuth(
    Uri uri,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    final provider = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';

    // Withings: server-side callback — no code, only a success flag.
    if (provider == 'withings') {
      await _handleWithingsResult(uri, ref, onLog: onLog);
      return;
    }

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
      case 'oura':
        final state = uri.queryParameters['state'] ?? '';
        await _handleOuraCallback(code, state, ref, onLog: onLog);
      case 'polar':
        final state = uri.queryParameters['state'] ?? '';
        await _handlePolarCallback(code, state, ref, onLog: onLog);
      default:
        onLog('Unknown OAuth provider in deep link: $provider');
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

  /// Exchange the Polar authorization code and CSRF state for tokens
  /// via the Cloud Brain.
  ///
  /// Called after the app intercepts `zuralog://oauth/polar?code=XXX&state=YYY`.
  /// Polar uses a mandatory user registration step server-side after the token
  /// exchange; the backend handles this transparently.
  ///
  /// Args:
  ///   code: The short-lived authorization code from Polar (expires in 10 min).
  ///   state: The CSRF state parameter validated server-side.
  static Future<void> _handlePolarCallback(
    String code,
    String state,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    onLog('🔗 Polar OAuth callback received, exchanging code...');

    final storage = ref.read(secureStorageProvider);
    final userId = await storage.read('user_id');

    if (userId == null) {
      onLog('❌ Cannot exchange Polar code — no user_id in secure storage. Log in first.');
      return;
    }

    final oauthRepo = ref.read(oauthRepositoryProvider);
    final success = await oauthRepo.handlePolarCallback(code, state, userId);

    if (success) {
      onLog('✅ Polar connected successfully!');
    } else {
      onLog('❌ Polar token exchange failed. Check server logs.');
    }
  }


  /// Handle the Withings server-side OAuth result deep link.
  ///
  /// Withings redirects the browser back to the Cloud Brain callback URL,
  /// which exchanges the code and then redirects the browser to
  /// `zuralog://oauth/withings?success=true` (or `success=false`).
  ///
  /// No client-side code exchange is required — the server already handled it.
  /// On success, reload server state to confirm the connection. On failure,
  /// revert the optimistic "connected" state set by [connect()].
  static Future<void> _handleWithingsResult(
    Uri uri,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    final success = uri.queryParameters['success'] == 'true';
    final error = uri.queryParameters['error'];

    if (success) {
      onLog('Withings connected successfully!');
      // Reload from server to confirm persisted state.
      await ref.read(integrationsProvider.notifier).loadIntegrations();
    } else {
      onLog(
        'Withings connection failed${error != null ? ': $error' : ''}. '
        'Please try again.',
      );
      // Revert the optimistic "connected" state so the UI shows the correct
      // disconnected status rather than remaining stuck as "connected".
      ref.read(integrationsProvider.notifier).disconnect('withings');
    }
  }

  /// Exchange the Oura Ring authorization code and CSRF state for tokens
  /// via the Cloud Brain.
  ///
  /// Reads the stored user ID from [SecureStorage] so the backend can
  /// associate the token with the correct account.
  ///
  /// Args:
  ///   code: The short-lived authorization code from Oura.
  ///   state: The CSRF state parameter validated server-side.
  static Future<void> _handleOuraCallback(
    String code,
    String state,
    WidgetRef ref, {
    required void Function(String) onLog,
  }) async {
    onLog('🔗 Oura Ring OAuth callback received, exchanging code...');

    final storage = ref.read(secureStorageProvider);
    final userId = await storage.read('user_id');

    if (userId == null) {
      onLog('❌ Cannot exchange Oura code — no user_id in secure storage. Log in first.');
      return;
    }

    final oauthRepo = ref.read(oauthRepositoryProvider);
    final success = await oauthRepo.handleOuraCallback(code, state, userId);

    if (success) {
      onLog('✅ Oura Ring connected successfully!');
    } else {
      onLog('❌ Oura Ring token exchange failed. Check server logs.');
    }
  }
}
