/// Zuralog — Water Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Water tile.
/// Allows quick logging of a water intake amount via vessel presets or
/// a custom numeric input.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/charts/z_mini_ring.dart';
import 'package:zuralog/shared/widgets/inputs/app_text_field.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── Vessel presets ─────────────────────────────────────────────────────────────

/// Represents a water vessel preset with a display label and amount in ml.
class _VesselPreset {
  const _VesselPreset({required this.key, required this.label, required this.ml});

  final String key;
  final String label;
  final double? ml; // null for 'custom'
}

const _kVessels = [
  _VesselPreset(key: 'small_cup', label: 'Small cup', ml: 150),
  _VesselPreset(key: 'glass', label: 'Glass', ml: 250),
  _VesselPreset(key: 'bottle', label: 'Bottle', ml: 500),
  _VesselPreset(key: 'large', label: 'Large bottle', ml: 750),
  _VesselPreset(key: 'custom', label: 'Custom', ml: null),
];

const double _kOzToMl = 29.5735;

// oz display amounts per vessel (rounded to nearest whole oz)
const _kVesselOz = {
  'small_cup': 5.0,
  'glass': 8.0,
  'bottle': 17.0,
  'large': 25.0,
};

/// Icon for each vessel key. All icons come from Flutter's built-in Material Icons.
const _kVesselIcons = <String, IconData>{
  'small_cup': Icons.local_cafe,
  'glass': Icons.local_bar,
  'bottle': Icons.sports_bar,
  'large': Icons.water_drop,
  'custom': Icons.edit,
};

const double _kRingSize = 56.0;

// ── ZWaterLogPanel ─────────────────────────────────────────────────────────────

/// Inline log panel for water intake.
///
/// Shows vessel presets as a single row of compact pill buttons that wrap as
/// needed (Small cup, Glass, Bottle, Large bottle, Custom). A `ZMiniRing`
/// goal-progress header sits above the pills. Selecting a non-custom pill sets
/// the amount automatically; selecting Custom reveals a text field for numeric
/// input.
///
/// The [onSave] callback receives the amount in ml as a [double].
/// The [onBack] callback is provided for the parent sheet header's back button.
class ZWaterLogPanel extends ConsumerStatefulWidget {
  const ZWaterLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user taps "Add Water". Receives the amount in ml.
  final Future<void> Function(double amountMl) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZWaterLogPanel> createState() => _ZWaterLogPanelState();
}

class _ZWaterLogPanelState extends ConsumerState<ZWaterLogPanel> {
  String? _selectedVesselKey;
  double _amountMl = 0;
  final TextEditingController _customController = TextEditingController();

  bool get _isCustomSelected => _selectedVesselKey == 'custom';
  bool get _canSave {
    if (_selectedVesselKey == null) return false;
    if (_isCustomSelected) return _amountMl > 0;
    return true;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  /// Returns just the amount string (number + unit) for display on the vessel card.
  String _vesselAmount(_VesselPreset vessel, bool isImperial) {
    if (vessel.ml == null) return ''; // Custom — no fixed amount
    if (isImperial) {
      final oz = _kVesselOz[vessel.key] ?? (vessel.ml! / _kOzToMl).roundToDouble();
      return '${oz.toStringAsFixed(0)} oz';
    }
    return '${vessel.ml!.toStringAsFixed(0)} ml';
  }

  double _toMl(_VesselPreset vessel, {double? customDisplayValue, required bool isImperial}) {
    if (vessel.ml != null) {
      if (isImperial) {
        final oz = _kVesselOz[vessel.key] ?? (vessel.ml! / _kOzToMl);
        return oz * _kOzToMl;
      }
      return vessel.ml!;
    }
    if (customDisplayValue == null || customDisplayValue <= 0) return 0;
    return isImperial ? customDisplayValue * _kOzToMl : customDisplayValue;
  }

  void _selectVessel(_VesselPreset vessel) {
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    setState(() {
      _selectedVesselKey = vessel.key;
      if (vessel.ml != null) {
        _amountMl = _toMl(vessel, isImperial: isImperial);
        _customController.clear();
      } else {
        _amountMl = 0;
      }
    });
  }

  void _onCustomChanged(String value) {
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    final parsed = double.tryParse(value) ?? 0;
    setState(() => _amountMl = isImperial ? parsed * _kOzToMl : parsed);
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;
    await widget.onSave(_amountMl);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(todayLogSummaryProvider);
    final goalsAsync = ref.watch(dailyGoalsProvider);
    final isImperial = ref.watch(unitsSystemProvider) == UnitsSystem.imperial;

    final todayMl = summaryAsync.valueOrNull?.latestValues['water'] as double?;
    final waterGoals = goalsAsync.valueOrNull
            ?.where((g) => g.label == 'Water')
            .toList() ??
        const <DailyGoal>[];
    final waterGoalMl = waterGoals.isEmpty ? null : waterGoals.first.target;

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Goal-progress ring header ───────────────────────────────────────
          _WaterRingHeader(
            todayMl: todayMl,
            goalMl: waterGoalMl,
            isImperial: isImperial,
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Vessel preset pills (Wrap so they flow on narrow widths) ───────
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: _kVessels.map((vessel) {
              final amountLabel = _vesselAmount(vessel, isImperial);
              return _VesselPill(
                vessel: vessel,
                isSelected: _selectedVesselKey == vessel.key,
                amountLabel: amountLabel,
                onTap: () => _selectVessel(vessel),
              );
            }).toList(),
          ),

          // ── Custom amount input — only when custom is selected ─────────────
          if (_isCustomSelected) ...[
            const SizedBox(height: AppDimens.spaceMd),
            AppTextField(
              controller: _customController,
              hintText: isImperial ? 'Enter amount (oz)' : 'Enter amount (ml)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              suffixIcon: Align(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceMd),
                  child: Text(
                    isImperial ? 'oz' : 'ml',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              onChanged: _onCustomChanged,
            ),
          ],

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save button (unchanged in Plan 1) ──────────────────────────────
          ZButton(
            label: 'Add Water',
            onPressed: _canSave ? _handleSave : null,
          ),
        ],
      ),
    );
  }
}

