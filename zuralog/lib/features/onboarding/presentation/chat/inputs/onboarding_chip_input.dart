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
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Internal sage-filled pill button with the brand pattern overlay.
/// Local to this file — OnboardingIntegrationsInput and the finale CTA
/// each have their own tailored variants.
class _SagePatternButton extends StatelessWidget {
  const _SagePatternButton({
    required this.height,
    required this.enabled,
    required this.label,
  });

  final double height;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: enabled ? colors.primary : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Stack(
        children: [
          if (enabled)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: const IgnorePointer(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.sage,
                    opacity: 0.55,
                    animate: true,
                  ),
                ),
              ),
            ),
          Center(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: enabled
                    ? const Color(0xFF1A2E22)
                    : colors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                decoration: BoxDecoration(
                  color: on ? colors.primary : colors.surface,
                  borderRadius: BorderRadius.circular(_chipHeight / 2),
                ),
                // Stack so the sage chip gets the topographic pattern
                // overlaid per the brand bible's "Sage fill + pattern"
                // rule. Inactive chips stay plain Surface.
                child: Stack(
                  children: [
                    if (on)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_chipHeight / 2),
                          child: const IgnorePointer(
                            child: ZPatternOverlay(
                              variant: ZPatternVariant.sage,
                              opacity: 0.55,
                              animate: true,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: _chipPadding,
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
                  ],
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
            child: _SagePatternButton(
              height: 48,
              enabled: canSubmit,
              label: canSubmit
                  ? _picked.length == 1
                      ? 'Continue'
                      : 'Continue with ${_picked.length}'
                  : 'Pick one or two',
            ),
          ),
        ),
      ],
    );
  }
}
