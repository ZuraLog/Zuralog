/// Life Logger Edge Agent — REST API Client.
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
/// Base URL is configurable for different environments (Android emulator,
/// iOS simulator, production).
class ApiClient {
  /// The underlying Dio HTTP client instance.
  final Dio _dio;

  /// Secure storage for reading/writing auth tokens.
  final FlutterSecureStorage _storage;

  /// Creates a new [ApiClient].
  ///
  /// [baseUrl] defaults to the Android emulator localhost alias.
  /// Override for iOS simulator (`http://localhost:8000`) or
  /// production (`https://api.lifelogger.com`).
  ///
  /// [dio] and [storage] can be injected for testing.
  ApiClient({
    String baseUrl = const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
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
      // Refresh failed — clear tokens to force re-login
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
      return handler.next(error);
    }
  }

  /// Sends a GET request to the given [path].
  ///
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> get(String path) => _dio.get(path);

  /// Sends a POST request to the given [path] with optional [data] and
  /// [queryParameters].
  ///
  /// [queryParameters] are appended to the URL as query string key-value pairs.
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.post(path, data: data, queryParameters: queryParameters);
}
