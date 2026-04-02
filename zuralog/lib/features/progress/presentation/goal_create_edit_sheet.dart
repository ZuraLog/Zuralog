/// Goal Create / Edit Sheet — DraggableScrollableSheet modal bottom sheet.
///
/// Handles both creating a new [Goal] and editing an existing one.
/// Opens from [GoalsScreen] via [showModalBottomSheet].
///
/// Features a stepped/progressive layout with staggered entrance animations,
/// visual goal-type cards, and a sticky save button with animated brand pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/animations/z_fade_slide_in.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

// ── GoalCreateEditSheet ───────────────────────────────────────────────────────

/// Modal bottom sheet for creating or editing a [Goal].
///
/// Pass [initialGoal] to enter edit mode; leave null for create mode.
class GoalCreateEditSheet extends ConsumerStatefulWidget {
  /// Creates a [GoalCreateEditSheet].
  ///
  /// If [initialGoal] is provided the sheet pre-fills the form and saves
  /// via `updateGoal`. Otherwise a new goal is created via `createGoal`.
  const GoalCreateEditSheet({super.key, this.initialGoal});

  /// The goal to edit. Null when creating a new goal.
  final Goal? initialGoal;

  @override
  ConsumerState<GoalCreateEditSheet> createState() =>
      _GoalCreateEditSheetState();
}

