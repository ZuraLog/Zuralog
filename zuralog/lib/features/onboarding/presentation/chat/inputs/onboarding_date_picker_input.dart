/// Zuralog — Onboarding Birthday Date Picker Input.
///
/// Inline CupertinoDatePicker (month/day/year) styled to match the
/// OnboardingWheelInput. Used for the [ChatStep.birthday] step.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class OnboardingDatePickerInput extends StatefulWidget {
  const OnboardingDatePickerInput({
    super.key,
    required this.onSubmit,
    this.initialDate,
  });

  final ValueChanged<DateTime> onSubmit;

  /// Pre-selected date. Defaults to 30 years before today if null.
  final DateTime? initialDate;

  @override
  State<OnboardingDatePickerInput> createState() =>
      _OnboardingDatePickerInputState();
}

class _OnboardingDatePickerInputState
    extends State<OnboardingDatePickerInput> {
  static final DateTime _minDate = DateTime(1920);
  static final DateTime _maxDate = DateTime(
    DateTime.now().year - 13,
    DateTime.now().month,
    DateTime.now().day,
  );

  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate ??
        DateTime(DateTime.now().year - 30, 1, 1);
    if (_selected.isBefore(_minDate)) _selected = _minDate;
    if (_selected.isAfter(_maxDate)) _selected = _maxDate;
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    widget.onSubmit(_selected);
  }

  String _formattedDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large date display — mirrors the big value row in OnboardingWheelInput.
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: Text(
            _formattedDate(_selected),
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              height: 1,
            ),
          ),
        ),

        // CupertinoDatePicker in date-only mode.
        //
        // Wrapped in a CupertinoTheme with an explicit dateTimePickerTextStyle
        // so all three wheel columns (months/days/years) share the same font,
        // size, and colour. Without this override the picker inherits odd
        // styling from the surrounding Material theme (serif italic on months,
        // sans-serif on numbers).
        SizedBox(
          height: 180,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Brightness.dark,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.normal,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selected,
              minimumDate: _minDate,
              maximumDate: _maxDate,
              onDateTimeChanged: (date) {
                HapticFeedback.selectionClick();
                setState(() => _selected = date);
              },
            ),
          ),
        ),

        // Confirm button — identical to OnboardingWheelInput's button.
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
