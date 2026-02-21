/// Life Logger Edge Agent — OAuth Repository (Phase 1.6).
///
/// Handles the client-side steps of the Strava OAuth 2.0 flow:
/// fetching the authorization URL from the Cloud Brain and forwarding
/// the intercepted authorization code back for server-side token exchange.
///
/// The Cloud Brain keeps the Client Secret; this repository only sends
/// the short-lived [code] and [userId] to complete the handshake.
library;

import 'package:life_logger/core/network/api_client.dart';

/// Repository responsible for initiating and completing OAuth flows
/// with third-party integrations (currently Strava).
///
/// All network calls go through [ApiClient], which automatically
/// injects the user's auth token into every request.
class OAuthRepository {
  /// Creates an [OAuthRepository] backed by the given [ApiClient].
  const OAuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Request the Strava authorization URL from the Cloud Brain.
  ///
  /// The returned URL should be opened in the system browser via
  /// `launchUrl(..., mode: LaunchMode.externalApplication)` so that
  /// Strava's login cookies persist and the deep-link return works.
  ///
  /// Returns:
  ///   The Strava OAuth URL string, or `null` if the request fails.
  Future<String?> getStravaAuthUrl() async {
    try {
      final response = await _apiClient.get('/integrations/strava/authorize');
      final data = response.data as Map<String, dynamic>;
      return data['auth_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Forward the intercepted Strava authorization code to the Cloud Brain
  /// for server-side token exchange.
  ///
  /// Called automatically by [DeeplinkHandler] after the app intercepts
  /// the `lifelogger://oauth/strava?code=XXX` deep link.
  ///
  /// Args:
  ///   code: The short-lived authorization code from Strava (expires quickly).
  ///   userId: The currently authenticated user's ID, used by the backend
  ///     to key the stored token.
  ///
  /// Returns:
  ///   `true` if the exchange succeeded and Strava is now connected.
  Future<bool> handleStravaCallback(String code, String userId) async {
    try {
      final response = await _apiClient.post(
        '/integrations/strava/exchange',
        queryParameters: <String, dynamic>{'code': code, 'user_id': userId},
      );
      final data = response.data as Map<String, dynamic>;
      return (data['success'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
