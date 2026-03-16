/// Zuralog — Meal Log Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
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
  bool _quickMode = false;
  String? _mealType;
  int? _caloriesPreset;
  final _descriptionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<String> _feelChips = {};
  final Set<String> _tags = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _autoSuggest();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _quickMode = prefs.getBool('meal_log_quick_mode') ?? false);
  }

  void _autoSuggest() {
    final summary = ref.read(todayLogSummaryProvider).valueOrNull;
    final latestValues = summary?.latestValues ?? {};
    setState(() => _mealType = _autoSuggestMealType(DateTime.now(), latestValues));
  }

  Future<void> _setQuickMode(bool value) async {
    setState(() => _quickMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('meal_log_quick_mode', value);
  }

  bool get _canSave {
    if (_isSaving || _mealType == null) return false;
    if (!_quickMode && _descriptionCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(todayRepositoryProvider);
      await repo.logMeal(
        mealType: _mealType!.toLowerCase().replaceAll('-', '_'),
        quickMode: _quickMode,
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        caloriesKcal: _caloriesPreset,
        feelChips: _feelChips.toList(),
        tags: _tags.toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      ref.invalidate(todayLogSummaryProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    Switch(value: _quickMode, onChanged: _setQuickMode),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                const ZSectionLabel(label: 'Meal type'),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: _kMealTypes.map((t) => ChoiceChip(
                    label: Text(t),
                    selected: _mealType == t,
                    onSelected: (_) => setState(() => _mealType = t),
                  )).toList(),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                if (_quickMode) ...[
                  const ZSectionLabel(label: 'Calories'),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    children: _kCaloriePresets.map((c) => ChoiceChip(
                      label: Text('~$c'),
                      selected: _caloriesPreset == c,
                      onSelected: (_) => setState(() => _caloriesPreset = c),
                    )).toList(),
                  ),
                ] else ...[
                  const ZSectionLabel(label: 'What did you eat?'),
                  const SizedBox(height: AppDimens.spaceSm),
                  TextField(
                    controller: _descriptionCtrl,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Describe what you ate...'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  ZSectionLabel(label: 'Rough calories', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    children: _kCaloriePresets.map((c) => ChoiceChip(
                      label: Text('~$c'),
                      selected: _caloriesPreset == c,
                      onSelected: (_) => setState(() => _caloriesPreset = c),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  ZSectionLabel(label: 'How did it make you feel?', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  Wrap(
                    spacing: AppDimens.spaceSm,
                    runSpacing: AppDimens.spaceSm,
                    children: _kFeelChips.map((f) => FilterChip(
                      label: Text(f),
                      selected: _feelChips.contains(f),
                      onSelected: (_) => setState(() {
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
                    children: _kTagChips.map((t) => FilterChip(
                      label: Text(t),
                      selected: _tags.contains(t),
                      onSelected: (_) => setState(() {
                        if (_tags.contains(t)) { _tags.remove(t); } else { _tags.add(t); }
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  ZSectionLabel(label: 'Notes', isOptional: true),
                  const SizedBox(height: AppDimens.spaceSm),
                  TextField(controller: _notesCtrl, maxLength: 500, decoration: const InputDecoration(hintText: 'Anything else to note?')),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, AppDimens.spaceSm + bottomPad),
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _isSaving ? const CircularProgressIndicator.adaptive() : const Text('Save Meal'),
            ),
          ),
        ],
      ),
    );
  }
}
