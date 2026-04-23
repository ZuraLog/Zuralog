/// Zuralog — Onboarding Chip Input.
///
/// Wrapping chips for a multi-select goal picker. Used on the
/// "one thing you want to change" step. Tapping a chip toggles it;
/// a sage "Done" pill at the bottom submits the chosen set.
///
/// Maximum picks is enforced so the user stays focused.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingChipInput extends StatefulWidget {
  const OnboardingChipInput({
    super.key,
    required this.options,
    required this.onSubmit,
    this.maxPicks = 2,
  });

  /// List of chip labels. The id is the label itself — keep it tight.
  final List<String> options;

  /// Called with the picked labels when the user presses Done.
  final ValueChanged<List<String>> onSubmit;

  /// Maximum number of chips the user can toggle on at once.
  final int maxPicks;

  @override
  State<OnboardingChipInput> createState() => _OnboardingChipInputState();
}

class _OnboardingChipInputState extends State<OnboardingChipInput> {
  final Set<String> _picked = {};

  static const double _chipHeight = 38;
  static const EdgeInsets _chipPadding = EdgeInsets.symmetric(horizontal: 16);

  void _toggle(String option) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.contains(option)) {
        _picked.remove(option);
      } else {
        if (_picked.length >= widget.maxPicks) {
          // Replace the oldest pick so the total never exceeds max.
          _picked.remove(_picked.first);
        }
        _picked.add(option);
      }
    });
  }

  void _submit() {
    if (_picked.isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.onSubmit(_picked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final canSubmit = _picked.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          alignment: WrapAlignment.center,
          children: widget.options.map((opt) {
            final on = _picked.contains(opt);
            return GestureDetector(
              onTap: () => _toggle(opt),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: _chipHeight,
                padding: _chipPadding,
                decoration: BoxDecoration(
                  color: on
                      ? colors.primary
                      : colors.surface,
                  borderRadius: BorderRadius.circular(_chipHeight / 2),
                ),
                child: Center(
                  child: Text(
                    opt,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: on
                          ? const Color(0xFF1A2E22)
                          : colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: canSubmit ? 1.0 : 0.4,
          child: GestureDetector(
            onTap: canSubmit ? _submit : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: canSubmit ? colors.primary : colors.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                canSubmit
                    ? _picked.length == 1
                        ? 'Continue'
                        : 'Continue with ${_picked.length}'
                    : 'Pick one or two',
                style: AppTextStyles.labelLarge.copyWith(
                  color: canSubmit
                      ? const Color(0xFF1A2E22)
                      : colors.textSecondary,
                  fontWeight: FontWeight.w600,
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
