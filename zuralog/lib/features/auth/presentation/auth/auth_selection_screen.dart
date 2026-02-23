/// Zuralog Edge Agent — Auth Selection Screen.
///
/// A focused "Clean Gate" screen that presents the full account-creation menu:
/// Apple Sign In (stub), Google Sign In (stub), or email/password registration.
/// Also provides a log-in link for returning users.
///
/// **Design direction:** "Clean Gate" — minimal, no distractions, legal footer.
///
/// Note: Apple and Google sign-in are stubbed with SnackBar notifications.
/// Full OAuth integration is tracked for a future phase.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Screen that offers multiple account-creation pathways to the user.
///
/// Presents Apple Sign In, Google Sign In, and email/password registration as
/// options. Social auth buttons show a "coming soon" SnackBar while the email
/// path navigates to [RegisterScreen].
class AuthSelectionScreen extends StatelessWidget {
  /// Creates an [AuthSelectionScreen].
  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Zuralog'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.spaceLg),

            // ── Heading ─────────────────────────────────────────────────
            Text('Create your account', style: AppTextStyles.h2),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Connect your health journey with AI guidance.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: AppDimens.spaceXl),

            // ── Apple Sign In (stub) ──────────────────────────────────
            _AppleSignInButton(
              onPressed: () => _showComingSoon(context, 'Apple Sign In'),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // ── Google Sign In (stub) ─────────────────────────────────
            _GoogleSignInButton(
              onPressed: () => _showComingSoon(context, 'Google Sign In'),
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // ── "or" divider ─────────────────────────────────────────
            const _OrDivider(),

            const SizedBox(height: AppDimens.spaceMd),

            // ── Email registration ────────────────────────────────────
            PrimaryButton(
              label: 'Sign up with Email',
              onPressed: () => context.push(RouteNames.registerPath),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // ── Login link ───────────────────────────────────────────
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(RouteNames.loginPath),
                    child: const Text('Log in'),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Legal footer ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              child: Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a "coming soon" [SnackBar] for a given [featureName].
  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName coming soon')),
    );
  }
}

// ── Private Widgets ────────────────────────────────────────────────────────────

/// Full-width black pill button styled for Apple Sign In.
///
/// Uses Material [ElevatedButton] with a forced black background and white
/// foreground. The button is intentionally [onPressed]-able with a stub
/// callback — set to `null` to disable entirely.
class _AppleSignInButton extends StatelessWidget {
  /// Creates an [_AppleSignInButton].
  const _AppleSignInButton({required this.onPressed});

  /// Callback invoked when the button is tapped.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF000000),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, AppDimens.touchTargetMin),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.apple, size: AppDimens.iconMd),
          const SizedBox(width: AppDimens.spaceSm),
          Text('Continue with Apple', style: AppTextStyles.h3.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Full-width outlined pill button styled for Google Sign In.
///
/// Uses Material [OutlinedButton] with a light border. Shows a stylized "G"
/// text widget as a stand-in for the Google logo until a proper asset is
/// added in a future phase.
class _GoogleSignInButton extends StatelessWidget {
  /// Creates a [_GoogleSignInButton].
  const _GoogleSignInButton({required this.onPressed});

  /// Callback invoked when the button is tapped.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.borderLight),
        minimumSize: const Size(double.infinity, AppDimens.touchTargetMin),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google "G" placeholder — replace with SVG asset in Phase 2.x.
          Text(
            'G',
            style: AppTextStyles.h3.copyWith(
              color: const Color(0xFF4285F4), // Google blue
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            'Continue with Google',
            style: AppTextStyles.h3.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal divider row with an "or" label in the centre.
///
/// Uses two [Expanded] + [Divider] widgets flanking a padded [Text] to
/// produce the classic "───── or ─────" layout.
class _OrDivider extends StatelessWidget {
  /// Creates an [_OrDivider].
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'or',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
