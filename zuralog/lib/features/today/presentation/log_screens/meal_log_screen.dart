/// Zuralog — Meal Log Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

const _kMealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Pre-workout', 'Post-workout'];
const _kCaloriePresets = [200, 400, 600, 800, 1000];
const _kFeelChips = ['Energised', 'Satisfied', 'Heavy', 'Bloated', 'Nauseous', 'Hungry still'];
const _kTagChips = ['High protein', 'Healthy', 'Takeaway', 'Home cooked', 'Cheat meal', 'Alcohol'];

String _autoSuggestMealType(DateTime now, Map<String, dynamic> latestValues) {
  final runLoggedAt = latestValues['run_logged_at'] as String?;
  if (runLoggedAt != null) {
    final runTime = DateTime.tryParse(runLoggedAt);
    if (runTime != null && now.difference(runTime).inMinutes.abs() <= 90) {
      return 'Post-workout';
    }
  }
  final hour = now.hour;
  if (hour < 10) return 'Breakfast';
  if (hour < 14) return 'Lunch';
  if (hour < 17) return 'Snack';
  return 'Dinner';
}

class MealLogScreen extends ConsumerStatefulWidget {
  const MealLogScreen({super.key});
  @override
  ConsumerState<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends ConsumerState<MealLogScreen> {
  String? _mealType;
  int? _calories;
  final _descriptionCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<String> _feelChips = {};
  final Set<String> _tags = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _autoSuggest();
  }

  void _autoSuggest() {
    final summary = ref.read(todayLogSummaryProvider).valueOrNull;
    final latestValues = summary?.latestValues ?? {};
    setState(() => _mealType = _autoSuggestMealType(DateTime.now(), latestValues));
  }

  void _onCaloriesTyped(String raw) {
    final parsed = int.tryParse(raw.trim());
    setState(() => _calories = parsed);
  }

  void _onPresetChipTapped(int preset) {
    final isDeselecting = _calories == preset;
    setState(() {
      _calories = isDeselecting ? null : preset;
      _caloriesCtrl.text = isDeselecting ? '' : preset.toString();
    });
  }

  bool get _canSave {
    if (_isSaving || _mealType == null) return false;
    final quickMode = ref.read(mealLogModeProvider).valueOrNull ?? false;
    if (quickMode && _calories == null) return false;
    if (!quickMode && _descriptionCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(todayRepositoryProvider);
      await repo.logMeal(
        mealType: _mealType!.toLowerCase().replaceAll('-', '_'),
        quickMode: ref.read(mealLogModeProvider).valueOrNull ?? false,
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        caloriesKcal: _calories,
        feelChips: _feelChips.toList(),
        tags: _tags.toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.invalidate(todayLogSummaryProvider);
          ref.invalidate(progressHomeProvider);
          ref.invalidate(goalsProvider);
        });
      }
    } catch (e) {
      debugPrint('MealLogScreen save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) { setState(() => _isSaving = false); }
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _caloriesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final quickMode = ref.watch(mealLogModeProvider).valueOrNull ?? false;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ZuralogScaffold(
      appBar: AppBar(title: const Text('Log Meal'), leading: const BackButton()),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quick calorie entry', style: AppTextStyles.bodyMedium),
                    Switch(value: quickMode, onChanged: (v) => ref.read(mealLogModeProvider.notifier).setMode(v)),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                const ZSectionLabel(label: 'Meal type'),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: _kMealTypes.map((t) => ZChip(
                    label: t,
                    isActive: _mealType == t,
                    onTap: () => setState(() => _mealType = t),
                  )).toList(),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                if (quickMode) ...[
                  const ZSectionLabel(label: 'Calories'),
                  const SizedBox(height: AppDimens.spaceSm),
                  AppTextField(
                    controller: _caloriesCtrl,
                    hintText: 'Enter calories',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    suffixIcon: Align(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppDimens.spaceMd),
                        child: Text('kcal', style: AppTextStyles.labelMedium.copyWith(color: colors.textSecondary)),
                      ),
                    ),
                    onChanged: _onCaloriesTyped,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    children: _kCaloriePresets.map((c) => ZChip(
                      label: '~$c',
                      isActive: _calories == c,
                      onTap: () => _onPresetChipTapped(c),
                    )).toList(),
                  ),
                ] else ...[
                  const ZSectionLabel(label: 'What did you eat?'),
                  const SizedBox(height: AppDimens.spaceSm),
                  ZTextArea(
                    controller: _descriptionCtrl,
                    placeholder: 'Describe what you ate...',
                    maxLength: 1000,
                    maxLines: 4,
                    minLines: 3,
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  const ZSectionLabel(label: 'Rough calories', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    children: _kCaloriePresets.map((c) => ZChip(
                      label: '~$c',
                      isActive: _calories == c,
                      onTap: () => setState(() => _calories = _calories == c ? null : c),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  ZSectionLabel(label: 'How did it make you feel?', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    runSpacing: AppDimens.spaceSm,
                    children: _kFeelChips.map((f) => ZChip(
                      label: f,
                      isActive: _feelChips.contains(f),
                      onTap: () => setState(() {
                        if (_feelChips.contains(f)) { _feelChips.remove(f); } else { _feelChips.add(f); }
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  ZSectionLabel(label: 'Tags', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    runSpacing: AppDimens.spaceSm,
                    children: _kTagChips.map((t) => ZChip(
                      label: t,
                      isActive: _tags.contains(t),
                      onTap: () => setState(() {
                        if (_tags.contains(t)) { _tags.remove(t); } else { _tags.add(t); }
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  ZSectionLabel(label: 'Notes', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  ZTextArea(
                    controller: _notesCtrl,
                    placeholder: 'Anything else to note?',
                    maxLength: 500,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, AppDimens.spaceSm + bottomPad),
            child: ZButton(
              label: quickMode ? 'Save' : 'Save Meal',
              onPressed: _canSave ? _save : null,
              isLoading: _isSaving,
            ),
          ),
        ],
      ),
    );
  }
}
