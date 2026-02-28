/// Zuralog Edge Agent — Social Auth Service.
///
/// Wraps the native OAuth provider SDKs (Google Sign In and Sign in with
/// Apple) to produce [SocialAuthCredentials] ready for the Cloud Brain
/// backend. All platform-specific SDK interactions are isolated here,
/// keeping [AuthRepository] and the UI layer clean and provider-agnostic.
///
/// **Google**: Uses `google_sign_in` with a separate serverClientId (OAuth
/// Web Client ID from Google Cloud Console). Note that this is different
/// from the Firebase project Client ID — see the credential setup guide.
///
/// **Apple**: Currently stubbed. Full implementation requires an active
/// Apple Developer Program membership ($99/year). The stub throws an
/// [UnsupportedError] with a descriptive message so callers can surface
/// a user-friendly dialog.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:zuralog/features/auth/domain/social_auth_credentials.dart';

/// Service that orchestrates native OAuth sign-in flows.
///
/// Interacts directly with platform SDKs (Google Sign In, Sign in with
/// Apple) and converts their results into provider-agnostic
/// [SocialAuthCredentials] objects.
///
/// This service is stateless — all SDK state is managed by the underlying
/// packages. Instantiate it once via the Riverpod DI layer.
class SocialAuthService {
  /// Creates a [SocialAuthService].
  ///
  /// [googleWebClientId] is the OAuth 2.0 **Web Client ID** from Google
  /// Cloud Console (not the Firebase iOS/Android client ID). It is used
  /// as `serverClientId` in `GoogleSignIn()` so that a server-verifiable
  /// `idToken` is included in the authentication result.
  ///
  /// Throws an [ArgumentError] in debug mode if [googleWebClientId] is
  /// empty — this is a configuration error, not a runtime error.
  SocialAuthService({required String googleWebClientId})
    : _googleWebClientId = googleWebClientId {
    assert(
      googleWebClientId.isNotEmpty,
      'googleWebClientId must not be empty. '
      'Check your --dart-define GOOGLE_WEB_CLIENT_ID configuration.',
    );
  }

  final String _googleWebClientId;

  // ── Google Sign In ─────────────────────────────────────────────────────────

