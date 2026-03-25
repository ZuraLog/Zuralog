/// Zuralog Design System — Password Strength Bar Widget.
///
/// Displays a colour-coded bar and label below a password input field,
/// giving the user immediate feedback on how strong their password is.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

/// Password strength bar for the change-password sheet.
///
/// Takes [password] and renders a coloured strength bar with a label.
///
/// Strength levels:
/// - Empty string → no bar shown ([SizedBox.shrink])
/// - Length 1–5 → Weak (red, 1/3 width)
/// - Length 6–7 → Fair (orange, 2/3 width)
/// - Length 8+ with mixed letters & digits → Strong (green, full width)
/// - Length 8+ but only letters OR only digits → Fair (orange, 2/3 width)
///
/// Example:
/// ```dart
/// ZPasswordStrengthBar(password: _newPasswordController.text)
/// ```
class ZPasswordStrengthBar extends StatelessWidget {
  const ZPasswordStrengthBar({super.key, required this.password});

  /// The password string to evaluate.
  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final strength = _strength(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: constraints.maxWidth * strength.fraction,
                      color: strength.color,
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strength.label,
          style: TextStyle(
            fontSize: 11,
            color: strength.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  _Strength _strength(String pw) {
    if (pw.length < 6) return _Strength(AppColors.statusError, 1 / 3, 'Weak');
    final hasLetter = pw.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = pw.contains(RegExp(r'\d'));
    if (pw.length >= 8 && hasLetter && hasDigit) {
      return _Strength(AppColors.statusConnected, 1.0, 'Strong');
    }
    return _Strength(AppColors.statusConnecting, 2 / 3, 'Fair');
  }
}

class _Strength {
  const _Strength(this.color, this.fraction, this.label);

  final Color color;
  final double fraction;
  final String label;
}
