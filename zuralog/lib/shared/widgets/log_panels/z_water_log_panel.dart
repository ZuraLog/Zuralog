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

// ── ZWaterLogPanel ─────────────────────────────────────────────────────────────

/// Inline log panel for water intake.
///
/// Shows vessel cards in a 2-column grid (Small cup, Glass, Bottle, Large bottle)
/// plus a full-width Custom tile below. Selecting a preset card sets the amount
/// automatically. Selecting Custom reveals a text field for numeric input.
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
    final isImperial = ref.watch(unitsSystemProvider) == UnitsSystem.imperial;

    // The 4 preset vessels (all except 'custom')
    final presets = _kVessels.where((v) => v.key != 'custom').toList();
    final customVessel = _kVessels.firstWhere((v) => v.key == 'custom');

    return Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
          // ── 2-column vessel card grid (4 presets) ───────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppDimens.spaceSm,
              mainAxisSpacing: AppDimens.spaceSm,
              mainAxisExtent: 110,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final vessel = presets[index];
              return _VesselCard(
                vessel: vessel,
                isSelected: _selectedVesselKey == vessel.key,
                amount: _vesselAmount(vessel, isImperial),
                onTap: () => _selectVessel(vessel),
              );
            },
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Full-width Custom tile ──────────────────────────────────────────
          _CustomTile(
            isSelected: _isCustomSelected,
            onTap: () => _selectVessel(customVessel),
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

// ── _VesselCard ────────────────────────────────────────────────────────────────

/// A square card representing a water vessel preset.
///
/// Shows an icon, the vessel name, and the amount (ml or oz depending on units).
/// Used only inside [ZWaterLogPanel] — not part of the shared widget library.
class _VesselCard extends StatelessWidget {
  const _VesselCard({
    required this.vessel,
    required this.isSelected,
    required this.amount,
    required this.onTap,
  });

  final _VesselPreset vessel;
  final bool isSelected;

  /// Pre-computed amount string (e.g. "150 ml" or "5 oz").
  final String amount;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final icon = _kVesselIcons[vessel.key] ?? Icons.water_drop;

    final backgroundColor = isSelected
        ? colors.primary.withValues(alpha: 0.10)
        : colors.cardBackground;
    final borderColor = isSelected ? colors.primary : colors.border;
    final borderWidth = isSelected ? 2.0 : 1.5;
    final iconColor = isSelected ? colors.primary : colors.textSecondary;
    final nameColor = isSelected ? colors.textPrimary : colors.textSecondary;
    final amountColor = isSelected ? colors.primary : colors.textPrimary;

    // Vessel card inner padding. 12px is intentional — AppDimens.spaceSm (8px)
    // is too tight for the icon+label+amount stack at mainAxisExtent 110, and
    // AppDimens.spaceMd (16px) leaves insufficient room. 12px is the midpoint.
    const cardPadding = 12.0;
    // 2px gap between vessel name and amount — tighter than spaceXs (4px) so
    // the name and amount read as one visual unit rather than two separate lines.
    const nameAmountGap = 2.0;

    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return ClipRRect(
      borderRadius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: colors.primary.withValues(alpha: 0.12),
            highlightColor: colors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(cardPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: iconColor),
                  const SizedBox(height: AppDimens.spaceXs),
                  Text(
                    vessel.label,
                    style: AppTextStyles.labelMedium.copyWith(color: nameColor),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: nameAmountGap),
                  Text(
                    amount,
                    style: AppTextStyles.labelLarge.copyWith(color: amountColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _CustomTile ────────────────────────────────────────────────────────────────

/// Full-width tile for the Custom vessel option.
///
/// Shows an edit icon on the left and "Custom" label centered.
/// Used only inside [ZWaterLogPanel].
class _CustomTile extends StatelessWidget {
  const _CustomTile({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    final backgroundColor = isSelected
        ? colors.primary.withValues(alpha: 0.10)
        : colors.cardBackground;
    final borderColor = isSelected ? colors.primary : colors.border;
    final borderWidth = isSelected ? 2.0 : 1.5;
    final iconColor = isSelected ? colors.primary : colors.textSecondary;
    final labelColor = isSelected ? colors.textPrimary : colors.textSecondary;

    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return ClipRRect(
      borderRadius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: AppDimens.touchTargetMin),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: colors.primary.withValues(alpha: 0.12),
            highlightColor: colors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, size: 20, color: iconColor),
                  const SizedBox(width: AppDimens.spaceSm),
                  Text(
                    'Custom',
                    style: AppTextStyles.labelMedium.copyWith(color: labelColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