// ── _WaterRingHeader ──────────────────────────────────────────────────────────

/// Goal-progress ring + numeric summary row at the top of the water panel.
///
/// Renders a [ZMiniRing] tinted [AppColors.categoryBody] (body blue) sized
/// [_kRingSize] on the left, with a two-line text column on the right.
class _WaterRingHeader extends StatelessWidget {
  const _WaterRingHeader({
    required this.todayMl,
    required this.goalMl,
    required this.isImperial,
  });

  /// Cumulative water logged today in millilitres. `null` when nothing logged.
  final double? todayMl;

  /// Daily water goal in millilitres. `null` when the user has not set a goal.
  final double? goalMl;

  /// `true` when the user prefers imperial units (oz).
  final bool isImperial;

  double get _progress {
    final t = todayMl;
    final g = goalMl;
    if (t == null || g == null || g <= 0) return 0.0;
    return (t / g).clamp(0.0, 1.0);
  }

  String _formatToday() {
    final t = todayMl;
    if (t == null) return '0 ${isImperial ? 'oz' : 'ml'}';
    if (isImperial) {
      final oz = t / _kOzToMl;
      return '${oz.toStringAsFixed(1)} oz';
    }
    return '${t.toStringAsFixed(0)} ml';
  }

  String _formatGoalLine() {
    final g = goalMl;
    if (g == null) return 'Set a water goal in Settings';
    if (isImperial) {
      final oz = g / _kOzToMl;
      return 'of ${oz.toStringAsFixed(0)} oz daily goal';
    }
    return 'of ${g.toStringAsFixed(0)} ml daily goal';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ZMiniRing(
          size: _kRingSize,
          strokeWidth: 5,
          value: _progress,
          color: AppColors.categoryBody,
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatToday(),
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                _formatGoalLine(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── _VesselPill ───────────────────────────────────────────────────────────────

/// A compact pill button representing one vessel preset (or the custom option).
///
/// Tap target is at least [AppDimens.touchTargetMin] tall. Selected state uses
/// the brand sage [primary] surface with `textOnSage` foreground; unselected
/// uses the neutral surface with a 1.5px border. Animates background and
/// border with a 150ms ease-in-out tween.
class _VesselPill extends StatelessWidget {
  const _VesselPill({
    required this.vessel,
    required this.isSelected,
    required this.amountLabel,
    required this.onTap,
  });

  final _VesselPreset vessel;
  final bool isSelected;

  /// Pre-computed amount string (e.g. "250 ml" or "8 oz"). Empty for 'custom'.
  final String amountLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final icon = _kVesselIcons[vessel.key] ?? Icons.water_drop;
    final isCustom = vessel.key == 'custom';

    final backgroundColor = isSelected ? colors.primary : colors.surface;
    final foregroundColor =
        isSelected ? colors.textOnSage : colors.textSecondary;
    final borderColor = isSelected ? colors.primary : colors.border;

    final radius = BorderRadius.circular(AppDimens.radiusChip);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(
          minHeight: AppDimens.touchTargetMin,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: AppDimens.spaceXs),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vessel.label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: foregroundColor,
                  ),
                ),
                if (!isCustom && amountLabel.isNotEmpty)
                  Text(
                    amountLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: foregroundColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
