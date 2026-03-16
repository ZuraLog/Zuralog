/// Zuralog — Weight Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Weight tile.
/// Allows logging body weight in kg or lbs using +/− step buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── ZWeightLogPanel ────────────────────────────────────────────────────────────

/// Inline log panel for body weight.
///
/// Always stores the value internally in kg. A kg/lbs toggle is shown above
/// the numeric display and defaults to the user's preferred unit from
/// [unitsSystemProvider].
///
/// The +/− buttons step by 0.1 kg (or 0.1 lbs), clamped to [20, 500] kg.
///
/// The [onSave] callback always receives the value in kg regardless of the
/// display unit toggle.
class ZWeightLogPanel extends ConsumerStatefulWidget {
  const ZWeightLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user taps "Save Weight". Receives the weight in kg.
  final void Function(double valueKg) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZWeightLogPanel> createState() => _ZWeightLogPanelState();
}

class _ZWeightLogPanelState extends ConsumerState<ZWeightLogPanel> {
  /// Internal value always in kg.
  double _value = 70.0;

  /// Whether the display and step logic uses kg.
  bool _isKg = true;
  bool _initialized = false;

  /// Step size in kg units.
  // In kg mode: 0.1 kg per tap.
  // In lbs mode: 0.1 lbs per tap → 0.1 / 2.20462 kg ≈ 0.0454 kg per tap.
  double get _step => _isKg ? 0.1 : 0.1 / 2.20462;

  /// Displayed value — converts to lbs when the lbs toggle is active.
  double get _displayValue => _isKg ? _value : _value * 2.20462;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final units = ref.read(unitsSystemProvider);
      _isKg = units == UnitsSystem.metric;
      _initialized = true;
    }
  }

  void _increment() {
    setState(() {
      _value = (_value + _step).clamp(20.0, 500.0);
    });
  }

  void _decrement() {
    setState(() {
      _value = (_value - _step).clamp(20.0, 500.0);
    });
  }

  void _handleSave() {
    // TODO(Part 4): Call repository. Endpoint: POST /api/v1/logs/weight
    // Body: { value_kg: double, logged_at: ISO8601 }
    // Always submit _value in kg regardless of display toggle.
    // Note: ref.invalidate(todayLogSummaryProvider) is intentionally NOT called
    // here. The sheet's onSaved callback owns post-save side effects so that
    // invalidation only fires on confirmed success (not before the server
    // round-trip in Part 4).
    widget.onSave(_value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final displayStr = _displayValue.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Unit toggle ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UnitChip(
                label: 'kg',
                isSelected: _isKg,
                onTap: () => setState(() => _isKg = true),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _UnitChip(
                label: 'lbs',
                isSelected: !_isKg,
                onTap: () => setState(() => _isKg = false),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Value display with +/− controls ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                iconSize: AppDimens.iconMd,
                onPressed: _decrement,
                tooltip: 'Decrease weight',
                color: colors.textPrimary,
                splashRadius: AppDimens.touchTargetMin / 2,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Text(
                displayStr,
                style: AppTextStyles.displayMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                _isKg ? 'kg' : 'lbs',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                iconSize: AppDimens.iconMd,
                onPressed: _increment,
                tooltip: 'Increase weight',
                color: colors.textPrimary,
                splashRadius: AppDimens.touchTargetMin / 2,
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Last logged (MVP stub) ─────────────────────────────────────────
          Center(
            child: Text(
              'Last logged: —',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textTertiary),
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save button ───────────────────────────────────────────────────
          FilledButton(
            onPressed: _handleSave,
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
              'Save Weight',
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _UnitChip ──────────────────────────────────────────────────────────────────

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? AppColors.primaryButtonText : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
