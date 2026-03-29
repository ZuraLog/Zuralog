/// ZEmailTypoSuggestion — inline chip that detects common email domain typos
/// and offers a one-tap correction.
///
/// Usage:
/// ```dart
/// ZEmailTypoSuggestion(
///   email: _emailController.text,
///   onAccept: () => _emailController.text = detectEmailTypo(_emailController.text)!,
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Typo detection ────────────────────────────────────────────────────────────

/// Maps common misspelled email domains to their correct counterparts.
const Map<String, String> _domainCorrections = {
  // gmail
  'gnail.com': 'gmail.com',
  'gmial.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  // yahoo
  'yhaoo.com': 'yahoo.com',
  'yaho.com': 'yahoo.com',
  'yahooo.com': 'yahoo.com',
  // hotmail
  'hotmial.com': 'hotmail.com',
  'hotmal.com': 'hotmail.com',
  'hotmai.com': 'hotmail.com',
  // icloud
  'iclould.com': 'icloud.com',
  'icloud.co': 'icloud.com',
  // outlook
  'outloo.com': 'outlook.com',
  'outlok.com': 'outlook.com',
};

/// Returns a corrected email address if [email] contains a recognised domain
/// typo, or `null` if the email looks fine (or doesn't contain an @ yet).
///
/// Leading and trailing whitespace is trimmed before checking, so a stray
/// space or auto-capitalised character does not prevent detection.
String? detectEmailTypo(String email) {
  email = email.trim();
  final atIndex = email.indexOf('@');
  if (atIndex < 0) return null;

  final local = email.substring(0, atIndex);
  final domain = email.substring(atIndex + 1).toLowerCase();

  final corrected = _domainCorrections[domain];
  if (corrected == null) return null;

  return '$local@$corrected';
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Displays a dismissable suggestion chip when [email] contains a common
/// domain typo.
///
/// Animates in and out smoothly as the user edits the email field.
/// Calls [onAccept] when the user taps "Use this" — the parent is responsible
/// for updating the email field with the corrected value.
class ZEmailTypoSuggestion extends StatelessWidget {
  const ZEmailTypoSuggestion({
    super.key,
    required this.email,
    required this.onAccept,
  });

  /// The current value of the email field.
  final String email;

  /// Called when the user taps "Use this".
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final suggestion = detectEmailTypo(email);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: suggestion == null ? const SizedBox.shrink() : _Chip(
        suggestion: suggestion,
        onAccept: onAccept,
      ),
    );
  }
}

// ── Private chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.suggestion, required this.onAccept});

  final String suggestion;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final textSecondary = colors.textSecondary;
    final primaryColor = colors.primary;

    return GestureDetector(
      onTap: onAccept,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        // Enforce minimum touch target height per project standard.
        constraints: const BoxConstraints(minHeight: AppDimens.touchTargetMin),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppDimens.shapeXs),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_fix_high,
                size: 16,
                color: textSecondary,
              ),
              SizedBox(width: AppDimens.spaceSm),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySmall.copyWith(
                      color: textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Did you mean '),
                      TextSpan(
                        text: suggestion,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: '? '),
                      TextSpan(
                        text: 'Use this',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
