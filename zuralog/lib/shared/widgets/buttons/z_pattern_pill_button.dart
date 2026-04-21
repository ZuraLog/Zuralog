/// Reusable sage-filled pill with an animated brand pattern overlay.
///
/// Matches the recipe used by the bottom-nav log pill in
/// [app_shell.dart] so the texture language is consistent across
/// primary actions. In dark mode the fill is Sage and the icon / text
/// are Deep Forest (#344E41). In light mode the fill is Deep Forest
/// (primary) and the icon / text are Warm Cream (textOnSage).
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class ZPatternPillButton extends StatelessWidget {
  const ZPatternPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.height = 56,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final fill = colors.primary;
    final foreground = colors.isDark
        ? AppColors.deepForest
        : colors.textOnSage;

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: ZuralogSpringButton(
        onTap: onPressed,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Material(
              color: fill,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: ZPatternOverlay(
                      variant: ZPatternVariant.sage,
                      opacity: 0.45,
                      blendMode: BlendMode.multiply,
                      animate: true,
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: foreground),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