  /// Initiates the native Google Sign In flow.
  ///
  /// Presents the native Google account picker sheet. On iOS, this uses
  /// the GIDSignIn native flow. On Android, it uses Google Play Services.
  ///
  /// The [GoogleSignIn] instance uses [_googleWebClientId] as
  /// `serverClientId` so that Supabase can validate the returned `idToken`
  /// (which is signed for the web client, not the mobile client).
  ///
  /// Returns:
  ///   [SocialAuthCredentials] with `provider == SocialProvider.google`,
  ///   a valid `idToken`, and a valid `accessToken`.
  ///
  /// Throws:
  ///   [SocialAuthCancelledException] if the user dismisses the sign-in
  ///   dialog without selecting an account.
  ///   [SocialAuthException] if the SDK returns null tokens (unexpected
  ///   state, e.g., Google Play Services unavailable on Android).
  Future<SocialAuthCredentials> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);

    // `signIn()` returns null if the user cancels.
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const SocialAuthCancelledException(provider: SocialProvider.google);
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      // This can happen if serverClientId is misconfigured — the SDK
      // returns an accessToken but no idToken without a serverClientId.
      throw SocialAuthException(
        provider: SocialProvider.google,
        message:
            'Google Sign In returned no idToken. '
            'Ensure GOOGLE_WEB_CLIENT_ID is set to the OAuth 2.0 '
            'Web Client ID (not the iOS/Android client ID).',
      );
    }
    if (accessToken == null) {
      throw SocialAuthException(
        provider: SocialProvider.google,
        message: 'Google Sign In returned no accessToken.',
      );
    }

    debugPrint(
      '[SocialAuthService] Google sign-in succeeded for '
      '${googleUser.email}',
    );

    return SocialAuthCredentials(
      provider: SocialProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // ── Apple Sign In ──────────────────────────────────────────────────────────

  /// Initiates the native Sign in with Apple flow.
  ///
  /// Generates a cryptographically random nonce, hashes it with SHA-256,
  /// and passes the hash to the Apple SDK. Apple embeds the hash in the
  /// returned `identityToken` — Supabase re-hashes the raw nonce we send
  /// and compares it to prevent replay attacks.
  ///
  /// On iOS/macOS the native Apple Sign In sheet is displayed. On Android,
  /// the `sign_in_with_apple` package opens a web-based flow (requires a
  /// redirect URL configured in the Apple Developer Portal pointing to
  /// the Supabase callback URL).
  ///
  /// **STUBBED**: Returns an [UnsupportedError] until Apple Developer
  /// Program credentials are configured. Once you have:
  ///   1. An Apple Developer Program membership ($99/year)
  ///   2. A Services ID with Sign in with Apple enabled
  ///   3. The Apple provider configured in the Supabase dashboard
  ///   4. For Android: an HTTPS redirect URI pointing to Supabase callback
  ///
  /// Remove the stub body and uncomment the real implementation below.
  ///
  /// Returns:
  ///   [SocialAuthCredentials] with `provider == SocialProvider.apple`,
  ///   a valid `idToken`, and the raw `nonce`.
  ///
  /// Throws:
  ///   [UnsupportedError] — stub until credentials are configured.
  ///   [SocialAuthCancelledException] if the user cancels.
  ///   [SocialAuthException] for unexpected SDK failures.
  Future<SocialAuthCredentials> signInWithApple() async {
    // ── STUB ──────────────────────────────────────────────────────────────
    // Apple Sign In requires an Apple Developer Program membership.
    // Replace this stub by following the setup guide in:
    //   docs/plans/2026-02-23-social-oauth-design.md
    // and then uncommenting the real implementation below.
    throw UnsupportedError(
      'Apple Sign In is not yet configured. '
      'An Apple Developer Program membership (\$99/year) is required. '
      'See docs/plans/2026-02-23-social-oauth-design.md for setup steps.',
    );

    // ── REAL IMPLEMENTATION (uncomment once credentials are ready) ────────
    // ignore: dead_code
    final rawNonce = _generateRawNonce();
    final hashedNonce = _sha256OfString(rawNonce);

    AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        // For Android web-based flow, configure a redirect URI that
        // points to your Supabase auth callback:
        //   https://<your-project-ref>.supabase.co/auth/v1/callback
        // webAuthenticationOptions: WebAuthenticationOptions(
        //   clientId: 'com.zuralog.auth',
        //   redirectUri: Uri.parse(
        //     'https://<your-project-ref>.supabase.co/auth/v1/callback',
        //   ),
        // ),
      );
    } on SignInWithAppleAuthorizationException catch (e, stackTrace) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialAuthCancelledException(
          provider: SocialProvider.apple,
        );
      }
      Sentry.captureException(e, stackTrace: stackTrace);
      throw SocialAuthException(
        provider: SocialProvider.apple,
        message: 'Apple Sign In failed: ${e.message}',
      );
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw SocialAuthException(
        provider: SocialProvider.apple,
        message: 'Apple Sign In returned no identityToken.',
      );
    }

    debugPrint('[SocialAuthService] Apple sign-in succeeded');

    return SocialAuthCredentials(
      provider: SocialProvider.apple,
      idToken: idToken,
      nonce: rawNonce, // raw nonce — NOT the hash
    );
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Generates a cryptographically random 32-byte nonce, base64url encoded.
  ///
  /// This raw value is passed to the Apple SDK as a *hashed* nonce
  /// (SHA-256), and sent to Supabase as the *raw* nonce for verification.
  ///
  /// Returns:
  ///   A URL-safe base64-encoded 32-byte random string.
  String _generateRawNonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    // base64Url encoding avoids characters that are invalid in a nonce.
    return base64Url.encode(bytes);
  }

  /// Computes the SHA-256 hash of [input] as a lowercase hex string.
  ///
  /// Used to hash the raw nonce before passing it to the Apple Sign In SDK.
  /// Apple stores this hash in the identity token; Supabase re-hashes the
  /// raw nonce we provide and compares to detect replay attacks.
  ///
  /// Args:
  ///   [input]: The raw nonce string to hash.
  ///
  /// Returns:
  ///   The SHA-256 digest as a lowercase hexadecimal string.
  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

// ── Exception Types ────────────────────────────────────────────────────────────

/// Base class for social authentication failures.
class SocialAuthException implements Exception {
  /// Creates a [SocialAuthException].
  const SocialAuthException({required this.provider, required this.message});

  /// The provider that caused the failure.
  final SocialProvider provider;

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'SocialAuthException(${provider.name}): $message';
}

/// Thrown when the user actively cancels the OAuth sign-in dialog.
///
/// Callers should treat this as a non-error (no error message shown to
/// the user) — the user simply changed their mind.
class SocialAuthCancelledException extends SocialAuthException {
  /// Creates a [SocialAuthCancelledException] for the given [provider].
  const SocialAuthCancelledException({required super.provider})
    : super(message: 'User cancelled sign-in');
}
