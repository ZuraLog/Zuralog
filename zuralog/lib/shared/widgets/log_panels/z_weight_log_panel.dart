/// Zuralog — Weight Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Weight tile.
/// Allows logging body weight in kg or lbs using +/− step buttons.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── Top-level helpers ──────────────────────────────────────────────────────────

/// Formats the weight change between a previous and current entry.
///
/// Returns `null` if [previousKg] is `null` (no previous entry) or if the
/// absolute difference is less than 0.05 kg (effectively no change).
///
/// Examples:
/// - `formatWeightDelta(80.0, 80.5)` → `'+0.5 kg'`
/// - `formatWeightDelta(80.0, 79.3)` → `'-0.7 kg'`
/// - `formatWeightDelta(null, 80.0)` → `null`
String? formatWeightDelta(double? previousKg, double currentKg) {
  if (previousKg == null) return null;
  final delta = currentKg - previousKg;
  if (delta.abs() < 0.05) return null;
  final sign = delta > 0 ? '+' : '-';
  return '$sign${delta.abs().toStringAsFixed(1)} kg';
}

// ── Data model ─────────────────────────────────────────────────────────────────

class WeightLogData {
  const WeightLogData({
    required this.valueKg,
    required this.timeOfDay,
    this.bodyFatPct,
  });

  final double valueKg;
  final String timeOfDay;
  final double? bodyFatPct;
}

// ── ZWeightLogPanel ────────────────────────────────────────────────────────────

/// Inline log panel for body weight.
///
/// Always stores the value internally in kg. A kg/lbs toggle is shown above
/// the numeric display and defaults to the user's preferred unit from
/// [unitsSystemProvider], with the last-used unit persisted via SharedPreferences.
///
/// The +/− buttons step by 0.1 kg (or 0.1 lbs), clamped to [20, 500] kg.
///
/// On open, the panel pre-fills with the user's last logged weight from the
/// Cloud Brain via [latestLogValuesProvider]. A delta indicator shows how the
/// current value compares to the last logged value.
///
/// The [onSave] callback always receives the value in kg regardless of the
/// display unit toggle.
class ZWeightLogPanel extends ConsumerStatefulWidget {
  const ZWeightLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user taps "Save Weight". Receives a [WeightLogData] payload.
  final Future<void> Function(WeightLogData data) onSave;

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

  /// The last logged weight in kg (from Cloud Brain). Null until data arrives.
  double? _lastLoggedKg;

  /// Formatted date string of the last log entry (e.g. "15 Mar 2026").
  String? _lastLoggedAt;

  /// Active long-press timer for fast-scroll. Cancelled on release.
  Timer? _holdTimer;

  /// Whether the inline edit TextField is currently shown.
  bool _isEditing = false;

  /// Controller for the inline edit TextField.
  final TextEditingController _editController = TextEditingController();

  /// FocusNode for the inline edit TextField.
  final FocusNode _editFocusNode = FocusNode();

  static const _kWeightUnitKey = 'weight_log_unit';

  /// Step size in kg units.
  // In kg mode: 0.1 kg per tap.
  // In lbs mode: 0.1 lbs per tap → 0.1 / 2.20462 kg ≈ 0.0454 kg per tap.
  double get _step => _isKg ? 0.1 : 0.1 / 2.20462;

