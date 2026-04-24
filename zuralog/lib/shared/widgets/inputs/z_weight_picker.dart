/// Zuralog Design System — Shared Weight Picker.
///
/// Single scroll wheel that switches between kg and lbs.
///
/// The Metric / Imperial toggle persists globally via [userPreferencesProvider].
/// [onSubmit] always receives the value converted to **kilograms** (double),
/// regardless of the unit currently displayed.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';

/// Scroll-wheel weight picker with a live Metric / Imperial toggle.
class ZWeightPicker extends ConsumerStatefulWidget {
  const ZWeightPicker({
    super.key,
    this.initialKg,
    required this.onSubmit,
    this.actionLabel = 'Continue',
  });

  /// Starting weight in kilograms. Defaults to 70 kg when null.
  final double? initialKg;

  /// Called with the chosen weight in **kilograms** when the user confirms.
  final ValueChanged<double> onSubmit;

  /// Label for the confirm button.
  final String actionLabel;

  @override
  ConsumerState<ZWeightPicker> createState() => _ZWeightPickerState();
}

class _ZWeightPickerState extends ConsumerState<ZWeightPicker> {
  static const int _minKg = 30;
  static const int _maxKg = 200;
  static const int _defaultKg = 70;
  static const int _minLbs = 66;
  static const int _maxLbs = 440;
  static const double _wheelHeight = 140;
  static const double _itemExtent = 44;

  late UnitsSystem _units;
  late int _currentKg;
  late int _currentLbs;
  late FixedExtentScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _units = ref.read(unitsSystemProvider);
    _currentKg = (widget.initialKg?.round() ?? _defaultKg).clamp(_minKg, _maxKg);
    _currentLbs = (_currentKg * 2.20462).round().clamp(_minLbs, _maxLbs);
    _scroll = _makeController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  FixedExtentScrollController _makeController() {
    if (_units == UnitsSystem.metric) {
      return FixedExtentScrollController(initialItem: _currentKg - _minKg);
    }
    return FixedExtentScrollController(
      initialItem: _currentLbs.clamp(_minLbs, _maxLbs) - _minLbs,
    );
  }

  void _onToggle(UnitsSystem newUnits) {
    if (newUnits == _units) return;
    setState(() {
      if (newUnits == UnitsSystem.imperial) {
        _currentLbs = (_currentKg * 2.20462).round().clamp(_minLbs, _maxLbs);
      } else {
        _currentKg = (_currentLbs / 2.20462).round().clamp(_minKg, _maxKg);
      }
      _units = newUnits;
      _scroll.dispose();
      _scroll = _makeController();
    });
    ref
        .read(userPreferencesProvider.notifier)
        .mutate((p) => p.copyWith(unitsSystem: newUnits));
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    final double kg = _units == UnitsSystem.metric
        ? _currentKg.toDouble()
        : _currentLbs / 2.20462;
    widget.onSubmit(kg);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isImperial = _units == UnitsSystem.imperial;
    final displayValue = isImperial ? '$_currentLbs' : '$_currentKg';
    final displayUnit = isImperial ? 'lbs' : 'kg';
    final minVal = isImperial ? _minLbs : _minKg;
    final maxVal = isImperial ? _maxLbs : _maxKg;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Unit toggle ────────────────────────────────────────────────────
        _UnitToggle(selected: _units, onChanged: _onToggle),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Big display ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              displayValue,
              style: AppTextStyles.displayLarge.copyWith(
                color: colors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                displayUnit,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // ── Wheel ─────────────────────────────────────────────────────────
        SizedBox(
          height: _wheelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Container(
                  height: _itemExtent,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceXl,
                  ),
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
                  setState(() {
                    if (isImperial) {
                      _currentLbs = _minLbs + i;
                    } else {
                      _currentKg = _minKg + i;
                    }
                  });
                },
                children: List.generate(
                  maxVal - minVal + 1,
                  (i) => Center(
                    child: Text(
                      '${minVal + i}',
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

        // ── Confirm / Continue button ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceMd),
          child: ZButton(label: widget.actionLabel, onPressed: _submit),
        ),
      ],
    );
  }
}

// ── _UnitToggle ───────────────────────────────────────────────────────────────

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.selected, required this.onChanged});

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
  const _Pill({required this.label, required this.active, required this.onTap});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
