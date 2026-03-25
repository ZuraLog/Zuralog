/// Wraps [child] in a ShaderMask that applies a sage gradient approximating
/// the brand topographic pattern.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

class PatternFill extends StatelessWidget {
  const PatternFill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            AppColors.progressSage.withValues(alpha: 0.85),
            AppColors.progressSage,
            AppColors.progressSage.withValues(alpha: 0.70),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}
