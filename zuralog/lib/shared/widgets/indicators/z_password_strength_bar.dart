/// Zuralog Design System — Password Strength Bar Widget.
///
/// Displays a 4-segment animated bar and label below a password input field,
/// giving the user immediate feedback on how strong their password is.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Password strength bar for auth screens.
///
/// Takes [password] and renders a 4-segment animated strength bar with a
/// label and hint text below it.
///
/// Strength levels:
/// - Empty string → nothing shown ([SizedBox.shrink])
/// - Weak: < 8 chars → 1 segment lit, red
/// - Fair: 8+ chars but letters-only OR digits-only → 2 segments lit, orange
/// - Good: 8+ chars with letters + digits → 3 segments lit, yellow-orange
/// - Strong: 8+ chars with letters + digits + symbol → 4 segments lit, green
///
/// Example:
/// ```dart
/// ZPasswordStrengthBar(password: _passwordController.text)
/// ```
class ZPasswordStrengthBar extends StatelessWidget {
  const ZPasswordStrengthBar({super.key, required this.password});

  /// The password string to evaluate.
  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final colors = AppColorsOf(context);
    final level = _strengthLevel(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < level.activeSegments
                        ? level.color
                        : colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              level.label,
              style: AppTextStyles.labelSmall.copyWith(color: level.color),
            ),
            if (level.hint.isNotEmpty)
              Text(
                level.hint,
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  _StrengthLevel _strengthLevel(String pw) {
    if (pw.length < 8) {
      return const _StrengthLevel(
        activeSegments: 1,
        color: AppColors.statusError,
        label: 'Weak',
        hint: 'Use 8+ characters',
      );
    }

    final hasLetter = pw.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = pw.contains(RegExp(r'\d'));
    final hasSymbol = pw.contains(RegExp(r'[^A-Za-z\d]'));

    if (hasLetter && hasDigit && hasSymbol) {
      return const _StrengthLevel(
        activeSegments: 4,
        color: AppColors.statusConnected,
        label: 'Strong',
        hint: '',
      );
    }

    if (hasLetter && hasDigit) {
      return const _StrengthLevel(
        activeSegments: 3,
        color: Color(0xFFFFB347),
        label: 'Good',
        hint: 'Add a symbol to strengthen it',
      );
    }

    return const _StrengthLevel(
      activeSegments: 2,
      color: AppColors.statusConnecting,
      label: 'Fair',
      hint: 'Add numbers to strengthen',
    );
  }
}

class _StrengthLevel {
  const _StrengthLevel({
    required this.activeSegments,
    required this.color,
    required this.label,
    required this.hint,
  });

  final int activeSegments;
  final Color color;
  final String label;
  final String hint;
}
