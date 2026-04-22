/// Zuralog — Exercise Entries Sheet.
///
/// A bottom sheet that shows today's manually-logged exercise burns,
/// lets the user add a new entry (activity name + calories), and supports
/// swipe-to-delete on existing entries.
///
/// Open via [ExerciseEntriesSheet.show].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_bottom_sheet.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_number_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_text_field.dart';

// ── ExerciseEntriesSheet ──────────────────────────────────────────────────────

/// Bottom sheet for viewing and managing today's exercise burns.
///
/// Shows a form at the top for logging a new entry, followed by a list of
/// today's entries. Each entry can be swiped left to delete it.
class ExerciseEntriesSheet extends ConsumerStatefulWidget {
  const ExerciseEntriesSheet({super.key});

  /// Shows this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return ZBottomSheet.show<void>(
      context,
      title: 'Exercise burns',
      child: const ExerciseEntriesSheet(),
    );
  }

  @override
  ConsumerState<ExerciseEntriesSheet> createState() =>
      _ExerciseEntriesSheetState();
}

class _ExerciseEntriesSheetState extends ConsumerState<ExerciseEntriesSheet> {
  final _activityController = TextEditingController();
  final _caloriesController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _activityController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final activity = _activityController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;

    if (activity.isEmpty) {
      setState(() => _error = 'Please enter an activity name.');
      return;
    }
    if (calories <= 0) {
      setState(() => _error = 'Please enter calories burned (greater than 0).');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(todayExerciseProvider.notifier).logExercise(
            activity: activity,
            durationMinutes: 0,
            caloriesBurned: calories,
          );
      _activityController.clear();
      _caloriesController.clear();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEntry(String id) async {
    await ref.read(todayExerciseProvider.notifier).deleteExercise(id);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(todayExerciseProvider);
    final entries = entriesAsync.valueOrNull ?? const <ExerciseEntry>[];
    final colors = AppColorsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Log form ──────────────────────────────────────────────────────────
        ZLabeledTextField(
          label: 'Activity',
          controller: _activityController,
          hint: 'e.g. Running, Cycling',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        ZLabeledNumberField(
          label: 'Calories burned',
          controller: _caloriesController,
          unit: 'kcal',
          allowDecimal: false,
          textInputAction: TextInputAction.done,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            _error!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: AppDimens.spaceMd),
        ZButton(
          label: 'Add exercise',
          onPressed: _isSaving ? null : _addEntry,
          variant: ZButtonVariant.primary,
        ),
        const SizedBox(height: AppDimens.spaceLg),

        // ── Entry list ────────────────────────────────────────────────────────
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              'No exercise logged today',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textTertiary,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimens.spaceSm),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _ExerciseEntryTile(
                entry: entry,
                onDelete: () => _deleteEntry(entry.id),
              );
            },
          ),
      ],
    );
  }
}

// ── _ExerciseEntryTile ────────────────────────────────────────────────────────

/// A single row in the exercise list with swipe-left-to-delete.
class _ExerciseEntryTile extends StatelessWidget {
  const _ExerciseEntryTile({
    required this.entry,
    required this.onDelete,
  });

  final ExerciseEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.warning),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceOverlay,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                entry.activity,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              '${entry.caloriesBurned} kcal',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
