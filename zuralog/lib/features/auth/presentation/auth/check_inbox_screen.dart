/// Zuralog Edge Agent — Check Inbox Screen.
///
/// Shown after email registration or password-reset request.
/// Displays the destination email, a helpful tip about spam folders,
/// and a resend button with a 60-second cooldown countdown.
///
/// Query parameters (read from GoRouter):
///   - `email`   — the address the email was sent to.
///   - `context` — `'verification'` (default) or `'reset'`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// "Check your inbox" confirmation screen.
///
/// Used for both email-verification and password-reset flows.
/// The [inboxContext] query param ('verification' | 'reset') controls
/// the subtitle copy and whether the resend button triggers a backend call.
class CheckInboxScreen extends ConsumerStatefulWidget {
  /// Creates a [CheckInboxScreen].
  const CheckInboxScreen({super.key});

  @override
  ConsumerState<CheckInboxScreen> createState() => _CheckInboxScreenState();
}

class _CheckInboxScreenState extends ConsumerState<CheckInboxScreen> {
  // ── Route params (populated in didChangeDependencies) ─────────────────────
  String _email = '';
  String _inboxContext = 'verification';

  // ── Resend countdown state ────────────────────────────────────────────────
  bool _canResend = false;
  int _countdown = 60;
  Timer? _timer;
  bool _isResending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read query params once — GoRouterState is available after first build.
    final uri = GoRouterState.of(context).uri;
    _email = uri.queryParameters['email'] ?? '';
    _inboxContext = uri.queryParameters['context'] ?? 'verification';
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Countdown ─────────────────────────────────────────────────────────────

  void _startCountdown() {
    _timer?.cancel(); // Cancel any existing timer before starting a new one
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _canResend = true;
            _countdown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() => _countdown--);
        }
      }
    });
  }

  // ── Resend handler ────────────────────────────────────────────────────────

  Future<void> _handleResend() async {
    if (!_canResend || _isResending) return;
    setState(() => _isResending = true);

    try {
      if (_inboxContext == 'verification') {
        await ref.read(authRepositoryProvider).resendVerification(_email);
      } else if (_inboxContext == 'reset') {
        await ref.read(authRepositoryProvider).resetPassword(_email);
      }
      if (!mounted) return;

      // Restart the countdown.
      setState(() {
        _canResend = false;
        _countdown = 60;
        _isResending = false;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      ZToast.error(context, 'Failed to resend. Please try again.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Re-read params on every build to stay reactive to hot-reload / deep links.
    final uri = GoRouterState.of(context).uri;
    final email = uri.queryParameters['email'] ?? _email;
    final inboxContext = uri.queryParameters['context'] ?? _inboxContext;

    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar — no back button on this screen.
          const ZAuthTopBar(showBack: false),

          // Scrollable content.
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Mail icon tile ──────────────────────────────────────
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          borderRadius:
                              BorderRadius.circular(AppDimens.shapeXl),
                        ),
                        child: Icon(
                          Icons.mail_outline_rounded,
                          size: 36,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),

                    // ── Headline ────────────────────────────────────────────
                    Text(
                      'Check your inbox.',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimens.spaceXs),

                    // ── Subtitle (context-aware) ────────────────────────────
                    Text(
                      inboxContext == 'reset'
                          ? 'We sent a password reset link to'
                          : 'We sent a verification link to',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimens.spaceXs),

                    // ── Email address ───────────────────────────────────────
                    Text(
                      email,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimens.spaceLg),

                    // ── Info card ───────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        borderRadius:
                            BorderRadius.circular(AppDimens.shapeSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppDimens.spaceSm),
                          Expanded(
                            child: Text(
                              "Check your spam folder if you don't see it within a minute. The link expires in 24 hours.",
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),

                    // ── Resend button ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            _canResend && !_isResending ? _handleResend : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _canResend
                                ? colors.textSecondary
                                    .withValues(alpha: 0.4)
                                : colors.textSecondary
                                    .withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.shapePill,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.spaceMd,
                          ),
                        ),
                        child: _isResending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _canResend
                                    ? 'Resend email'
                                    : 'Resend email (${_countdown}s)',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: _canResend
                                      ? colors.textSecondary
                                      : colors.textSecondary
                                          .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),

                    // ── "Wrong email? Go back" link ─────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Wrong email? ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(RouteNames.loginPath);
                              }
                            },
                            child: Text(
                              'Go back',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
