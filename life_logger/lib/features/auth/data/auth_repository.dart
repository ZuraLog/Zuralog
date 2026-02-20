/// Life Logger Edge Agent — Auth Repository.
///
/// Handles communication with the Cloud Brain auth endpoints and
/// manages local persistence of authentication tokens via
/// [SecureStorage]. Returns typed [AuthResult] instead of bare
/// booleans to provide error context to the UI.
library;

import 'package:dio/dio.dart';

import 'package:life_logger/core/network/api_client.dart';
import 'package:life_logger/core/storage/secure_storage.dart';
import 'package:life_logger/features/auth/domain/auth_state.dart';

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
        data['access_token'] as String,
        data['refresh_token'] as String,
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
        data['access_token'] as String,
        data['refresh_token'] as String,
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

  /// Saves access and refresh tokens to secure storage.
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.saveAuthToken(accessToken);
    await _secureStorage.write('refresh_token', refreshToken);
  }

  /// Clears all auth tokens from secure storage.
  Future<void> _clearTokens() async {
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
