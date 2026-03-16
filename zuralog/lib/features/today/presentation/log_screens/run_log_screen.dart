/// Zuralog — Run Log Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

const _kActivities = ['Run', 'Walk', 'Cycle', 'Swim', 'Hike', 'Other'];
const _kEffortEmojis = ['😌', '😤', '🔥', '💀'];
const _kEffortLabels = ['Easy', 'Steady', 'Hard', 'Max'];

enum _RunMode { picker, manualForm }

class RunLogScreen extends ConsumerStatefulWidget {
  const RunLogScreen({super.key});

  @override
  ConsumerState<RunLogScreen> createState() => _RunLogScreenState();
}

class _RunLogScreenState extends ConsumerState<RunLogScreen> {
  _RunMode _mode = _RunMode.picker;
  String? _activityType;
  final _distanceCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();
  final _secondsCtrl = TextEditingController();
  int? _effortIndex;
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _distanceKm => double.tryParse(_distanceCtrl.text.trim());

  int? get _durationSeconds {
    final m = int.tryParse(_minutesCtrl.text.trim()) ?? 0;
    final s = int.tryParse(_secondsCtrl.text.trim()) ?? 0;
    final total = m * 60 + s;
    return total > 0 ? total : null;
  }

  int? _calcPaceSecondsPerKm() {
    final distKm = _distanceKm;
    final durSec = _durationSeconds;
    if (distKm == null || distKm == 0 || durSec == null) return null;
    return (durSec / distKm).round();
  }

  String _formatPace(int? secsPerKm) {
    if (secsPerKm == null) return '—';
    final m = secsPerKm ~/ 60;
    final s = secsPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')} / km';
  }

  bool get _canSave =>
      _activityType != null &&
      _distanceKm != null &&
      _distanceKm! > 0 &&
      _durationSeconds != null &&
      !_isSaving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(todayRepositoryProvider);
      await repo.logRun(
        activityType: _activityType!.toLowerCase(),
        distanceKm: _distanceKm!,
        durationSeconds: _durationSeconds!,
        avgPaceSecondsPerKm: _calcPaceSecondsPerKm(),
        effortLevel: _effortIndex != null ? _kEffortLabels[_effortIndex!].toLowerCase() : null,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      ref.invalidate(todayLogSummaryProvider);
      if (mounted) { Navigator.of(context).pop(); }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) { setState(() => _isSaving = false); }
    }
  }

  Future<void> _openStrava() async {
    const stravaDeepLink = 'strava://';
    final uri = Uri.parse(stravaDeepLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) context.pushNamed(RouteNames.settingsIntegrations);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ZuralogScaffold(
      appBar: AppBar(title: const Text('Log Run / Cardio'), leading: const BackButton()),
      body: _mode == _RunMode.picker
          ? _ModePicker(
              onOpenStrava: _openStrava,
              onLogPastRun: () => setState(() => _mode = _RunMode.manualForm),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    children: [
                      const ZSectionLabel(label: 'Activity type'),
                      const SizedBox(height: AppDimens.spaceSm),
                      Wrap(
                        spacing: AppDimens.spaceSm,
                        runSpacing: AppDimens.spaceSm,
                        children: _kActivities.map((a) => ChoiceChip(
                          label: Text(a),
                          selected: _activityType == a,
                          onSelected: (_) => setState(() => _activityType = a),
                        )).toList(),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      const ZSectionLabel(label: 'Distance'),
                      const SizedBox(height: AppDimens.spaceSm),
                      TextField(
                        controller: _distanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '0.0', suffixText: 'km'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      const ZSectionLabel(label: 'Duration'),
                      const SizedBox(height: AppDimens.spaceSm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minutesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '00', suffixText: 'min'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceMd),
                          Expanded(
                            child: TextField(
                              controller: _secondsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '00', suffixText: 'sec'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      if (_activityType != 'Swim')
                        Row(
                          children: [
                            Text('Avg pace', style: AppTextStyles.caption),
                            Text(': ', style: AppTextStyles.caption),
                            Text(
                              _formatPace(_calcPaceSecondsPerKm()),
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppDimens.spaceLg),
                      ZSectionLabel(label: 'Effort', isOptional: true),
                      const SizedBox(height: AppDimens.spaceSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (i) {
                          final selected = _effortIndex == i;
                          return GestureDetector(
                            onTap: () => setState(() => _effortIndex = selected ? null : i),
                            child: Column(
                              children: [
                                Text(_kEffortEmojis[i], style: TextStyle(fontSize: selected ? 32 : 24)),
                                Text(_kEffortLabels[i], style: AppTextStyles.caption.copyWith(
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                )),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      ZSectionLabel(label: 'Notes', isOptional: true),
                      const SizedBox(height: AppDimens.spaceSm),
                      TextField(controller: _notesCtrl, maxLength: 500, decoration: const InputDecoration(hintText: 'How did it go?')),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, AppDimens.spaceSm + bottomPad),
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _isSaving ? const CircularProgressIndicator.adaptive() : const Text('Save Run'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.onOpenStrava, required this.onLogPastRun});
  final VoidCallback onOpenStrava;
  final VoidCallback onLogPastRun;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      children: [
        GestureDetector(
          onTap: onOpenStrava,
          child: Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.categoryActivity, width: 2),
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Open Strava', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Record your run with Strava. It syncs back automatically.',
                    style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        GestureDetector(
          onTap: onLogPastRun,
          child: Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
            child: Text('Log a past run', style: AppTextStyles.bodyMedium),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Builder(builder: (ctx) => GestureDetector(
          onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Text('Live GPS recording is coming soon.'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          ),
          child: Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
              child: Row(children: [
                Text('Record live session', style: AppTextStyles.bodyMedium),
                const SizedBox(width: AppDimens.spaceSm),
                ZBadge(
                  label: 'Soon',
                  color: AppColors.primary.withValues(alpha: 0.2),
                  textColor: AppColors.primary,
                ),
              ]),
            ),
          ),
        )),
      ],
    );
  }
}
