/// Zuralog — Onboarding Unit-Aware Wheel Inputs.
///
/// Provides [OnboardingHeightInput] and [OnboardingWeightInput], each with a
/// unit toggle that persists the choice globally via [userPreferencesProvider].
/// Both widgets always submit metric values (cm or kg) regardless of the
/// display unit chosen by the user.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_wheel_input.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── Height Input ──────────────────────────────────────────────────────────────

/// Height picker that supports both metric (cm) and imperial (ft/in).
///
/// The wheel always stores values in centimetres (120–220 cm, initial 170 cm).
/// When imperial mode is active the [format] callback converts cm to a
/// `ft'in"` string for display. [onSubmit] always receives the raw cm value.
class OnboardingHeightInput extends ConsumerStatefulWidget {
  const OnboardingHeightInput({
    super.key,
    required this.onSubmit,
  });

  /// Called with the selected height in **centimetres** regardless of display unit.
  final ValueChanged<int> onSubmit;

  @override
  ConsumerState<OnboardingHeightInput> createState() =>
      _OnboardingHeightInputState();
}

class _OnboardingHeightInputState extends ConsumerState<OnboardingHeightInput> {
  static const int _initialCm = 170;
  static const int _minCm = 120;
  static const int _maxCm = 220;

  late UnitsSystem _units;

  @override
  void initState() {
    super.initState();
    _units = ref.read(unitsSystemProvider);
  }

  void _onToggle(UnitsSystem newUnits) {
    setState(() => _units = newUnits);
    ref.read(userPreferencesProvider.notifier).mutate(
          (p) => p.copyWith(unitsSystem: newUnits),
        );
  }

  String _formatHeight(int cm) {
    if (_units == UnitsSystem.imperial) {
      final totalInches = (cm / 2.54).round();
      final ft = totalInches ~/ 12;
      final inches = totalInches % 12;
      return "$ft'$inches\"";
    }
    return '$cm';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UnitToggle(selected: _units, onChanged: _onToggle),
        const SizedBox(height: AppDimens.spaceSm),
        OnboardingWheelInput(
          key: ValueKey(_units),
          minValue: _minCm,
          maxValue: _maxCm,
          initialValue: _initialCm,
          unit: _units == UnitsSystem.imperial ? '' : 'cm',
          format: _formatHeight,
          onSubmit: widget.onSubmit,
        ),
      ],
    );
  }
}

// ── Weight Input ──────────────────────────────────────────────────────────────

/// Weight picker that supports both metric (kg) and imperial (lbs).
///
/// In metric mode the wheel ranges 30–200 kg (initial 70 kg).
/// In imperial mode the wheel ranges 66–440 lbs; the initial position is
/// derived from the last metric value so switching units feels seamless.
/// [onSubmit] always receives the weight converted back to **kilograms**.
class OnboardingWeightInput extends ConsumerStatefulWidget {
  const OnboardingWeightInput({
    super.key,
    required this.onSubmit,
  });

  /// Called with the selected weight in **kilograms** regardless of display unit.
  final ValueChanged<int> onSubmit;

  @override
  ConsumerState<OnboardingWeightInput> createState() =>
      _OnboardingWeightInputState();
}

class _OnboardingWeightInputState
    extends ConsumerState<OnboardingWeightInput> {
  static const int _initialKg = 70;
  static const int _minKg = 30;
  static const int _maxKg = 200;
  static const int _minLbs = 66;
  static const int _maxLbs = 440;

  late UnitsSystem _units;

  /// Tracks the current metric value so we can reconvert when switching units.
  int _currentKg = _initialKg;

  @override
  void initState() {
    super.initState();
    _units = ref.read(unitsSystemProvider);
  }

  void _onToggle(UnitsSystem newUnits) {
    setState(() => _units = newUnits);
    ref.read(userPreferencesProvider.notifier).mutate(
          (p) => p.copyWith(unitsSystem: newUnits),
        );
  }

  int get _initialLbs => (_currentKg * 2.20462).round();

  void _handleSubmit(int wheelValue) {
    final kg = _units == UnitsSystem.imperial
        ? (wheelValue / 2.20462).round()
        : wheelValue;
    _currentKg = kg;
    widget.onSubmit(kg);
  }

  void _onWheelChanged(int wheelValue) {
    // Keep _currentKg in sync so toggling units re-anchors correctly.
    if (_units == UnitsSystem.metric) {
      _currentKg = wheelValue;
    } else {
      _currentKg = (wheelValue / 2.20462).round();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImperial = _units == UnitsSystem.imperial;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UnitToggle(selected: _units, onChanged: _onToggle),
        const SizedBox(height: AppDimens.spaceSm),
        _WeightWheel(
          key: ValueKey(_units),
          isImperial: isImperial,
          initialKg: _currentKg,
          initialLbs: _initialLbs,
          minKg: _minKg,
          maxKg: _maxKg,
          minLbs: _minLbs,
          maxLbs: _maxLbs,
          onChanged: _onWheelChanged,
          onSubmit: _handleSubmit,
        ),
      ],
    );
  }
}

/// Internal stateful wrapper for the weight wheel so that [ValueKey] forces a
/// full rebuild (and thus a fresh [FixedExtentScrollController]) on unit change.
class _WeightWheel extends StatelessWidget {
  const _WeightWheel({
    super.key,
    required this.isImperial,
    required this.initialKg,
    required this.initialLbs,
    required this.minKg,
    required this.maxKg,
    required this.minLbs,
    required this.maxLbs,
    required this.onChanged,
    required this.onSubmit,
  });

  final bool isImperial;
  final int initialKg;
  final int initialLbs;
  final int minKg;
  final int maxKg;
  final int minLbs;
  final int maxLbs;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onSubmit;

  @override
  Widget build(BuildContext context) {
    if (isImperial) {
      return OnboardingWheelInput(
        minValue: minLbs,
        maxValue: maxLbs,
        initialValue: initialLbs.clamp(minLbs, maxLbs),
        unit: 'lbs',
        onSubmit: onSubmit,
      );
    }
    return OnboardingWheelInput(
      minValue: minKg,
      maxValue: maxKg,
      initialValue: initialKg.clamp(minKg, maxKg),
      unit: 'kg',
      onSubmit: onSubmit,
    );
  }
}

// ── Unit Toggle ───────────────────────────────────────────────────────────────

/// Pill-style segmented control for switching between Metric and Imperial.
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.selected,
    required this.onChanged,
  });

  final UnitsSystem selected;
  final ValueChanged<UnitsSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeXs),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            label: 'Metric',
            active: selected == UnitsSystem.metric,
            onTap: () => onChanged(UnitsSystem.metric),
          ),
          _Pill(
            label: 'Imperial',
            active: selected == UnitsSystem.imperial,
            onTap: () => onChanged(UnitsSystem.imperial),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: active ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.shapeXs - 2),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: active ? const Color(0xFF1A2E22) : colors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
