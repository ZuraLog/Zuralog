/// Zuralog Edge Agent — Social Auth Credentials Model.
///
/// Represents the token payload collected from a native OAuth provider SDK
/// (Google Sign In or Sign in with Apple) before it is sent to the Cloud
/// Brain backend for validation.
///
/// This is an **intermediate** data transfer object — it is never persisted.
/// Once the backend validates the tokens and returns a Supabase session,
/// standard [AuthSuccess] / [AuthFailure] results take over.
library;

/// The OAuth provider that issued the credentials.
enum SocialProvider {
  /// Google Sign In via the google_sign_in package.
  google,

  /// Sign in with Apple via the sign_in_with_apple package.
  apple,
}

/// Credentials obtained from a native OAuth provider SDK.
///
/// Used to carry the raw token payload from [SocialAuthService] to
/// [AuthRepository.socialLogin]. The backend then validates the tokens
/// against Supabase GoTrue.
///
/// Example usage:
/// ```dart
/// final creds = await _socialAuthService.signInWithGoogle();
/// final result = await _authRepository.socialLogin(
///   provider: creds.provider.name,
///   idToken: creds.idToken,
///   accessToken: creds.accessToken,
///   nonce: creds.nonce,
/// );
/// ```
class SocialAuthCredentials {
  /// Creates [SocialAuthCredentials].
  ///
  /// [provider] and [idToken] are always required. [accessToken] is
  /// required for Google and unused for Apple. [nonce] is required for
  /// Apple (the raw un-hashed value) and unused for Google.
  const SocialAuthCredentials({
    required this.provider,
    required this.idToken,
    this.accessToken,
    this.nonce,
  });

  /// The provider that issued these credentials.
  final SocialProvider provider;

  /// The JWT identity token from the provider.
  ///
  /// For Google: the `idToken` from [GoogleSignInAuthentication].
  /// For Apple: the `identityToken` from [AuthorizationCredentialAppleID].
  final String idToken;

  /// The short-lived OAuth access token from the provider.
  ///
  /// Required for Google (used by Supabase to validate the token).
  /// Not present for Apple.
  final String? accessToken;

  /// The raw (un-hashed) nonce used to call Sign in with Apple.
  ///
  /// Required for Apple. The Apple SDK embeds the SHA-256 hash of this
  /// value in the identity token, allowing Supabase to confirm the
  /// request was not replayed.
  /// Not used for Google.
  final String? nonce;
}
