/// Life Logger Edge Agent — Secure Storage Wrapper.
///
/// Provides a clean API over FlutterSecureStorage for persisting
/// sensitive data (auth tokens, integration tokens) using the OS
/// secure enclave (iOS Keychain / Android EncryptedSharedPreferences).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] for secure key-value persistence.
///
/// All values are encrypted at rest using the platform's secure enclave:
/// - **iOS:** Keychain Services
/// - **Android:** EncryptedSharedPreferences (AES-256)
class SecureStorage {
  /// The underlying secure storage instance.
  final FlutterSecureStorage _storage;

  /// Creates a new [SecureStorage] wrapper.
  ///
  /// [storage] can be injected for testing.
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Writes a [value] to secure storage under the given [key].
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Reads the value stored under [key], or null if not found.
  Future<String?> read(String key) => _storage.read(key: key);

  /// Deletes the value stored under [key].
  Future<void> delete(String key) => _storage.delete(key: key);

  // --- Auth Token Convenience Methods ---

  /// Saves the user's JWT auth token.
  Future<void> saveAuthToken(String token) => write('auth_token', token);

  /// Retrieves the user's JWT auth token, or null if not stored.
  Future<String?> getAuthToken() => read('auth_token');

  /// Deletes the user's JWT auth token (used on logout).
  Future<void> clearAuthToken() => delete('auth_token');

  // --- Integration Token Convenience Methods ---

  /// Saves an OAuth token for a specific integration [provider].
  ///
  /// [provider] should match the integration name (e.g., 'strava', 'fitbit').
  Future<void> saveIntegrationToken(String provider, String token) =>
      write('integration_$provider', token);

  /// Retrieves the OAuth token for a specific integration [provider].
  Future<String?> getIntegrationToken(String provider) =>
      read('integration_$provider');
}
