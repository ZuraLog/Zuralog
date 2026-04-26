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

const double _kLargeRingSize = 110.0;
const double _kLargeRingStroke = 8.0;
const double _kVesselCardHeight = 84.0;
const String _kLastVesselPrefKey = 'water_log_last_vessel';
const String _kLastAmountPrefKey = 'water_log_last_amount_ml';
const String _kLastSavedAtPrefKey = 'water_log_last_saved_at_ms';

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

  final _ringKey = GlobalKey<_WaterRingHeaderState>();
  String? _defaultVesselKey;
  double? _lastAmountMl;
  DateTime? _lastSavedAt;
  bool _initialized = false;
  final FocusNode _customFocusNode = FocusNode();

  String? _badgeText;
  bool _showBadge = false;
  int _badgeKey = 0;

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
    final savedVessel = prefs.getString(_kLastVesselPrefKey);
    final savedAmount = prefs.getDouble(_kLastAmountPrefKey);
    final savedAtMs = prefs.getInt(_kLastSavedAtPrefKey);
    if (!mounted) return;
    setState(() {
      if (savedVessel != null) _defaultVesselKey = savedVessel;
      _lastAmountMl = savedAmount;
      if (savedAtMs != null) {
        _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      }
    });
  }

  void _triggerFeedback(double amountMl) {
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    final currentMl = _ringKey.currentState?._displayedMl ??
        (ref.read(todayLogSummaryProvider).valueOrNull?.latestValues['water']
                as double? ??
            0);
    _ringKey.currentState?.animateTo(currentMl + amountMl);

    final label = isImperial
        ? '+${(amountMl / _kOzToMl).toStringAsFixed(1)} oz'
        : '+${amountMl.toStringAsFixed(0)} mL';
    setState(() {
      _badgeText = label;
      _showBadge = true;
      _badgeKey++;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showBadge = false);
    });
  }

  void _handlePresetTap(_VesselPreset vessel) {
    final isImperial =
        ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    final amountMl = _toMl(vessel, isImperial: isImperial);
    if (amountMl <= 0) return;
    HapticFeedback.mediumImpact();
    // ignore: discarded_futures
    widget.onSave(amountMl, vesselKey: vessel.key);
    _triggerFeedback(amountMl);
    final now = DateTime.now();
    setState(() {
      _lastAmountMl = amountMl;
      _lastSavedAt = now;
    });
    // ignore: discarded_futures
    SharedPreferences.getInstance().then((p) {
      p.setString(_kLastVesselPrefKey, vessel.key);
      p.setDouble(_kLastAmountPrefKey, amountMl);
      p.setInt(_kLastSavedAtPrefKey, now.millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocusNode.dispose();
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
      _handlePresetTap(vessel);
      return;
    }
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    final initMl = _lastAmountMl ?? 0;
    setState(() {
      _selectedVesselKey = vessel.key;
      _amountMl = initMl;
      if (initMl > 0) {
        _customController.text = isImperial
            ? (initMl / _kOzToMl).toStringAsFixed(1)
            : initMl.toStringAsFixed(0);
      } else {
        _customController.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _customFocusNode.requestFocus(),
    );
  }

  void _increment() {
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    setState(() {
      _amountMl += 50;
      _customController.text = isImperial
          ? (_amountMl / _kOzToMl).toStringAsFixed(1)
          : _amountMl.toStringAsFixed(0);
    });
  }

  void _decrement() {
    if (_amountMl <= 0) return;
    final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
    setState(() {
      _amountMl = (_amountMl - 50).clamp(0, double.infinity);
      _customController.text = _amountMl > 0
          ? (isImperial
              ? (_amountMl / _kOzToMl).toStringAsFixed(1)
              : _amountMl.toStringAsFixed(0))
          : '';
    });
  }

  void _backToGrid() {
    _customFocusNode.unfocus();
    setState(() {
      _selectedVesselKey = null;
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
    final savedAmount = _amountMl;
    await widget.onSave(savedAmount, vesselKey: null);
    if (!mounted) return;
    _triggerFeedback(savedAmount);
    final now = DateTime.now();
    setState(() {
      _lastAmountMl = savedAmount;
      _lastSavedAt = now;
    });
    // ignore: discarded_futures
    SharedPreferences.getInstance().then((p) {
      p.setDouble(_kLastAmountPrefKey, savedAmount);
      p.setInt(_kLastSavedAtPrefKey, now.millisecondsSinceEpoch);
    });
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

    // The 4 preset vessels shown in the 2×2 grid.
    final presets = _kVessels.where((v) => v.ml != null).toList();
    // The custom entry (full-width bar).
    final customVessel = _kVessels.firstWhere((v) => v.ml == null);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
          // ── Centred ring header (always visible) ──────────────────────────
          _WaterRingHeader(
            key: _ringKey,
            todayMl: todayMl,
            goalMl: waterGoalMl,
            isImperial: isImperial,
            lastDrinkDate: lastDrinkDate,
            lastDrinkTime: _lastSavedAt,
          ),

          const SizedBox(height: AppDimens.spaceLg),

          if (!_isCustomSelected) ...[
            // ── 2×2 symmetric vessel grid ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _VesselCard(
                    vessel: presets[0],
                    isSelected: _selectedVesselKey == presets[0].key,
                    amountLabel: _vesselAmount(presets[0], isImperial),
                    isDefault: presets[0].key == _defaultVesselKey,
                    onTap: () => _selectVessel(presets[0]),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _VesselCard(
                    vessel: presets[1],
                    isSelected: _selectedVesselKey == presets[1].key,
                    amountLabel: _vesselAmount(presets[1], isImperial),
                    isDefault: presets[1].key == _defaultVesselKey,
                    onTap: () => _selectVessel(presets[1]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: _VesselCard(
                    vessel: presets[2],
                    isSelected: _selectedVesselKey == presets[2].key,
                    amountLabel: _vesselAmount(presets[2], isImperial),
                    isDefault: presets[2].key == _defaultVesselKey,
                    onTap: () => _selectVessel(presets[2]),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _VesselCard(
                    vessel: presets[3],
                    isSelected: _selectedVesselKey == presets[3].key,
                    amountLabel: _vesselAmount(presets[3], isImperial),
                    isDefault: presets[3].key == _defaultVesselKey,
                    onTap: () => _selectVessel(presets[3]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            // ── Full-width Custom amount bar ──────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectVessel(customVessel),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.shapeMd),
                  border: Border.all(color: colors.border, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit,
                      size: AppDimens.iconSm,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    Text(
                      'Custom amount',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── Custom-active: ±50 mL stepper + tappable number ──────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _decrement,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.shapeMd),
                      border: Border.all(color: colors.border, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '−',
                        style: AppTextStyles.displaySmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _customController,
                        focusNode: _customFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 48,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        onChanged: _onCustomChanged,
                      ),
                      Text(
                        isImperial ? 'ounces' : 'millilitres',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                GestureDetector(
                  onTap: _increment,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.shapeMd),
                      border: Border.all(color: colors.border, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '+',
                        style: AppTextStyles.displaySmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              '+/− adjusts by 50 mL',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ZButton(
              label: 'Back to vessels',
              variant: ZButtonVariant.secondary,
              size: ZButtonSize.medium,
              onPressed: _backToGrid,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ZButton(
              label: 'Add Water',
              onPressed: _amountMl > 0 ? _handleSave : null,
            ),
          ],
        ],
          ),
        ),
        // ── Float-up badge overlay (appears on every successful log) ─────────
        if (_showBadge && _badgeText != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(0, 0.1),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_badgeKey),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  builder: (_, t, child) => Opacity(
                    opacity: (1.0 - t * 1.5).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -50 * t),
                      child: child,
                    ),
                  ),
                  child: _FloatBadge(text: _badgeText!),
                ),
              ),
            ),
          ),
      ],
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
    super.key,
    required this.todayMl,
    required this.goalMl,
    required this.isImperial,
    this.lastDrinkDate,
    this.lastDrinkTime,
  });

  /// Cumulative water logged today in millilitres. `null` when nothing logged.
  final double? todayMl;

  /// Daily water goal in millilitres. `null` when the user has not set a goal.
  final double? goalMl;

  /// `true` when the user prefers imperial units (oz).
  final bool isImperial;

  /// ISO date string ('YYYY-MM-DD') or null — used as fallback when no precise timestamp.
  final String? lastDrinkDate;

  /// Precise timestamp of the last logged drink, for relative-time display.
  final DateTime? lastDrinkTime;

  @override
  State<_WaterRingHeader> createState() => _WaterRingHeaderState();
}

class _WaterRingHeaderState extends State<_WaterRingHeader>
    with SingleTickerProviderStateMixin {
  bool _goalJustCompleted = false;

  late AnimationController _countUpController;
  double _animFromMl = 0;
  double _animToMl = 0;

  double get _displayedMl {
    final t = Curves.easeOut.transform(_countUpController.value);
    return _animFromMl + (_animToMl - _animFromMl) * t;
  }

  @override
  void initState() {
    super.initState();
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animFromMl = widget.todayMl ?? 0;
    _animToMl = widget.todayMl ?? 0;
  }

  @override
  void dispose() {
    _countUpController.dispose();
    super.dispose();
  }

  void animateTo(double targetMl) {
    _animFromMl = _displayedMl;
    _animToMl = targetMl;
    _countUpController.forward(from: 0);
  }

  static double _computeProgress(double? todayMl, double? goalMl) {
    if (todayMl == null || goalMl == null || goalMl <= 0) return 0.0;
    return (todayMl / goalMl).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(_WaterRingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Goal completion detection uses real provider data, not optimistic value.
    final oldProgress = _computeProgress(oldWidget.todayMl, oldWidget.goalMl);
    final newProgress = _computeProgress(widget.todayMl, widget.goalMl);
    if (oldProgress < 1.0 && newProgress >= 1.0) {
      setState(() => _goalJustCompleted = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _goalJustCompleted = false);
      });
    }
    // Sync animation target to real data when idle.
    if (widget.todayMl != oldWidget.todayMl && !_countUpController.isAnimating) {
      final real = widget.todayMl ?? 0;
      _animFromMl = real;
      _animToMl = real;
    }
  }

  String _formatNumber(double ml) {
    if (widget.isImperial) return (ml / _kOzToMl).toStringAsFixed(1);
    return ml.toStringAsFixed(0);
  }

  String _formatTodayUnit() => widget.isImperial ? 'oz today' : 'mL today';

  String? _formatGoalInline() {
    final g = widget.goalMl;
    if (g == null) return null;
    if (widget.isImperial) {
      final oz = g / _kOzToMl;
      return '${oz.toStringAsFixed(0)} oz goal';
    }
    return '${g.toStringAsFixed(0)} mL goal';
  }

  String? _formatLastDrink(String? dateStr, DateTime? drinkTime) {
    if (drinkTime != null) {
      final diff = DateTime.now().difference(drinkTime);
      if (diff.inMinutes < 1) return 'Last drink: just now';
      if (diff.inMinutes < 60) return 'Last drink: ${diff.inMinutes} min ago';
      if (diff.inHours < 24) return 'Last drink: ${diff.inHours} hr ago';
      if (diff.inDays == 1) return 'Last drink: yesterday';
      return 'Last drink: ${diff.inDays} days ago';
    }
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
    final lastDrink = _formatLastDrink(widget.lastDrinkDate, widget.lastDrinkTime);
    final goalInline = _formatGoalInline();

    return AnimatedBuilder(
      animation: _countUpController,
      builder: (context, _) {
        final ml = _displayedMl;
        final progress = widget.goalMl != null && widget.goalMl! > 0
            ? (ml / widget.goalMl!).clamp(0.0, 1.0)
            : 0.0;
        final ringColor =
            progress >= 1.0 ? AppColors.success : AppColors.categoryBody;

        final numberWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatNumber(ml),
              style: AppTextStyles.displayMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            Text(
              _formatTodayUnit(),
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.goalMl != null) ...[
              // ── Large ring with today's number in the centre ────────────────
              SizedBox(
                width: _kLargeRingSize,
                height: _kLargeRingSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: _goalJustCompleted ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      child: ZMiniRing(
                        size: _kLargeRingSize,
                        strokeWidth: _kLargeRingStroke,
                        value: progress,
                        color: ringColor,
                      ),
                    ),
                    numberWidget,
                  ],
                ),
              ),
            ] else
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
                child: numberWidget,
              ),
            const SizedBox(height: AppDimens.spaceSm),
            // ── Meta row: last drink · goal ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastDrink != null)
                  Text(
                    lastDrink,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                if (lastDrink != null && goalInline != null) ...[
                  const SizedBox(width: AppDimens.spaceXs),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                ],
                if (goalInline != null)
                  Text(
                    goalInline,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── _VesselCard ───────────────────────────────────────────────────────────────

/// Square card used in the 2×2 vessel preset grid.
///
/// All four cards are forced to [_kVesselCardHeight] so the grid stays
/// perfectly symmetric regardless of label length. Selected state uses
/// [AppColors.categoryBody] tint; unselected uses the neutral surface.
///
/// When [isDefault] is true and the card is not selected, a small dot is shown
/// in the top-right corner as a hint that this was the last-used vessel.
class _VesselCard extends StatelessWidget {
  const _VesselCard({
    required this.vessel,
    required this.isSelected,
    required this.amountLabel,
    required this.onTap,
    this.isDefault = false,
  });

  final _VesselPreset vessel;
  final bool isSelected;
  final String amountLabel;
  final VoidCallback onTap;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final icon = _kVesselIcons[vessel.key] ?? Icons.water_drop;

    final borderColor =
        isSelected ? AppColors.categoryBody : colors.border;
    final bgColor = isSelected
        ? AppColors.categoryBody.withValues(alpha: 0.1)
        : colors.surface;
    final nameColor =
        isSelected ? AppColors.categoryBody : colors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        height: _kVesselCardHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: nameColor),
                  const SizedBox(height: 4),
                  Text(
                    vessel.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (amountLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      amountLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isDefault && !isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.categoryBody,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── _FloatBadge ───────────────────────────────────────────────────────────────

/// Pill badge shown briefly after a successful water log.
///
/// Displays the amount added (e.g. "+250 mL") in [AppColors.categoryBody]
/// text on a semi-transparent sky-blue background. Animated by the parent
/// via [TweenAnimationBuilder] — this widget is purely visual.
class _FloatBadge extends StatelessWidget {
  const _FloatBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.categoryBody.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.categoryBody.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.categoryBody,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
