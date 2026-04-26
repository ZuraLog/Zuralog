/// Zuralog — Water Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Water tile.
/// Allows quick logging of a water intake amount via vessel presets or
/// a custom numeric input.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
const String _kLastVesselPrefKey = 'water_log_last_vessel';

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

  /// Called whenever the user logs water — either by tapping a preset pill
  /// (instant-save) or by entering a custom amount and tapping "Add Water".
  ///
  /// [amountMl] is always millilitres. [vesselKey] is the chosen preset key
  /// ('small_cup', 'glass', 'bottle', 'large') or `null` for custom.
  final Future<void> Function(double amountMl, {String? vesselKey}) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZWaterLogPanel> createState() => _ZWaterLogPanelState();
}

class _ZWaterLogPanelState extends ConsumerState<ZWaterLogPanel> {
  String? _selectedVesselKey;
  double _amountMl = 0;
  final TextEditingController _customController = TextEditingController();

  String? _defaultVesselKey;
  bool _initialized = false;

  bool get _isCustomSelected => _selectedVesselKey == 'custom';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadLastVessel();
    }
  }

  Future<void> _loadLastVessel() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLastVesselPrefKey);
    if (!mounted) return;
    if (saved != null) {
      setState(() => _defaultVesselKey = saved);
    }
  }

  void _handlePresetTap(_VesselPreset vessel) {
    final isImperial =
        ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    final amountMl = _toMl(vessel, isImperial: isImperial);
    if (amountMl <= 0) return;
    HapticFeedback.mediumImpact();
    // ignore: discarded_futures
    widget.onSave(amountMl, vesselKey: vessel.key);
    // Persist last-used preset, fire-and-forget.
    // ignore: discarded_futures
    SharedPreferences.getInstance().then(
      (p) => p.setString(_kLastVesselPrefKey, vessel.key),
    );
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
    if (vessel.ml != null) {
      // Preset — instant-save, no state change needed.
      _handlePresetTap(vessel);
      return;
    }
    // Custom — toggle the input field on; clear any prior value.
    setState(() {
      _selectedVesselKey = vessel.key;
      _amountMl = 0;
      _customController.clear();
    });
  }

  void _onCustomChanged(String value) {
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    final parsed = double.tryParse(value) ?? 0;
    setState(() => _amountMl = isImperial ? parsed * _kOzToMl : parsed);
  }

  Future<void> _handleSave() async {
    if (!_isCustomSelected || _amountMl <= 0) return;
    HapticFeedback.mediumImpact();
    await widget.onSave(_amountMl, vesselKey: null);
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

    final lastWaterAsync = ref.watch(
      latestLogValuesProvider(latestLogValuesKey(const {'water'})),
    );
    final lastWaterRaw = lastWaterAsync.valueOrNull?['water'];
    final lastDrinkDate = lastWaterRaw is Map<String, dynamic>
        ? lastWaterRaw['date'] as String?
        : null;

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
            lastDrinkDate: lastDrinkDate,
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
                isDefault: vessel.key == _defaultVesselKey,
                onTap: () => _selectVessel(vessel),
              );
            }).toList(),
          ),

          // ── Custom amount input + save button (custom-only) ───────────────
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
            const SizedBox(height: AppDimens.spaceLg),
            ZButton(
              label: 'Add Water',
              onPressed: _amountMl > 0 ? _handleSave : null,
            ),
          ],
        ],
      ),
    );
  }
}

// ── _WaterRingHeader ──────────────────────────────────────────────────────────

/// Goal-progress ring + numeric summary row at the top of the water panel.
///
/// Renders a [ZMiniRing] tinted [AppColors.categoryBody] (body blue) sized
/// [_kRingSize] on the left, with a text column on the right. Animates the
/// ring with a brief scale-up when the goal is first reached.
class _WaterRingHeader extends StatefulWidget {
  const _WaterRingHeader({
    required this.todayMl,
    required this.goalMl,
    required this.isImperial,
    this.lastDrinkDate,
  });

  /// Cumulative water logged today in millilitres. `null` when nothing logged.
  final double? todayMl;

  /// Daily water goal in millilitres. `null` when the user has not set a goal.
  final double? goalMl;

  /// `true` when the user prefers imperial units (oz).
  final bool isImperial;

  /// ISO date string ('YYYY-MM-DD') or null.
  final String? lastDrinkDate;

  @override
  State<_WaterRingHeader> createState() => _WaterRingHeaderState();
}

class _WaterRingHeaderState extends State<_WaterRingHeader> {
  bool _goalJustCompleted = false;

  static double _computeProgress(double? todayMl, double? goalMl) {
    if (todayMl == null || goalMl == null || goalMl <= 0) return 0.0;
    return (todayMl / goalMl).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(_WaterRingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldProgress =
        _computeProgress(oldWidget.todayMl, oldWidget.goalMl);
    final newProgress = _computeProgress(widget.todayMl, widget.goalMl);
    if (oldProgress < 1.0 && newProgress >= 1.0) {
      setState(() => _goalJustCompleted = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _goalJustCompleted = false);
      });
    }
  }

  String _formatToday() {
    final t = widget.todayMl;
    if (t == null) return '0 ${widget.isImperial ? 'oz' : 'ml'}';
    if (widget.isImperial) {
      final oz = t / _kOzToMl;
      return '${oz.toStringAsFixed(1)} oz';
    }
    return '${t.toStringAsFixed(0)} ml';
  }

  String _formatGoalLine() {
    final g = widget.goalMl;
    if (g == null) return 'Set a water goal in Settings';
    if (widget.isImperial) {
      final oz = g / _kOzToMl;
      return 'of ${oz.toStringAsFixed(0)} oz daily goal';
    }
    return 'of ${g.toStringAsFixed(0)} ml daily goal';
  }

  String? _formatLastDrink(String? dateStr) {
    if (dateStr == null) return 'No drinks yet today';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final logDate = DateTime(date.year, date.month, date.day);
      final diff = today.difference(logDate).inDays;
      if (diff == 0) return 'Last drink: today';
      if (diff == 1) return 'Last drink: yesterday';
      if (diff > 1) return 'Last drink: $diff days ago';
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final progress = _computeProgress(widget.todayMl, widget.goalMl);
    final ringColor =
        progress >= 1.0 ? AppColors.success : AppColors.categoryBody;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: _goalJustCompleted ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          child: ZMiniRing(
            size: _kRingSize,
            strokeWidth: 5,
            value: progress,
            color: ringColor,
          ),
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
              if (_formatLastDrink(widget.lastDrinkDate) != null) ...[
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  _formatLastDrink(widget.lastDrinkDate)!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
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
///
/// When [isDefault] is true and the pill is not selected, a small dot is shown
/// beneath the amount label as a visual hint that this was the last-used vessel.
class _VesselPill extends StatelessWidget {
  const _VesselPill({
    required this.vessel,
    required this.isSelected,
    required this.amountLabel,
    required this.onTap,
    this.isDefault = false,
  });

  final _VesselPreset vessel;
  final bool isSelected;

  /// Pre-computed amount string (e.g. "250 ml" or "8 oz"). Empty for 'custom'.
  final String amountLabel;

  final VoidCallback onTap;

  /// When true, shows a small dot beneath the amount label to hint this was the
  /// last-used vessel. Only visible when the pill is not currently selected.
  final bool isDefault;

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
                if (isDefault && !isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
