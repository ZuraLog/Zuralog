/// Zuralog Edge Agent — Auth Repository.
///
/// Handles communication with the Cloud Brain auth endpoints and
/// manages local persistence of authentication tokens via
/// [SecureStorage]. Returns typed [AuthResult] instead of bare
/// booleans to provide error context to the UI.
library;

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';

/// Repository for authentication operations.
///
/// Abstracts the Cloud Brain auth API behind clean methods that
/// handle both the network call and local token persistence.
/// All methods return [AuthResult] for typed success/failure handling.
class AuthRepository {
  /// The REST API client for Cloud Brain communication.
  final ApiClient _apiClient;

  /// Secure storage for persisting auth tokens.
  final SecureStorage _secureStorage;

  /// Creates a new [AuthRepository].
  ///
  /// [apiClient] is used for HTTP calls to the Cloud Brain.
  /// [secureStorage] is used for persisting JWT tokens.
  AuthRepository({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
  }) : _apiClient = apiClient,
       _secureStorage = secureStorage;

  /// Authenticates an existing user.
  ///
  /// Calls `POST /api/v1/auth/login` with email and password.
  /// On success, saves both access and refresh tokens to secure storage.
  ///
  /// Args:
  ///   [email]: User's email address.
  ///   [password]: User's password.
  ///
  /// Returns:
  ///   [AuthSuccess] with user ID and tokens on success.
  ///   [AuthFailure] with error message on failure.
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      await _saveTokens(
        userId: data['user_id'] as String,
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      return AuthSuccess(
        userId: data['user_id'] as String,
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
    } on DioException catch (e) {
      return AuthFailure(message: _extractErrorMessage(e));
    }
  }

  /// Registers a new user.
  ///
  /// Calls `POST /api/v1/auth/register` with email and password.
  /// On success, saves both access and refresh tokens to secure storage.
  ///
  /// Args:
  ///   [email]: User's email address.
  ///   [password]: User's password (min 6 chars enforced by Supabase).
  ///
  /// Returns:
  ///   [AuthSuccess] with user ID and tokens on success.
  ///   [AuthFailure] with error message on failure.
  Future<AuthResult> register(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/register',
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      await _saveTokens(
        userId: data['user_id'] as String,
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      return AuthSuccess(
        userId: data['user_id'] as String,
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
    } on DioException catch (e) {
      return AuthFailure(message: _extractErrorMessage(e));
    }
  }

  /// Logs out the current user.
  ///
  /// Calls `POST /api/v1/auth/logout` to invalidate the server session,
  /// then clears local tokens regardless of server response.
  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } on DioException {
      // Server-side logout failure is non-critical.
      // Local token cleanup is what matters for the client.
    }
    await _clearTokens();
  }

  /// Fetches the current user's profile from the backend.
  ///
  /// Calls `GET /api/v1/me/profile` using the stored auth token.
  ///
  /// Returns:
  ///   A fully populated [UserProfile] on success.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<UserProfile> fetchProfile() async {
    final response = await _apiClient.get('/api/v1/me/profile');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates the current user's profile. Only non-null fields are sent.
  ///
  /// Calls `PATCH /api/v1/me/profile` with only the provided fields, so
  /// omitted parameters retain their current server-side values.
  ///
  /// Args:
  ///   [displayName]: New display name (optional).
  ///   [nickname]: New nickname for AI greetings (optional).
  ///   [birthday]: New date of birth (optional). Sent as `YYYY-MM-DD`.
  ///   [gender]: New gender identifier (optional).
  ///   [onboardingComplete]: Marks onboarding as done (optional).
  ///
  /// Returns:
  ///   The updated [UserProfile] as returned by the server.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<UserProfile> updateProfile({
    String? displayName,
    String? nickname,
    DateTime? birthday,
    String? gender,
    bool? onboardingComplete,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (nickname != null) body['nickname'] = nickname;
    if (birthday != null) {
      body['birthday'] = birthday.toIso8601String().split('T').first;
    }
    if (gender != null) body['gender'] = gender;
    if (onboardingComplete != null) {
      body['onboarding_complete'] = onboardingComplete;
    }
    final response = await _apiClient.patch(
      '/api/v1/me/profile',
      body: body,
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Checks if the user has a stored auth token.
  ///
  /// This is a quick local check — it does NOT validate the token
  /// with the server. Used for initial routing on app launch.
  ///
  /// Returns:
  ///   `true` if an access token exists in secure storage.
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getAuthToken();
    return token != null;
  }

  /// Saves user ID and auth tokens to secure storage.
  ///
  /// Persisting [userId] alongside tokens allows downstream features
  /// (e.g. OAuth integrations in Phase 1.6) to identify the user
  /// without requiring a server round-trip.
  Future<void> _saveTokens({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write('user_id', userId);
    await _secureStorage.saveAuthToken(accessToken);
    await _secureStorage.write('refresh_token', refreshToken);
  }

  /// Clears all auth tokens and the user ID from secure storage.
  Future<void> _clearTokens() async {
    await _secureStorage.delete('user_id');
    await _secureStorage.clearAuthToken();
    await _secureStorage.delete('refresh_token');
  }

  /// Extracts a human-readable error message from a Dio exception.
  ///
  /// Attempts to parse the backend's error response. Falls back to
  /// a generic message if parsing fails.
  String _extractErrorMessage(DioException error) {
    try {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return data['detail'] as String;
      }
    } catch (_) {
      // Fall through to generic message
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your network.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