class _GoalCreateEditSheetState extends ConsumerState<GoalCreateEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _unitCtrl;

  late GoalType _selectedType;
  late GoalPeriod _selectedPeriod;
  DateTime? _deadline;

  bool _isSaving = false;

  /// Whether a goal type has been chosen (always true in edit mode).
  bool _typeChosen = false;

  bool get _isEdit => widget.initialGoal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.initialGoal;
    _selectedType = g?.type ?? GoalType.custom;
    _selectedPeriod = g?.period ?? GoalPeriod.weekly;
    _titleCtrl = TextEditingController(text: g?.title ?? '');
    _targetCtrl = TextEditingController(
      text: g != null ? _fmtValue(g.targetValue) : '',
    );
    _unitCtrl = TextEditingController(text: g?.unit ?? '');
    _deadline = g?.deadline != null ? DateTime.tryParse(g!.deadline!) : null;

    // In edit mode, all sections are visible immediately.
    if (_isEdit) _typeChosen = true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  String _fmtValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final repo = ref.read(progressRepositoryProvider);
    final haptics = ref.read(hapticServiceProvider);

    final title = _titleCtrl.text.trim();
    final target = double.parse(_targetCtrl.text.trim());
    final unit = _unitCtrl.text.trim();
    // Build an explicit UTC-neutral date string to avoid timezone edge cases
    // (e.g. local DateTime behind UTC could produce the previous day).
    final d = _deadline;
    final deadlineIso = d != null
        ? '${d.year.toString().padLeft(4, '0')}'
            '-${d.month.toString().padLeft(2, '0')}'
            '-${d.day.toString().padLeft(2, '0')}'
        : null;

    try {
      if (_isEdit) {
        await repo.updateGoal(
          goalId: widget.initialGoal!.id,
          title: title,
          targetValue: target,
          unit: unit.isNotEmpty ? unit : null,
          deadline: deadlineIso,
        );
        await haptics.light();
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.goalUpdated,
          properties: {
            'goal_type': widget.initialGoal!.type.name,
            'has_deadline': deadlineIso != null,
          },
        );
      } else {
        await repo.createGoal(
          type: _selectedType,
          period: _selectedPeriod,
          title: title,
          targetValue: target,
          unit: unit,
          deadline: deadlineIso,
        );
        await haptics.medium();
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.goalCreated,
          properties: {
            'goal_type': _selectedType.name,
            'period': _selectedPeriod.name,
            'has_deadline': deadlineIso != null,
          },
        );
        // First-use guard.
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('analytics_first_goal_created') != true) {
          await prefs.setBool('analytics_first_goal_created', true);
          ref.read(analyticsServiceProvider).capture(
            event: AnalyticsEvents.firstGoalCreated,
          );
        }
      }

      ref.invalidate(goalsProvider);
      ref.invalidate(progressHomeProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save goal. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDeadline() async {
    final colors = AppColorsOf(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: AppColors.primaryButtonText,
                  surface: colors.elevatedSurface,
                  onSurface: colors.textPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _clearDeadline() => setState(() => _deadline = null);

  String _formatDeadline(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ── Icon mapping for goal types ──────────────────────────────────────────

  IconData _iconForType(GoalType type) {
    switch (type) {
      case GoalType.weightTarget:
        return Icons.monitor_weight_rounded;
      case GoalType.weeklyRunCount:
        return Icons.directions_run_rounded;
      case GoalType.dailyCalorieLimit:
        return Icons.local_fire_department_rounded;
      case GoalType.sleepDuration:
        return Icons.bedtime_rounded;
      case GoalType.stepCount:
        return Icons.directions_walk_rounded;
      case GoalType.waterIntake:
        return Icons.water_drop_rounded;
      case GoalType.custom:
        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              // ── Scrollable content ──────────────────────────────────
              Expanded(
                child: Form(
                  key: _formKey,
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(colors)),
                      SliverToBoxAdapter(child: _buildTypeSection(colors)),
                      // Progressive reveal: these sections appear after type is chosen
                      SliverToBoxAdapter(child: _buildDetailsSection(colors)),
                      // Extra bottom space so content is not hidden behind the button
                      SliverToBoxAdapter(
                        child: SizedBox(height: AppDimens.spaceLg),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Sticky save button ──────────────────────────────────
              _buildStickyButton(colors, bottomPadding),
            ],
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppColorsOf colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          ZFadeSlideIn(
            child: Text(
              _isEdit ? 'Edit Goal' : 'New Goal',
              style: AppTextStyles.h2,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZFadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              _isEdit
                  ? 'Update your goal details below.'
                  : 'Choose a goal type to get started.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Goal type picker — visual card grid ─────────────────────────────────────

  Widget _buildTypeSection(AppColorsOf colors) {
    return ZFadeSlideIn(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceLg,
          AppDimens.spaceMd,
          AppDimens.spaceLg,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Type',
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm + 4),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppDimens.spaceSm + 4,
              crossAxisSpacing: AppDimens.spaceSm + 4,
              childAspectRatio: 2.2,
              children: GoalType.values.map((type) {
                final selected = type == _selectedType && _typeChosen;
                return _GoalTypeCard(
                  type: type,
                  icon: _iconForType(type),
                  selected: selected,
                  enabled: !_isEdit,
                  onTap: _isEdit
                      ? null
                      : () {
                          ref.read(hapticServiceProvider).selectionTick();
                          setState(() {
                            _selectedType = type;
                            _typeChosen = true;
                            if (_unitCtrl.text.isEmpty ||
                                _unitCtrl.text == _defaultUnitFor(_selectedType)) {
                              _unitCtrl.text = _defaultUnitFor(type);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Details section (progressive reveal) ────────────────────────────────────

  Widget _buildDetailsSection(AppColorsOf colors) {
    final show = _typeChosen;

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: show ? 1.0 : 0.0,
        child: show
            ? Column(
                children: [
                  const SizedBox(height: AppDimens.spaceMd),
                  // Period selector
                  _buildPeriodSection(colors),
                  // Title field
                  _buildTitleField(colors),
                  // Target + Unit in a row
                  _buildTargetUnitRow(colors),
                  // Deadline
                  _buildDeadlineSection(colors),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── Period picker ────────────────────────────────────────────────────────────

  Widget _buildPeriodSection(AppColorsOf colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        0,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Period',
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<GoalPeriod>(
              segments: GoalPeriod.values
                  .map(
                    (p) => ButtonSegment<GoalPeriod>(
                      value: p,
                      label: Text(p.displayName),
                    ),
                  )
                  .toList(),
              selected: {_selectedPeriod},
              onSelectionChanged: _isEdit
                  ? null
                  : (set) {
                      ref.read(hapticServiceProvider).selectionTick();
                      setState(() => _selectedPeriod = set.first);
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return colors.inputBackground;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primaryButtonText;
                  }
                  return colors.textSecondary;
                }),
                textStyle: WidgetStatePropertyAll(AppTextStyles.caption),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Title field ──────────────────────────────────────────────────────────────

  Widget _buildTitleField(AppColorsOf colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        0,
      ),
      child: TextFormField(
        controller: _titleCtrl,
        textCapitalization: TextCapitalization.sentences,
        style: AppTextStyles.body.copyWith(color: colors.textPrimary),
        decoration: _inputDecoration(colors,
          label: 'Title',
          hint: 'e.g. Run 5km this week',
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Title is required';
          if (v.trim().length > 200) return 'Title must be 200 characters or fewer';
          return null;
        },
      ),
    );
  }

  // ── Target + Unit fields in a row ─────────────────────────────────────────

  Widget _buildTargetUnitRow(AppColorsOf colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target value — takes more space
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: AppTextStyles.body.copyWith(color: colors.textPrimary),
              decoration: _inputDecoration(colors,
                label: 'Target',
                hint: 'e.g. 10000',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final d = double.tryParse(v.trim());
                if (d == null || d <= 0) return 'Must be > 0';
                return null;
              },
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm + 4),
          // Unit — narrower
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _unitCtrl,
              style: AppTextStyles.body.copyWith(color: colors.textPrimary),
              decoration: _inputDecoration(colors,
                label: 'Unit',
                hint: 'e.g. steps',
              ),
              validator: (v) {
                if (v != null && v.trim().length > 50) {
                  return 'Max 50 chars';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Deadline section ─────────────────────────────────────────────────────────

  Widget _buildDeadlineSection(AppColorsOf colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deadline',
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          if (_deadline == null)
            TextButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                'Add deadline (optional)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: _pickDeadline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm + 4,
                      vertical: AppDimens.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusChip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Text(
                          _formatDeadline(_deadline!),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                GestureDetector(
                  onTap: _clearDeadline,
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.spaceXs + 2),
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Sticky save button with pattern overlay ───────────────────────────────

  Widget _buildStickyButton(AppColorsOf colors, double bottomPadding) {
    // Ensure the button clears the tab bar: at least 100px + safe area
    final effectiveBottomPad = bottomPadding + 100;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        effectiveBottomPad,
      ),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _typeChosen ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: (_isSaving || !_typeChosen) ? null : _save,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 1: Sage background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppDimens.shapePill),
                      ),
                    ),
                  ),
                  // Layer 2: Animated pattern overlay
                  Positioned.fill(
                    child: ZPatternOverlay(
                      variant: ZPatternVariant.sage,
                      opacity: 0.15,
                      animate: true,
                    ),
                  ),
                  // Layer 3: Button content
                  Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primaryButtonText,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Save Changes' : 'Create Goal',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.primaryButtonText,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Returns a sensible default unit string for a given [GoalType].
  ///
  /// Used to pre-fill the unit field when the user changes the goal type.
  /// For [GoalType.weightTarget], reads [unitsSystemProvider] via [ref] so
  /// the pre-fill respects the user's metric/imperial preference.
  String _defaultUnitFor(GoalType type) {
    switch (type) {
      case GoalType.weightTarget:
        final system = ref.read(unitsSystemProvider);
        return system == UnitsSystem.imperial ? 'lbs' : 'kg';
      case GoalType.weeklyRunCount:
        return 'runs';
      case GoalType.dailyCalorieLimit:
        return 'kcal';
      case GoalType.sleepDuration:
        return 'hrs';
      case GoalType.stepCount:
        return 'steps';
      case GoalType.waterIntake:
        return 'glasses';
      case GoalType.custom:
        return '';
    }
  }

  InputDecoration _inputDecoration(AppColorsOf colors, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: colors.inputBackground,
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: colors.textSecondary,
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textTertiary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        borderSide: const BorderSide(color: AppColors.statusError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        borderSide: const BorderSide(color: AppColors.statusError, width: 1.5),
      ),
    );
  }
}

// ── Goal Type Card ──────────────────────────────────────────────────────────

/// A visual card for selecting a goal type in the 2-column grid.
class _GoalTypeCard extends StatelessWidget {
  const _GoalTypeCard({
    required this.type,
    required this.icon,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final GoalType type;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : colors.border.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm + 4,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.spaceSm + 4),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? AppColors.primaryButtonText
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Text(
                type.displayName,
                style: AppTextStyles.caption.copyWith(
                  color: selected
                      ? AppColors.primaryButtonText
                      : colors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primaryButtonText.withValues(alpha: 0.8),
              ),
          ],
        ),
      ),
    );
  }
}
