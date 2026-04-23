/// Zuralog — Onboarding Pill Input.
///
/// A row (or wrap) of tappable pill options. Single-select — tapping a
/// pill emits [onSelect] which the parent uses to advance the
/// conversation. No Continue button.
///
/// Used for sex (2-3 options) and coach tone (4 options, where each
/// pill also shows a live sample quote in a preview strip).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingPillOption {
  const OnboardingPillOption({
    required this.id,
    required this.label,
    this.helper,
  });

  final String id;
  final String label;

  /// Optional short text shown under the selected pill (used by tone input
  /// to render the sample coach quote for the currently-hovered option).
  final String? helper;
}

class OnboardingPillInput extends StatefulWidget {
  const OnboardingPillInput({
    super.key,
    required this.options,
    required this.onSelect,
    this.selectedId,
    this.layout = PillLayout.wrap,
  });

  final List<OnboardingPillOption> options;
  final ValueChanged<String> onSelect;

  /// Optional pre-selection (used when the helper-preview mode is active).
  final String? selectedId;

  /// Row = equal-width tiles across the row. Wrap = chips that wrap.
  final PillLayout layout;

  @override
  State<OnboardingPillInput> createState() => _OnboardingPillInputState();
}

enum PillLayout { row, wrap }

class _OnboardingPillInputState extends State<OnboardingPillInput> {
  String? _hovered;

  static const double _pillHeight = 46;
  static const EdgeInsets _pillPadding =
      EdgeInsets.symmetric(horizontal: 18);
  static const Duration _tapAnimDuration = Duration(milliseconds: 180);

  void _handleTap(String id) {
    HapticFeedback.mediumImpact();
    setState(() => _hovered = id);
    // Give the selection animation a beat to land, then emit.
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) widget.onSelect(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final active = widget.selectedId ?? _hovered;

    Widget buildPill(OnboardingPillOption opt) {
      final isActive = opt.id == active;
      return AnimatedContainer(
        duration: _tapAnimDuration,
        curve: Curves.easeOut,
        height: _pillHeight,
        padding: _pillPadding,
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary
              : colors.surface,
          borderRadius: BorderRadius.circular(_pillHeight / 2),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            opt.label,
            style: AppTextStyles.labelLarge.copyWith(
              color: isActive
                  ? const Color(0xFF1A2E22)
                  : colors.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      );
    }

    switch (widget.layout) {
      case PillLayout.row:
        return Row(
          children: [
            for (var i = 0; i < widget.options.length; i++) ...[
              if (i > 0) const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleTap(widget.options[i].id),
                  behavior: HitTestBehavior.opaque,
                  child: buildPill(widget.options[i]),
                ),
              ),
            ],
          ],
        );
      case PillLayout.wrap:
        return Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: widget.options.map((opt) {
            return GestureDetector(
              onTap: () => _handleTap(opt.id),
              behavior: HitTestBehavior.opaque,
              child: buildPill(opt),
            );
          }).toList(),
        );
    }
  }
}
