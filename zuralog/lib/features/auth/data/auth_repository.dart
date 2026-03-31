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

  /// Authenticates via a native OAuth provider (Google or Apple).
  ///
  /// Sends the provider's token payload to `POST /api/v1/auth/social`.
  /// The backend validates the ID token with Supabase GoTrue and returns
  /// standard session tokens. On success, tokens are persisted to secure
  /// storage exactly as in [login].
  ///
  /// Args:
  ///   [provider]: Provider name — "google" or "apple".
  ///   [idToken]: The JWT identity token from the provider SDK.
  ///   [accessToken]: Provider access token (required for Google).
  ///   [nonce]: Raw nonce for Apple replay prevention (required for Apple).
  ///
  /// Returns:
  ///   [AuthSuccess] with user ID and tokens on success.
  ///   [AuthFailure] with a human-readable error message on failure.
  Future<AuthResult> socialLogin({
    required String provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    try {
      final body = <String, dynamic>{
        'provider': provider,
        'id_token': idToken,
      };
      if (accessToken != null) body['access_token'] = accessToken;
      if (nonce != null) body['nonce'] = nonce;

      final response = await _apiClient.post(
        '/api/v1/auth/social',
        data: body,
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

  /// Re-sends the email verification link to the given address.
  ///
  /// Calls `POST /api/v1/auth/resend-verification` with the user's email.
  /// The backend triggers Supabase GoTrue to re-send the confirmation email.
  ///
  /// Args:
  ///   [email]: The email address to re-send the verification link to.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<void> resendVerification(String email) async {
    await _apiClient.post(
      '/api/v1/auth/resend-verification',
      data: {'email': email},
    );
  }

  /// Sends a password reset email to the given address.
  ///
  /// Calls `POST /api/v1/auth/reset-password` with the user's email.
  /// The backend triggers Supabase GoTrue to send a reset link.
  ///
  /// Args:
  ///   [email]: The email address to send the reset link to.
  ///
  /// Returns:
  ///   [AuthSuccess] (with empty token fields) on success.
  ///   [AuthFailure] with error message on failure.
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _apiClient.post(
        '/api/v1/auth/reset-password',
        data: {'email': email},
      );
      return const AuthSuccess(userId: '', accessToken: '', refreshToken: '');
    } on DioException catch (e) {
      return AuthFailure(message: _extractErrorMessage(e));
    }
  }

  /// Sets a new password using a recovery access token from the reset link.
  ///
  /// Calls `POST /api/v1/auth/set-password` with the new password, passing
  /// the recovery [accessToken] directly in the Authorization header instead
  /// of the stored auth token — the user is not yet logged in.
  ///
  /// Args:
  ///   [accessToken]: The short-lived recovery token from the deep link URL.
  ///   [newPassword]: The new password to set for the account.
  ///
  /// Returns:
  ///   [AuthSuccess] (with empty token fields) on success.
  ///   [AuthFailure] with error message on failure.
  Future<AuthResult> setNewPassword({
    required String accessToken,
    required String newPassword,
  }) async {
    try {
      await _apiClient.post(
        '/api/v1/auth/set-password',
        data: {'new_password': newPassword},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      return const AuthSuccess(userId: '', accessToken: '', refreshToken: '');
    } on DioException catch (e) {
      return AuthFailure(message: _extractErrorMessage(e));
    }
  }

  /// Permanently deletes the current user's account.
  ///
  /// Calls `DELETE /api/v1/users/me` which removes all user data from every
  /// table and removes the user from Supabase Auth on the server.
  /// On success (HTTP 204), clears local tokens so the app treats the
  /// session as ended.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<void> deleteAccount() async {
    await _apiClient.delete('/api/v1/users/me');
    await _clearTokens();
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
  /// Calls `GET /api/v1/users/me/profile` using the stored auth token.
  ///
  /// Returns:
  ///   A fully populated [UserProfile] on success.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<UserProfile> fetchProfile() async {
    final response = await _apiClient.get('/api/v1/users/me/profile');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates the current user's profile. Only non-null fields are sent.
  ///
  /// Calls `PATCH /api/v1/users/me/profile` with only the provided fields, so
  /// omitted parameters retain their current server-side values.
  ///
  /// Args:
  ///   [displayName]: New display name (optional).
  ///   [nickname]: New nickname for AI greetings (optional).
  ///   [birthday]: New date of birth (optional). Sent as `YYYY-MM-DD`.
  ///   [gender]: New gender identifier (optional).
  ///   [onboardingComplete]: Marks onboarding as done (optional).
  ///   [heightCm]: Height in centimetres (optional).
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
    double? heightCm,
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
    if (heightCm != null) body['height_cm'] = heightCm;
    final response = await _apiClient.patch(
      '/api/v1/users/me/profile',
      body: body,
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Requests an email address change for the current user.
  ///
  /// Calls `POST /api/v1/users/me/email`. The backend sends a confirmation
  /// email to [newEmail] — the change does not take effect until confirmed.
  ///
  /// Args:
  ///   [newEmail]: The new email address the user wants to switch to.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<void> changeEmail(String newEmail) async {
    await _apiClient.post(
      '/api/v1/users/me/email',
      data: {'new_email': newEmail},
    );
  }

  /// Changes the current user's password.
  ///
  /// Calls `POST /api/v1/users/me/password` with both the current and new
  /// passwords. The backend verifies [currentPassword] before applying the
  /// change.
  ///
  /// Args:
  ///   [currentPassword]: The user's existing password for verification.
  ///   [newPassword]: The new password to set.
  ///
  /// Throws:
  ///   [DioException] if the network call fails, the current password is
  ///   wrong, or the new password does not meet requirements.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/api/v1/users/me/password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  /// Uploads a new avatar image for the current user.
  ///
  /// Calls `POST /api/v1/users/me/avatar` as a multipart form upload.
  /// The file is sent under the field name `file`.
  ///
  /// Args:
  ///   [filePath]: Absolute path to the image file on the device.
  ///   [contentType]: MIME type of the image (e.g. `image/jpeg`).
  ///
  /// Returns:
  ///   The public URL of the newly uploaded avatar.
  ///
  /// Throws:
  ///   [DioException] if the network call fails or returns a non-2xx status.
  Future<String> uploadAvatar({
    required String filePath,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final response = await _apiClient.post(
      '/api/v1/users/me/avatar',
      data: formData,
    );
    final data = response.data as Map<String, dynamic>;
    return data['avatar_url'] as String;
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
