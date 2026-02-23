/// Zuralog Edge Agent — Authentication State Models.
///
/// Defines the [AuthResult] sealed class for representing authentication
/// outcomes, and the [AuthState] enum for tracking the global auth status.
library;

/// The result of an authentication operation (login, register).
///
/// Use pattern matching to handle success and failure cases:
/// ```dart
/// switch (result) {
///   case AuthSuccess(:final userId):
///     // navigate to home
///   case AuthFailure(:final message):
///     // show error
/// }
/// ```
sealed class AuthResult {
  /// Creates an [AuthResult].
  const AuthResult();
}

/// A successful authentication result.
///
/// Contains the user's ID and session tokens returned by the backend.
class AuthSuccess extends AuthResult {
  /// The authenticated user's Supabase UID.
  final String userId;

  /// Short-lived JWT access token.
  final String accessToken;

  /// Long-lived refresh token for silent session renewal.
  final String refreshToken;

  /// Creates an [AuthSuccess].
  ///
  /// All fields are required.
  const AuthSuccess({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });
}

/// A failed authentication result.
///
/// Contains a human-readable error message for display.
class AuthFailure extends AuthResult {
  /// Describes what went wrong (e.g., "Invalid credentials").
  final String message;

  /// Creates an [AuthFailure] with the given error [message].
  const AuthFailure({required this.message});
}

/// Global authentication state of the application.
///
/// Used by the auth state notifier to drive navigation
/// (e.g., redirect to login screen when [unauthenticated]).
enum AuthState {
  /// The user is authenticated and has valid tokens.
  authenticated,

  /// The user is not authenticated (no tokens or tokens expired).
  unauthenticated,

  /// An authentication operation is in progress.
  loading,
}
