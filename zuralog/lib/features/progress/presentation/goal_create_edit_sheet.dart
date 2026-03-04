/// Goal Create / Edit Sheet — DraggableScrollableSheet modal bottom sheet.
///
/// Handles both creating a new [Goal] and editing an existing one.
/// Opens from [GoalsScreen] via [showModalBottomSheet].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

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
    final deadlineIso = _deadline?.toIso8601String().substring(0, 10);

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
                  surface: AppColors.elevatedSurfaceDark,
                  onSurface: AppColors.textPrimaryDark,
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.elevatedSurfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildTypeSection()),
                SliverToBoxAdapter(child: _buildPeriodSection()),
                SliverToBoxAdapter(child: _buildTitleField()),
                SliverToBoxAdapter(child: _buildTargetField()),
                SliverToBoxAdapter(child: _buildUnitField()),
                SliverToBoxAdapter(child: _buildDeadlineSection()),
                SliverToBoxAdapter(child: _buildSaveButton()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimens.spaceXl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
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
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            _isEdit ? 'Edit Goal' : 'New Goal',
            style: AppTextStyles.h2,
          ),
        ],
      ),
    );
  }

  // ── Goal type picker ─────────────────────────────────────────────────────────

  Widget _buildTypeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Type',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: GoalType.values.map((type) {
              final selected = type == _selectedType;
              return ChoiceChip(
                label: Text(type.displayName),
                selected: selected,
                onSelected: _isEdit
                    ? null // type locked in edit mode
                    : (_) => setState(() => _selectedType = type),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.inputBackgroundDark,
                disabledColor: AppColors.inputBackgroundDark,
                labelStyle: AppTextStyles.caption.copyWith(
                  color: selected
                      ? AppColors.primaryButtonText
                      : AppColors.textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  side: BorderSide.none,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Period picker ────────────────────────────────────────────────────────────

  Widget _buildPeriodSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Period',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SegmentedButton<GoalPeriod>(
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
                ? null // period locked in edit mode
                : (set) => setState(() => _selectedPeriod = set.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return AppColors.inputBackgroundDark;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryButtonText;
                }
                return AppColors.textSecondary;
              }),
              textStyle: WidgetStatePropertyAll(AppTextStyles.caption),
            ),
          ),
        ],
      ),
    );
  }

  // ── Title field ──────────────────────────────────────────────────────────────

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: TextFormField(
        controller: _titleCtrl,
        textCapitalization: TextCapitalization.sentences,
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimaryDark),
        decoration: _inputDecoration(
          label: 'Title',
          hint: 'e.g. Run 5km this week',
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Title is required';
          return null;
        },
      ),
    );
  }

  // ── Target value field ───────────────────────────────────────────────────────

  Widget _buildTargetField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: TextFormField(
        controller: _targetCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimaryDark),
        decoration: _inputDecoration(
          label: 'Target Value',
          hint: 'e.g. 10000',
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Target value is required';
          final d = double.tryParse(v.trim());
          if (d == null || d <= 0) return 'Enter a value greater than 0';
          return null;
        },
      ),
    );
  }

  // ── Unit field ───────────────────────────────────────────────────────────────

  Widget _buildUnitField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: TextFormField(
        controller: _unitCtrl,
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimaryDark),
        decoration: _inputDecoration(
          label: 'Unit',
          hint: 'e.g. steps, kg, hrs',
        ),
      ),
    );
  }

  // ── Deadline section ─────────────────────────────────────────────────────────

  Widget _buildDeadlineSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deadline',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
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
                'Add deadline',
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
                      horizontal: AppDimens.spaceSm,
                      vertical: AppDimens.spaceXs,
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
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Text(
                          _formatDeadline(_deadline!),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                GestureDetector(
                  onTap: _clearDeadline,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Save button ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryButtonText,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
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
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputBackgroundDark,
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
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
