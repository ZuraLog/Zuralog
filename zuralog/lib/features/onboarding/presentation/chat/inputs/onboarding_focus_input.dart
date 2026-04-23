/// Zuralog — Onboarding Focus Tile Input.
///
/// 2×2 grid of tappable category tiles. Single-select. Category-colored
/// icon on each tile. Selection emits [onSelect] and auto-advances —
/// no Continue button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingFocusOption {
  const OnboardingFocusOption({
    required this.id,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
}

class OnboardingFocusInput extends StatefulWidget {
  const OnboardingFocusInput({
    super.key,
    required this.options,
    required this.onSelect,
  });

  final List<OnboardingFocusOption> options;
  final ValueChanged<String> onSelect;

  @override
  State<OnboardingFocusInput> createState() => _OnboardingFocusInputState();
}

class _OnboardingFocusInputState extends State<OnboardingFocusInput> {
  String? _picked;

  static const double _tileRadius = 18;
  static const double _iconSize = 28;
  static const double _iconContainerSize = 44;
  static const double _gridSpacing = AppDimens.spaceSm;
  static const Duration _tapDelay = Duration(milliseconds: 200);

  void _pick(String id) {
    HapticFeedback.mediumImpact();
    setState(() => _picked = id);
    Future.delayed(_tapDelay, () {
      if (mounted) widget.onSelect(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: _gridSpacing,
        crossAxisSpacing: _gridSpacing,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, i) {
        final opt = widget.options[i];
        final isPicked = opt.id == _picked;
        final isDimmed = _picked != null && !isPicked;
        return GestureDetector(
          onTap: () => _pick(opt.id),
          behavior: HitTestBehavior.opaque,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isDimmed ? 0.4 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(_tileRadius),
                border: Border.all(
                  color: isPicked
                      ? opt.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isPicked
                    ? [
                        BoxShadow(
                          color: opt.accent.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: _iconContainerSize,
                    height: _iconContainerSize,
                    decoration: BoxDecoration(
                      color: opt.accent.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppDimens.spaceMd - 4),
                    ),
                    child: Icon(
                      opt.icon,
                      size: _iconSize,
                      color: opt.accent,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                          letterSpacing: -0.05,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
