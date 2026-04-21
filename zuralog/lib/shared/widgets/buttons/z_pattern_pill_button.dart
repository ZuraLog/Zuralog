/// Reusable pill button with an animated brand pattern overlay.
///
/// Two visual modes:
///
/// 1. **Sage primary (default)** — Sage fill + Deep-Forest text, matches
///    the bottom-nav log pill. Used for top-level "log new entry" style
///    actions where the button is the hero action on its screen.
///
/// 2. **Tinted accent** — when [accent] is supplied, the pill renders
///    as a translucent chip in that color (e.g. the category color of
///    the surrounding content). Softer, more editorial — designed to
///    sit at the end of a detail-page scroll without shouting.
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
    this.accent,
    this.patternVariant,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double height;

  /// Optional color that tints the pill. When provided, the button
  /// renders as a translucent accent-tinted pill; when null, the
  /// classic Sage primary recipe is used.
  final Color? accent;

  /// Pattern overlay variant. Defaults to [ZPatternVariant.sage] for
  /// the Sage primary style. Pass a category-matching variant (e.g.
  /// [ZPatternVariant.periwinkle] for sleep) alongside [accent] for a
  /// fully-branded accent pill.
  final ZPatternVariant? patternVariant;

  @override
  Widget build(BuildContext context) {
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
          child: accent == null
              ? _buildSagePrimary(context, height: height)
              : _buildAccentTinted(context, accent!, height: height),
        ),
      ),
    );
  }

  Widget _buildSagePrimary(
    BuildContext context, {
    required double height,
  }) {
    final colors = AppColorsOf(context);
    final fill = colors.primary;
    final foreground = colors.isDark
        ? AppColors.deepForest
        : colors.textOnSage;
    final variant = patternVariant ?? ZPatternVariant.sage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Material(
        color: fill,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ZPatternOverlay(
                variant: variant,
                opacity: 0.22,
                blendMode: BlendMode.multiply,
                animate: true,
              ),
            ),
            _PillContent(
              icon: icon,
              label: label,
              foreground: foreground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentTinted(
    BuildContext context,
    Color accent, {
    required double height,
  }) {
    final variant = patternVariant ?? ZPatternVariant.sage;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: ZPatternOverlay(
                  variant: variant,
                  opacity: 0.10,
                  blendMode: BlendMode.screen,
                  animate: true,
                ),
              ),
              _PillContent(
                icon: icon,
                label: label,
                foreground: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillContent extends StatelessWidget {
  const _PillContent({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
