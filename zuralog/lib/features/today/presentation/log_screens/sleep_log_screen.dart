/// Zuralog — Sleep Log Screen.
///
/// Full-screen form for logging a sleep entry. Pushed onto the nav stack
/// when the Sleep tile in [ZLogGridSheet] is tapped.
///
/// ## Nav bar clearance
/// This screen uses [ZuralogScaffold] with a pinned Save button at the bottom.
/// The Save button container uses [MediaQuery.of(context).padding.bottom] as
/// extra bottom padding so the nav bar never hides the button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

const _kQualityLabels = ['Awful', 'Poor', 'Okay', 'Good', 'Great'];

const _kFactors = [
  'Late workout', 'Alcohol', 'Caffeine', 'Stress',
  'Screen time', 'Napped', 'Noisy', 'Hot/cold', 'Illness',
];

class SleepLogScreen extends ConsumerStatefulWidget {
  const SleepLogScreen({super.key});

  @override
  ConsumerState<SleepLogScreen> createState() => _SleepLogScreenState();
}

class _SleepLogScreenState extends ConsumerState<SleepLogScreen> {
  DateTime? _bedtime;
  DateTime? _wakeTime;
  int? _qualityRating;
  int _interruptions = 0;
  final Set<String> _factors = {};
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_bedtime == null || _wakeTime == null || _isSaving) return false;
    int mins = _wakeTime!.difference(_bedtime!).inMinutes;
    if (mins < 0) mins += 24 * 60;
    return mins >= 1 && mins <= 1440;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Tap to set';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration() {
    if (_bedtime == null || _wakeTime == null) return '';
    int mins = _wakeTime!.difference(_bedtime!).inMinutes;
    if (mins < 0) mins += 24 * 60;   // overnight: wake is next calendar day
    if (mins <= 0) return '';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  Future<void> _pickTime(bool isBedtime) async {
    final initial = isBedtime
        ? (_bedtime ?? DateTime.now())
        : (_wakeTime ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    setState(() {
      if (isBedtime) {
        _bedtime = dt;
      } else {
        _wakeTime = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(todayRepositoryProvider);
      await repo.logSleep(
        bedtime: _bedtime!,
        wakeTime: _wakeTime!,
        durationMinutes: () {
          int mins = _wakeTime!.difference(_bedtime!).inMinutes;
          // Handle overnight sleep: if wake time appears before bedtime,
          // add 24 hours to the wake time difference.
          if (mins < 0) mins += 24 * 60;
          return mins;
        }(),
        qualityRating: _qualityRating,
        interruptions: _interruptions > 0 ? _interruptions : null,
        factors: _factors.toList(),
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
      debugPrint('SleepLogScreen save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Log Sleep'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              children: [
                Row(
                  children: [
                    Expanded(child: _TimeField(
                      label: 'Bedtime',
                      value: _formatTime(_bedtime),
                      onTap: () => _pickTime(true),
                    )),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(child: _TimeField(
                      label: 'Wake time',
                      value: _formatTime(_wakeTime),
                      onTap: () => _pickTime(false),
                    )),
                  ],
                ),
                if (_bedtime != null && _wakeTime != null) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimens.shapePill),
                      ),
                      child: Text(
                        _formatDuration(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimens.spaceLg),
                ZSectionLabel(label: 'Sleep quality', isOptional: true),
                const SizedBox(height: AppDimens.spaceSm),
                Column(
                  children: [
                    ZRatingBar(
                      rating: _qualityRating ?? 0,
                      onChanged: (v) => setState(() =>
                          _qualityRating = _qualityRating == v ? null : v),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _kQualityLabels.map((l) => Text(
                        l,
                        style: AppTextStyles.caption.copyWith(
                          color: _qualityRating == _kQualityLabels.indexOf(l) + 1
                              ? colors.primary
                              : colors.textTertiary,
                        ),
                      )).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                ZSectionLabel(label: 'Night interruptions', isOptional: true),
                const SizedBox(height: AppDimens.spaceSm),
                Center(
                  child: ZNumberStepper(
                    value: _interruptions,
                    min: 0,
                    max: 20,
                    onChanged: (v) => setState(() => _interruptions = v),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                ZSectionLabel(label: 'What affected your sleep?', isOptional: true),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: _kFactors.map((factor) => ZChip(
                    label: factor,
                    isActive: _factors.contains(factor),
                    onTap: () => setState(() {
                      if (_factors.contains(factor)) {
                        _factors.remove(factor);
                      } else {
                        _factors.add(factor);
                      }
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
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm + bottomPad,
            ),
            child: ZButton(
              label: 'Save Sleep',
              onPressed: _canSave ? _save : null,
              isLoading: _isSaving,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: colors.textTertiary)),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.h2),
          ],
        ),
      ),
    );
  }
}
