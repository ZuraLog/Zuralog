/// Zuralog — Onboarding Connect-Health-Data Input.
///
/// Single primary Sage button labeled per platform, with a quiet
/// "Skip for now" text link below. No Continue, no chrome.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingConnectInput extends StatelessWidget {
  const OnboardingConnectInput({
    super.key,
    required this.onConnect,
    required this.onSkip,
  });

  final VoidCallback onConnect;
  final VoidCallback onSkip;

  static const double _buttonHeight = 52;

  String get _platformLabel =>
      Platform.isAndroid ? 'Connect Health Connect' : 'Connect Apple Health';

  void _handleConnect() {
    HapticFeedback.mediumImpact();
    onConnect();
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _handleConnect,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: _buttonHeight,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(_buttonHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _platformLabel,
              style: AppTextStyles.labelLarge.copyWith(
                color: const Color(0xFF1A2E22),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Center(
          child: GestureDetector(
            onTap: _handleSkip,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceSm,
                horizontal: AppDimens.spaceMd,
              ),
              child: Text(
                'Skip for now',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.primary.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
