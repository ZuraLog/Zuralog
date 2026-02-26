/// Zuralog Edge Agent — REST API Client.
///
/// A centralized HTTP client built on Dio with automatic authentication
/// token injection and silent token refresh via interceptors. Provides
/// type-safe REST methods for communicating with the Cloud Brain backend.
library;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// REST API client for Cloud Brain communication.
///
/// Automatically injects the user's auth token into every request
/// via a Dio interceptor. On 401 responses, transparently refreshes
/// the token using the stored refresh token and retries the request.
///
/// If the refresh token is also expired (i.e., the refresh call itself
/// fails), [onUnauthenticated] is invoked so the app can force-logout
/// the user and redirect them to the login screen.
///
/// Base URL is configurable for different environments (Android emulator,
/// iOS simulator, production).
class ApiClient {
  /// The underlying Dio HTTP client instance.
  final Dio _dio;

  /// Secure storage for reading/writing auth tokens.
  final FlutterSecureStorage _storage;

  /// Optional callback invoked when a 401 cannot be recovered by token
  /// refresh (i.e., both the access token and the refresh token are
  /// expired or invalid). Wire this to [AuthStateNotifier.forceLogout]
  /// via the DI provider so the app redirects to the login screen.
  final void Function()? onUnauthenticated;

  /// Creates a new [ApiClient].
  ///
  /// [baseUrl] defaults to the Android emulator localhost alias.
  /// Override for iOS simulator (`http://localhost:8001`) or
  /// production (`https://api.zuralog.com`).
  ///
  /// [onUnauthenticated] is called when both the access token and the
  /// refresh token are expired, signalling the app to force-logout.
  ///
  /// [dio] and [storage] can be injected for testing.
  ApiClient({
    String baseUrl = const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://10.0.2.2:8001',
    ),
    this.onUnauthenticated,
    Dio? dio,
    FlutterSecureStorage? storage,
  }) : _dio = dio ?? Dio(),
       _storage = storage ?? const FlutterSecureStorage() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  /// Injects the stored auth token into every outgoing request.
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  /// Handles 401 errors by attempting a silent token refresh.
  ///
  /// On receiving a 401 Unauthorized response:
  /// 1. Reads the stored refresh token.
  /// 2. Calls `/api/v1/auth/refresh` with a fresh Dio instance
  ///    (to avoid triggering this interceptor recursively).
  /// 3. On success: saves new tokens and retries the original request.
  /// 4. On failure: clears stored tokens (forces re-login).
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode != 401) {
      return handler.next(error);
    }

    // Don't attempt refresh on auth endpoints themselves to avoid loops
    final path = error.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh')) {
      return handler.next(error);
    }

    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      return handler.next(error);
    }

    try {
      // Use a separate Dio instance to avoid recursive interceptor calls
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;

      // Persist new tokens
      await _storage.write(key: 'auth_token', value: newAccessToken);
      await _storage.write(key: 'refresh_token', value: newRefreshToken);

      // Retry the original request with the new token
      final opts = error.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await _dio.request(
        opts.path,
        options: Options(method: opts.method, headers: opts.headers),
        data: opts.data,
        queryParameters: opts.queryParameters,
      );
      return handler.resolve(retryResponse);
    } catch (_) {
      // Refresh failed — clear tokens and notify the app to force-logout.
      // This happens when both the access token and refresh token are
      // expired (e.g., user hasn't opened the app in >7 days).
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
      onUnauthenticated?.call();
      return handler.next(error);
    }
  }

  /// The base URL this client is configured to communicate with.
  ///
  /// Exposed so other services (e.g. background sync) can pass the URL to
  /// native code without having to re-read it from the environment.
  String get baseUrl => _dio.options.baseUrl;

  /// Sends a GET request to the given [path] with optional [queryParameters].
  ///
  /// [queryParameters] are appended to the URL as query string key-value pairs.
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _dio.get(path, queryParameters: queryParameters);

  /// Sends a POST request to the given [path] with optional [data] and
  /// [queryParameters].
  ///
  /// [queryParameters] are appended to the URL as query string key-value pairs.
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) => _dio.post(path, data: data, queryParameters: queryParameters);

  /// Sends a PATCH request to the given [path] with optional [body].
  ///
  /// Used for partial resource updates where only provided fields should
  /// be modified on the server. Unlike PUT, fields absent from [body]
  /// remain unchanged on the backend.
  ///
  /// [body] is serialised as JSON and sent as the request body.
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _dio.patch(path, data: body);

  // -------------------------------------------------------------------------
  // Error Helpers
  // -------------------------------------------------------------------------

  /// Produces a user-friendly error message from a [DioException].
  ///
  /// Differentiates between connection errors (backend unreachable)
  /// and HTTP errors (backend responded with an error status).
  ///
  /// [e] is the Dio exception to format.
  ///
  /// Returns a human-readable error string suitable for display in
  /// developer logs or UI error messages.
  static String friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Is the Cloud Brain running at '
            '${e.requestOptions.baseUrl}?';
      case DioExceptionType.connectionError:
        return 'Cannot reach Cloud Brain at ${e.requestOptions.baseUrl}. '
            'Start the backend with: cd cloud-brain && make dev';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final detail = _extractDetail(e);
        return 'Server error ($code): $detail';
      default:
        return 'Network error: ${e.message}';
    }
  }

  /// Extracts the `detail` field from a backend error response.
  ///
  /// FastAPI returns `{"detail": "..."}` for HTTP errors.
  /// Falls back to the status message if parsing fails.
  ///
  /// [e] is the Dio exception containing the response.
  ///
  /// Returns the error detail string.
  static String _extractDetail(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    } catch (_) {
      // Fall through to generic message
    }
    return e.response?.statusMessage ?? 'Unknown error';
  }
}
