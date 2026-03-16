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
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
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
  _VesselPreset(key: 'large', label: 'Large', ml: 750),
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

// ── ZWaterLogPanel ─────────────────────────────────────────────────────────────

/// Inline log panel for water intake.
///
/// Shows vessel chips (Small cup, Glass, Bottle, Large, Custom).
/// Selecting a preset chip sets the amount automatically. Selecting Custom
/// reveals a text field for numeric input.
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

  String _vesselLabel(_VesselPreset vessel, bool isImperial) {
    if (vessel.ml == null) return 'Custom';
    if (isImperial) {
      final oz = _kVesselOz[vessel.key] ?? (vessel.ml! / _kOzToMl).roundToDouble();
      return '${vessel.label}\n${oz.toStringAsFixed(0)} oz';
    }
    return '${vessel.label}\n${vessel.ml!.toStringAsFixed(0)} ml';
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
    await widget.onSave(_amountMl);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(todayLogSummaryProvider);
    final isImperial = ref.watch(unitsSystemProvider) == UnitsSystem.imperial;

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Vessel chips ────────────────────────────────────────────────────
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: _kVessels.map((vessel) {
              final isSelected = _selectedVesselKey == vessel.key;
              return ChoiceChip(
                label: Text(_vesselLabel(vessel, isImperial)),
                selected: isSelected,
                onSelected: (_) => _selectVessel(vessel),
                selectedColor: AppColors.primary,
                backgroundColor: colors.surface,
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.primaryButtonText
                      : colors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusChip),
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : colors.border,
                ),
              );
            }).toList(),
          ),

          // ── Custom amount input ─────────────────────────────────────────────
          if (_isCustomSelected) ...[
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              controller: _customController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                hintText: isImperial ? 'Enter amount (oz)' : 'Enter amount (ml)',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: colors.textTertiary),
                suffixText: isImperial ? 'oz' : 'ml',
              ),
              onChanged: _onCustomChanged,
              cursorColor: AppColors.primary,
            ),
          ],

          const SizedBox(height: AppDimens.spaceMd),

          // ── Today total ─────────────────────────────────────────────────────
          summaryAsync.when(
            data: (summary) {
              final todayMl = summary.latestValues['water'] as double?;
              final String label;
              if (todayMl == null) {
                label = 'Nothing logged yet today';
              } else if (isImperial) {
                final oz = todayMl / _kOzToMl;
                label = '${oz.toStringAsFixed(1)} oz logged today';
              } else {
                label = '${todayMl.toStringAsFixed(0)} ml logged today';
              }
              return Text(
                label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textTertiary),
              );
            },
            loading: () => Text(
              'Nothing logged yet today',
              style:
                  AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
            ),
            error: (e, st) => Text(
              'Nothing logged yet today',
              style:
                  AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save button ─────────────────────────────────────────────────────
          FilledButton(
            onPressed: _canSave ? _handleSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusButton),
              ),
              minimumSize: const Size.fromHeight(AppDimens.touchTargetMin),
            ),
            child: Text(
              'Add Water',
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
