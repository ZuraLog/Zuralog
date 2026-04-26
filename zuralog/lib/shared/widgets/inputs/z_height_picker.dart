/// Zuralog Design System — Shared Height Picker.
///
/// Metric mode: single cm scroll wheel (120–220 cm).
/// Imperial mode: two side-by-side wheels — feet (3–7) and inches (0–11).
///
/// The Metric / Imperial toggle persists globally via [userPreferencesProvider].
/// [onSubmit] always receives the value converted to **centimetres** (double),
/// regardless of the unit currently displayed.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/scheduler.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';

/// Scroll-wheel height picker with a live Metric / Imperial toggle.
class ZHeightPicker extends ConsumerStatefulWidget {
  const ZHeightPicker({
    super.key,
    this.initialCm,
    required this.onSubmit,
    this.actionLabel = 'Continue',
    this.useSessionUnits = false,
  });

  /// Starting height in centimetres. Defaults to 170 cm when null.
  final double? initialCm;

  /// Called with the chosen height in **centimetres** when the user confirms.
  final ValueChanged<double> onSubmit;

  /// Label for the confirm button (e.g. 'Continue' in the wizard, 'Confirm'
  /// in onboarding).
  final String actionLabel;

  /// When true, reads/writes [sessionUnitsProvider] instead of
  /// [userPreferencesProvider]. Use this during onboarding before the
  /// persisted preferences have loaded from the server.
  final bool useSessionUnits;

  @override
  ConsumerState<ZHeightPicker> createState() => _ZHeightPickerState();
}

class _ZHeightPickerState extends ConsumerState<ZHeightPicker> {
  static const int _minCm = 120;
  static const int _maxCm = 220;
  static const int _defaultCm = 170;
  static const int _minFt = 3;
  static const int _maxFt = 7;
  static const double _wheelHeight = 140;
  static const double _itemExtent = 44;

  late UnitsSystem _units;
  late int _currentCm;
  late int _currentFt;
  late int _currentIn;
  late FixedExtentScrollController _cmScroll;
  late FixedExtentScrollController _ftScroll;
  late FixedExtentScrollController _inScroll;

  @override
  void initState() {
    super.initState();
    _units = widget.useSessionUnits
        ? ref.read(sessionUnitsProvider)
        : ref.read(unitsSystemProvider);
    _currentCm = (widget.initialCm?.round() ?? _defaultCm).clamp(_minCm, _maxCm);
    _deriveImperialFromCm();
    _cmScroll = FixedExtentScrollController(initialItem: _currentCm - _minCm);
    _ftScroll = FixedExtentScrollController(initialItem: _currentFt - _minFt);
    _inScroll = FixedExtentScrollController(initialItem: _currentIn);
  }

  @override
  void dispose() {
    _cmScroll.dispose();
    _ftScroll.dispose();
    _inScroll.dispose();
    super.dispose();
  }

  void _deriveImperialFromCm() {
    final totalIn = (_currentCm / 2.54).round();
    _currentFt = (totalIn ~/ 12).clamp(_minFt, _maxFt);
    _currentIn = (totalIn % 12).clamp(0, 11);
  }

  void _deriveCmFromImperial() {
    _currentCm =
        (_currentFt * 30.48 + _currentIn * 2.54).round().clamp(_minCm, _maxCm);
  }

  void _onToggle(UnitsSystem newUnits) {
    if (newUnits == _units) return;
    if (newUnits == UnitsSystem.imperial) {
      _deriveImperialFromCm();
    } else {
      _deriveCmFromImperial();
    }
    _units = newUnits;
    // Capture stale controllers, swap in new ones, then dispose stale after
    // the frame renders so the CupertinoPicker is never left holding a
    // disposed controller.
    final staleCm = _cmScroll;
    final staleFt = _ftScroll;
    final staleIn = _inScroll;
    _cmScroll = FixedExtentScrollController(initialItem: _currentCm - _minCm);
    _ftScroll = FixedExtentScrollController(initialItem: _currentFt - _minFt);
    _inScroll = FixedExtentScrollController(initialItem: _currentIn);
    setState(() {});
    SchedulerBinding.instance.addPostFrameCallback((_) {
      staleCm.dispose();
      staleFt.dispose();
      staleIn.dispose();
    });
    if (widget.useSessionUnits) {
      ref.read(sessionUnitsProvider.notifier).state = newUnits;
    } else {
      ref
          .read(userPreferencesProvider.notifier)
          .mutate((p) => p.copyWith(unitsSystem: newUnits));
    }
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    final double cm = _units == UnitsSystem.metric
        ? _currentCm.toDouble()
        : _currentFt * 30.48 + _currentIn * 2.54;
    widget.onSubmit(cm);
  }

  String get _displayValue => _units == UnitsSystem.imperial
      ? "$_currentFt' $_currentIn\""
      : '$_currentCm';

  String get _displayUnit => _units == UnitsSystem.metric ? 'cm' : '';

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isImperial = _units == UnitsSystem.imperial;

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
              _displayValue,
              style: AppTextStyles.displayLarge.copyWith(
                color: colors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                height: 1,
              ),
            ),
            if (_displayUnit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _displayUnit,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // ── Wheel(s) ───────────────────────────────────────────────────────
        SizedBox(
          height: _wheelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Guide lines spanning the full width.
              IgnorePointer(
                child: Container(
                  height: _itemExtent,
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
              isImperial
                  ? _buildImperialWheels(colors)
                  : _buildMetricWheel(colors),
            ],
          ),
        ),

        // ── Sub-labels for imperial wheels ─────────────────────────────────
        if (isImperial)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.spaceXxs),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'feet',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: colors.textSecondary),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'inches',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Confirm / Continue button ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceMd),
          child: ZButton(label: widget.actionLabel, onPressed: _submit),
        ),
      ],
    );
  }

  Widget _buildMetricWheel(AppColorsOf colors) {
    return CupertinoPicker(
      scrollController: _cmScroll,
      itemExtent: _itemExtent,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() => _currentCm = _minCm + i);
      },
      children: List.generate(
        _maxCm - _minCm + 1,
        (i) => Center(
          child: Text(
            '${_minCm + i}',
            style: AppTextStyles.titleLarge.copyWith(
              color: colors.textPrimary,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImperialWheels(AppColorsOf colors) {
    final itemStyle = AppTextStyles.titleLarge.copyWith(
      color: colors.textPrimary,
      letterSpacing: -0.3,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        // Feet wheel
        Expanded(
          child: CupertinoPicker(
            scrollController: _ftScroll,
            itemExtent: _itemExtent,
            selectionOverlay: const SizedBox.shrink(),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _currentFt = _minFt + i);
            },
            children: List.generate(
              _maxFt - _minFt + 1,
              (i) => Center(
                child: Text('${_minFt + i}', style: itemStyle),
              ),
            ),
          ),
        ),
        // Inches wheel
        Expanded(
          child: CupertinoPicker(
            scrollController: _inScroll,
            itemExtent: _itemExtent,
            selectionOverlay: const SizedBox.shrink(),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _currentIn = i);
            },
            children: List.generate(
              12,
              (i) => Center(child: Text('$i', style: itemStyle)),
            ),
          ),
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