  /// Displayed value — converts to lbs when the lbs toggle is active.
  double get _displayValue => _isKg ? _value : _value * 2.20462;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadUnitPreference();
    }
  }

  Future<void> _loadUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kWeightUnitKey);
    if (!mounted) return;
    if (saved != null) {
      setState(() => _isKg = saved == 'kg');
    } else {
      final units = ref.read(unitsSystemProvider);
      setState(() => _isKg = units == UnitsSystem.metric);
    }
  }

  Future<void> _setUnit(bool isKg) async {
    setState(() => _isKg = isKg);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWeightUnitKey, isKg ? 'kg' : 'lbs');
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

  void _startHold(VoidCallback step) {
    step();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => step());
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _beginEdit() {
    _editController.text = _displayValue.toStringAsFixed(1);
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
  }

  void _commitEdit() {
    final raw = _editController.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed != null && parsed.isFinite) {
      final kg = _isKg ? parsed : parsed / 2.20462;
      setState(() => _value = kg.clamp(20.0, 500.0));
    }
    setState(() => _isEditing = false);
    _editFocusNode.unfocus();
  }

  Future<void> _handleSave() async {
    debugPrint('[WeightLog] 📤 Save tapped — value=$_value kg');
    await widget.onSave(WeightLogData(
      valueKg: _value,
      timeOfDay: 'morning', // placeholder — Plan C wires real state
      bodyFatPct: null,     // placeholder — Plan C wires real state
    ));
    debugPrint('[WeightLog] ✅ onSave callback returned');
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final displayStr = _displayValue.toStringAsFixed(1);

    // Pre-fill from latest logged value when data arrives.
    // ref.listen is used (not ref.watch) because this is a side-effect —
    // it must not run on every rebuild, only when the provider value changes.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      latestLogValuesProvider(latestLogValuesKey(const {'weight'})),
      (_, next) {
        next.whenData((latest) {
          final raw = latest['weight'];
          if (raw is! Map<String, dynamic>) return;
          final w = raw;
          if (_lastLoggedKg == null) {
            final kg = (w['value'] as num?)?.toDouble();
            final loggedAt = w['date'] as String?;
            if (kg != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _value = kg.clamp(20.0, 500.0);
                    _lastLoggedKg = kg;
                    _lastLoggedAt = _formatDate(loggedAt);
                  });
                }
              });
            }
          }
        });
      },
    );

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
                onTap: () => _setUnit(true),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _UnitChip(
                label: 'lbs',
                isSelected: !_isKg,
                onTap: () => _setUnit(false),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Value display with chevron tap zones ──────────────────────────
          SizedBox(
            height: 96,
            child: Stack(
              children: [
                Center(
                  child: _isEditing
                      ? IntrinsicWidth(
                          child: TextField(
                            controller: _editController,
                            focusNode: _editFocusNode,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            style: AppTextStyles.displayMedium.copyWith(
                              color: colors.textPrimary,
                              fontSize: 58,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _commitEdit(),
                            onTapOutside: (_) => _commitEdit(),
                          ),
                        )
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _beginEdit,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                displayStr,
                                style: AppTextStyles.displayMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 58,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: AppDimens.spaceXs),
                              Text(
                                _isKg ? 'kg' : 'lbs',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 64,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _decrement,
                    onLongPressStart: (_) => _startHold(_decrement),
                    onLongPressEnd: (_) => _stopHold(),
                    onLongPressCancel: _stopHold,
                    child: Center(
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 36,
                        color: colors.textSecondary,
                        semanticLabel: 'Decrease weight',
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 64,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _increment,
                    onLongPressStart: (_) => _startHold(_increment),
                    onLongPressEnd: (_) => _stopHold(),
                    onLongPressCancel: _stopHold,
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 36,
                        color: colors.textSecondary,
                        semanticLabel: 'Increase weight',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Last logged strip ────────────────────────────────────────────────
          const SizedBox(height: AppDimens.spaceXs),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceXxs,
              children: [
                Text(
                  _lastLoggedKg == null
                      ? 'Last logged: —'
                      : 'Last logged: ${_isKg ? _lastLoggedKg!.toStringAsFixed(1) : (_lastLoggedKg! * 2.20462).toStringAsFixed(1)} ${_isKg ? "kg" : "lbs"} · $_lastLoggedAt',
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                ),
                if (_lastLoggedKg != null)
                  _DeltaIndicator(
                    currentKg: _value,
                    previousKg: _lastLoggedKg!,
                    isKg: _isKg,
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'tap the number to type · hold ‹ or › to scroll fast',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save button ───────────────────────────────────────────────────
          ZButton(
            label: 'Save Weight',
            onPressed: _handleSave,
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
          color: isSelected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? colors.textOnSage : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── _DeltaIndicator ────────────────────────────────────────────────────────────

class _DeltaIndicator extends StatelessWidget {
  const _DeltaIndicator({
    required this.currentKg,
    required this.previousKg,
    required this.isKg,
  });

  final double currentKg;
  final double previousKg;
  final bool isKg;

  @override
  Widget build(BuildContext context) {
    final deltaKg = currentKg - previousKg;
    if (deltaKg.abs() < 0.05) {
      return const SizedBox.shrink();
    }
    final magnitude = isKg
        ? deltaKg.abs().toStringAsFixed(1)
        : (deltaKg.abs() * 2.20462).toStringAsFixed(1);
    final unit = isKg ? 'kg' : 'lbs';
    final isGain = deltaKg > 0;
    final arrow = isGain ? '↑' : '↓';
    final color = isGain ? AppColors.categoryHeart : AppColors.categoryActivity;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
      ),
      child: Text(
        '$arrow $magnitude $unit',
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
