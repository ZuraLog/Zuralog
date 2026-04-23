/// Zuralog — Onboarding Wheel Picker Input.
///
/// A Cupertino-style scrollable wheel paired with a sage confirm button.
/// Used for integer inputs (age, weight, height). The parent supplies
/// the unit label and the formatter for the centered display.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class OnboardingWheelInput extends StatefulWidget {
  const OnboardingWheelInput({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.initialValue,
    required this.unit,
    required this.onSubmit,
    this.format,
  });

  final int minValue;
  final int maxValue;
  final int initialValue;

  /// Short unit label (e.g. "years", "cm", "kg"). Shown next to the value.
  final String unit;

  final ValueChanged<int> onSubmit;

  /// Optional formatter for rendering the value (e.g. imperial conversion).
  final String Function(int value)? format;

  @override
  State<OnboardingWheelInput> createState() => _OnboardingWheelInputState();
}

class _OnboardingWheelInputState extends State<OnboardingWheelInput> {
  late int _current;
  late final FixedExtentScrollController _scroll;

  static const double _wheelHeight = 140;
  static const double _itemExtent = 44;
  static const double _centerValueSize = 36;

  @override
  void initState() {
    super.initState();
    _current = widget.initialValue.clamp(widget.minValue, widget.maxValue);
    _scroll = FixedExtentScrollController(
      initialItem: _current - widget.minValue,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _formatValue(int v) => widget.format?.call(v) ?? '$v';

  void _submit() {
    HapticFeedback.mediumImpact();
    widget.onSubmit(_current);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Centered big value + unit on top so the user always sees their
        // current choice clearly, even as the wheel spins.
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatValue(_current),
                style: AppTextStyles.displayLarge.copyWith(
                  color: colors.textPrimary,
                  fontSize: _centerValueSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.unit,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),

        // The wheel itself — Cupertino for the native scroll feel.
        SizedBox(
          height: _wheelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Faint sage guide lines marking the centered slot.
              IgnorePointer(
                child: Container(
                  height: _itemExtent,
                  margin: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceXl),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colors.primary.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: colors.primary.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              CupertinoPicker(
                scrollController: _scroll,
                itemExtent: _itemExtent,
                selectionOverlay: const SizedBox.shrink(),
                onSelectedItemChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _current = widget.minValue + i);
                },
                children: List.generate(
                  widget.maxValue - widget.minValue + 1,
                  (i) => Center(
                    child: Text(
                      _formatValue(widget.minValue + i),
                      style: AppTextStyles.titleLarge.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Confirm button.
        Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceMd),
          child: GestureDetector(
            onTap: _submit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
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
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Confirm',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: const Color(0xFF1A2E22),
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Color(0xFF1A2E22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
