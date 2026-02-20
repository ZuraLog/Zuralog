/// Life Logger Edge Agent — Auth Riverpod Providers.
///
/// Defines Riverpod providers for the authentication layer:
/// [authRepositoryProvider] for the repository singleton and
/// [authStateProvider] for reactive auth state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/core/di/providers.dart';
import 'package:life_logger/features/auth/data/auth_repository.dart';
import 'package:life_logger/features/auth/domain/auth_state.dart';

/// Provides a singleton [AuthRepository] instance.
///
/// Depends on [apiClientProvider] and [secureStorageProvider]
/// from the core DI layer.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

/// Provides the current [AuthState] and methods to update it.
///
/// Starts as [AuthState.unauthenticated] and transitions based on
/// login/logout operations.
final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

/// Notifier that manages [AuthState] transitions.
///
/// Wraps [AuthRepository] calls and updates the state accordingly.
/// The UI watches this provider to react to auth changes
/// (e.g., redirecting to login screen on logout).
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.unauthenticated;

  /// The auth repository, read from the provider graph.
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  /// Checks if the user has stored tokens and updates state.
  ///
  /// Called once on app startup to determine initial routing.
  Future<void> checkAuthStatus() async {
    state = AuthState.loading;
    final isLoggedIn = await _authRepository.isLoggedIn();
    state = isLoggedIn ? AuthState.authenticated : AuthState.unauthenticated;
  }

  /// Attempts to log in with the given credentials.
  ///
  /// Returns the [AuthResult] for the UI to display.
  /// Updates state to [AuthState.authenticated] on success.
  Future<AuthResult> login(String email, String password) async {
    state = AuthState.loading;
    final result = await _authRepository.login(email, password);

    switch (result) {
      case AuthSuccess():
        state = AuthState.authenticated;
      case AuthFailure():
        state = AuthState.unauthenticated;
    }

    return result;
  }

  /// Attempts to register with the given credentials.
  ///
  /// Returns the [AuthResult] for the UI to display.
  /// Updates state to [AuthState.authenticated] on success.
  Future<AuthResult> register(String email, String password) async {
    state = AuthState.loading;
    final result = await _authRepository.register(email, password);

    switch (result) {
      case AuthSuccess():
        state = AuthState.authenticated;
      case AuthFailure():
        state = AuthState.unauthenticated;
    }

    return result;
  }

  /// Logs out the current user.
  ///
  /// Always transitions to [AuthState.unauthenticated].
  Future<void> logout() async {
    state = AuthState.loading;
    await _authRepository.logout();
    state = AuthState.unauthenticated;
  }
}

/// Convenience provider that returns `true` when the user is authenticated.
///
/// Derived from [authStateProvider] for widgets that only care about
/// the boolean logged-in state.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider) == AuthState.authenticated;
});
