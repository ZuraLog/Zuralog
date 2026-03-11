/// Journal Entry Sheet — modal bottom sheet for creating and editing journal entries.
///
/// Pass [initialEntry] to edit an existing entry; leave it null to create a new one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const List<String> _kPresetTags = [
  'Rest day',
  'Gym',
  'Stressful',
  'Traveled',
  'Good mood',
  'Poor sleep',
  'Sick',
  'Social',
  'Productive',
];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _moodEmoji(double value) {
  if (value <= 2) return '😞';
  if (value <= 4) return '😕';
  if (value <= 6) return '😐';
  if (value <= 8) return '😊';
  return '😄';
}

String _isoDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}'
    '-${dt.month.toString().padLeft(2, '0')}'
    '-${dt.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

/// Modal bottom sheet for creating or editing a [JournalEntry].
class JournalEntrySheet extends ConsumerStatefulWidget {
  /// Creates the [JournalEntrySheet].
  ///
  /// Pass [initialEntry] to open in edit mode.
  const JournalEntrySheet({super.key, this.initialEntry});

  /// Existing entry to edit; null for a new entry.
  final JournalEntry? initialEntry;

  @override
  ConsumerState<JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends ConsumerState<JournalEntrySheet> {
  // ── Form state ──────────────────────────────────────────────────────────────
  late DateTime _selectedDate;
  late double _mood;
  late double _energy;
  late double _stress;
  bool _trackSleep = false;
  late double _sleepQuality;
  late TextEditingController _notesController;
  late Set<String> _selectedTags;
  late List<String> _customTags;

  final TextEditingController _customTagController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get _isEditing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _selectedDate = e != null
        ? DateTime.tryParse(e.date) ?? DateTime.now()
        : DateTime.now();
    _mood = (e?.mood ?? 7).toDouble();
    _energy = (e?.energy ?? 7).toDouble();
    _stress = (e?.stress ?? 3).toDouble();
    _sleepQuality = (e?.sleepQuality ?? 7).toDouble();
    _trackSleep = e?.sleepQuality != null;
    _notesController = TextEditingController(text: e?.notes ?? '');

    // Split tags into preset-matching and custom.
    final allTags = e?.tags ?? [];
    _selectedTags = allTags
        .where(_kPresetTags.contains)
        .toSet();
    _customTags = allTags
        .where((t) => !_kPresetTags.contains(t))
        .toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final colors = AppColorsOf(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.primaryButtonText,
                surface: colors.surface,
                onSurface: colors.textPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final haptics = ref.read(hapticServiceProvider);
    final repo = ref.read(progressRepositoryProvider);
    final allTags = [..._selectedTags, ..._customTags];

    try {
      if (_isEditing) {
        await repo.updateJournalEntry(
          entryId: widget.initialEntry!.id,
          mood: _mood.round(),
          energy: _energy.round(),
          stress: _stress.round(),
          sleepQuality: _trackSleep ? _sleepQuality.round() : null,
          notes: _notesController.text.trim(),
          tags: allTags,
        );
      } else {
        await repo.createJournalEntry(
          date: _isoDate(_selectedDate),
          mood: _mood.round(),
          energy: _energy.round(),
          stress: _stress.round(),
          sleepQuality: _trackSleep ? _sleepQuality.round() : null,
          notes: _notesController.text.trim(),
          tags: allTags,
        );
      }

      await haptics.medium();
      ref.invalidate(journalProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save entry. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final colors = AppColorsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Delete Entry',
          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'This entry will be permanently deleted.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.body.copyWith(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    final haptics = ref.read(hapticServiceProvider);
    final repo = ref.read(progressRepositoryProvider);

    try {
      await repo.deleteJournalEntry(widget.initialEntry!.id);
      await haptics.warning();
      ref.invalidate(journalProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete entry. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty || _customTags.contains(tag) || _selectedTags.contains(tag)) return;
    setState(() {
      _customTags.add(tag);
      _customTagController.clear();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceMd + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ───────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────────
              Text(
                _isEditing ? 'Edit Entry' : 'New Entry',
                style: AppTextStyles.h2.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),

              // ── Date ──────────────────────────────────────────────────────
              _SectionLabel('Date'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: AppDimens.iconMd,
                ),
                title: Text(
                  _displayDate(_selectedDate),
                  style: AppTextStyles.body.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // ── Mood slider ───────────────────────────────────────────────
              _SliderField(
                label: 'Mood',
                emoji: _moodEmoji(_mood),
                value: _mood,
                activeColor: AppColors.categoryWellness,
                onChanged: (v) {
                  setState(() => _mood = v);
                  ref.read(hapticServiceProvider).selectionTick();
                },
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // ── Energy slider ─────────────────────────────────────────────
              _SliderField(
                label: 'Energy',
                emoji: _moodEmoji(_energy),
                value: _energy,
                activeColor: AppColors.categoryActivity,
                onChanged: (v) {
                  setState(() => _energy = v);
                  ref.read(hapticServiceProvider).selectionTick();
                },
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // ── Stress slider ─────────────────────────────────────────────
              _SliderField(
                label: 'Stress',
                emoji: _moodEmoji(_stress),
                value: _stress,
                activeColor: AppColors.statusError,
                onChanged: (v) {
                  setState(() => _stress = v);
                  ref.read(hapticServiceProvider).selectionTick();
                },
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // ── Sleep quality toggle + slider ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Track sleep quality',
                    style: AppTextStyles.h3.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Switch(
                    value: _trackSleep,
                    onChanged: (v) => setState(() => _trackSleep = v),
                    activeThumbColor: AppColors.categorySleep,
                    activeTrackColor:
                        AppColors.categorySleep.withValues(alpha: 0.4),
                  ),
                ],
              ),
              if (_trackSleep) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _SliderField(
                  label: 'Sleep Quality',
                  emoji: _moodEmoji(_sleepQuality),
                  value: _sleepQuality,
                  activeColor: AppColors.categorySleep,
                  onChanged: (v) {
                    setState(() => _sleepQuality = v);
                    ref.read(hapticServiceProvider).selectionTick();
                  },
                ),
              ],
              const SizedBox(height: AppDimens.spaceMd),

              // ── Notes field ───────────────────────────────────────────────
              _SectionLabel('Notes'),
              const SizedBox(height: AppDimens.spaceSm),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 8,
                style: AppTextStyles.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'How was your day?',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: colors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusInput),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusInput),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusInput),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),

              // ── Tags ──────────────────────────────────────────────────────
              _SectionLabel('Tags'),
              const SizedBox(height: AppDimens.spaceSm),
              Wrap(
                spacing: AppDimens.spaceSm,
                runSpacing: AppDimens.spaceSm,
                children: [
                  // Preset tags
                  ..._kPresetTags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(
                        tag,
                        style: AppTextStyles.caption.copyWith(
                          color: selected
                              ? AppColors.primaryButtonText
                              : colors.textSecondary,
                        ),
                      ),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      }),
                      backgroundColor: colors.surface,
                      selectedColor: AppColors.primary,
                      checkmarkColor: AppColors.primaryButtonText,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                      ),
                    );
                  }),
                  // Custom tags
                  ..._customTags.map((tag) => FilterChip(
                        label: Text(
                          tag,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryButtonText,
                          ),
                        ),
                        selected: true,
                        onSelected: (_) => setState(() => _customTags.remove(tag)),
                        backgroundColor: AppColors.primary,
                        selectedColor: AppColors.primary,
                        checkmarkColor: AppColors.primaryButtonText,
                        side: BorderSide.none,
                        deleteIcon: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.primaryButtonText,
                        ),
                        onDeleted: () =>
                            setState(() => _customTags.remove(tag)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceSm,
                        ),
                      )),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),

              // Custom tag input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customTagController,
                      style: AppTextStyles.body.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add custom tag…',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: colors.inputBackground,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceSm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusInput),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusInput),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusInput),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    onPressed: _addCustomTag,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),

              // ── Save button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryButtonText,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceMd,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryButtonText,
                          ),
                        )
                      : Text(
                          'Save Entry',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.primaryButtonText,
                          ),
                        ),
                ),
              ),

              // ── Delete button (edit mode only) ────────────────────────────
              if (_isEditing) ...[
                const SizedBox(height: AppDimens.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: const BorderSide(
                        color: AppColors.statusError,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceMd,
                      ),
                    ),
                    child: Text(
                      'Delete Entry',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.statusError,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Text(
      text,
      style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
    );
  }
}

// ── Slider field ──────────────────────────────────────────────────────────────

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.emoji,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final String emoji;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.h3.copyWith(
                color: colors.textPrimary,
              ),
            ),
            Text(
              '$emoji ${value.round()}',
              style: AppTextStyles.body.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            inactiveTrackColor:
                activeColor.withValues(alpha: 0.2),
            thumbColor: activeColor,
            overlayColor: activeColor.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
