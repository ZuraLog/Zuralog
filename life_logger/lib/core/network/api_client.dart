/// Life Logger Edge Agent — REST API Client.
///
/// A centralized HTTP client built on Dio with automatic authentication
/// token injection via interceptors. Provides type-safe REST methods
/// for communicating with the Cloud Brain backend.
library;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// REST API client for Cloud Brain communication.
///
/// Automatically injects the user's auth token into every request
/// via a Dio interceptor. Base URL is configurable for different
/// environments (Android emulator, iOS simulator, production).
class ApiClient {
  /// The underlying Dio HTTP client instance.
  final Dio _dio;

  /// Secure storage for reading auth tokens.
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
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Sends a GET request to the given [path].
  ///
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> get(String path) => _dio.get(path);

  /// Sends a POST request to the given [path] with optional [data].
  ///
  /// Returns the Dio [Response] containing the server's response.
  Future<Response<dynamic>> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);
}
