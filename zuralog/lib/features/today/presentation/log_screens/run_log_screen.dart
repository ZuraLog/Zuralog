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
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

const _kActivities = ['Run', 'Walk', 'Cycle', 'Swim', 'Hike', 'Other'];
const _kEffortLabels = ['Easy', 'Steady', 'Hard', 'Max'];

enum _RunMode { picker, manualForm }

/// Calculates average pace in seconds per kilometre.
///
/// Returns `null` if [distanceKm] is zero or negative, or if
/// [durationSeconds] is zero or negative — prevents division by zero.
///
/// Examples:
/// - `calculatePaceSecondsPerKm(5.0, 1500)` → `300` (5:00/km)
/// - `calculatePaceSecondsPerKm(10.0, 3600)` → `360` (6:00/km)
int? calculatePaceSecondsPerKm(double distanceKm, int durationSeconds) {
  if (distanceKm <= 0 || durationSeconds <= 0) return null;
  return (durationSeconds / distanceKm).round();
}

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
  bool _useMetric = true; // initialised from unitsSystemProvider in initState

  @override
  void initState() {
    super.initState();
    // ref.read() is safe to call synchronously in initState for ConsumerStatefulWidget.
    // Read once — the toggle is session-scoped and does not write back to the preference.
    final units = ref.read(unitsSystemProvider);
    _useMetric = units == UnitsSystem.metric;
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Returns the entered distance converted to km regardless of display unit.
  /// This is what gets posted to the API — the backend always stores km.
  double? get _distanceKm {
    final raw = double.tryParse(_distanceCtrl.text.trim());
    if (raw == null) return null;
    return _useMetric ? raw : raw * 1.60934; // mi → km
  }

  int? get _durationSeconds {
    final m = int.tryParse(_minutesCtrl.text.trim()) ?? 0;
    final s = (int.tryParse(_secondsCtrl.text.trim()) ?? 0).clamp(0, 59);
    final total = m * 60 + s;
    return total > 0 ? total : null;
  }

  int? _calcPaceSecondsPerKm() {
    final distKm = _distanceKm;
    final durSec = _durationSeconds;
    if (distKm == null || durSec == null) return null;
    return calculatePaceSecondsPerKm(distKm, durSec);
  }

  /// Pace converted to the display unit.
  int? _calcDisplayPace() {
    final secsPerKm = _calcPaceSecondsPerKm();
    if (secsPerKm == null) return null;
    if (_useMetric) return secsPerKm;
    // A mile is longer than a km, so pace per mile is a larger number — multiply.
    // e.g. 300 sec/km × 1.60934 ≈ 483 sec/mile ≈ 8:03/mi
    return (secsPerKm * 1.60934).round();
  }

  String _formatPace(int? secsPerKm) {
    if (secsPerKm == null) return '—';
    final m = secsPerKm ~/ 60;
    final s = secsPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')} / ${_useMetric ? 'km' : 'mi'}';
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
      if (mounted) {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.invalidate(todayLogSummaryProvider);
          ref.invalidate(progressHomeProvider);
          ref.invalidate(goalsProvider);
        });
      }
    } catch (e) {
      debugPrint('RunLogScreen save failed: $e');
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
    final colors = AppColorsOf(context);
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
                        children: _kActivities.map((a) => ZChip(
                          label: a,
                          isActive: _activityType == a,
                          onTap: () => setState(() => _activityType = a),
                        )).toList(),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const ZSectionLabel(label: 'Distance'),
                          _UnitToggle(
                            useMetric: _useMetric,
                            onToggle: () => setState(() {
                              _useMetric = !_useMetric;
                              _distanceCtrl.clear();
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      AppTextField(
                        controller: _distanceCtrl,
                        hintText: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        suffixIcon: Align(
                          widthFactor: 1.0,
                          heightFactor: 1.0,
                          child: Padding(
                            padding: const EdgeInsets.only(right: AppDimens.spaceMd),
                            child: Text(_useMetric ? 'km' : 'mi', style: AppTextStyles.labelMedium.copyWith(color: colors.textSecondary)),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      const ZSectionLabel(label: 'Duration'),
                      const SizedBox(height: AppDimens.spaceSm),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _minutesCtrl,
                              hintText: '00',
                              keyboardType: TextInputType.number,
                              suffixIcon: Align(
                                widthFactor: 1.0,
                                heightFactor: 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: AppDimens.spaceMd),
                                  child: Text('min', style: AppTextStyles.labelMedium.copyWith(color: colors.textSecondary)),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceMd),
                          Expanded(
                            child: AppTextField(
                              controller: _secondsCtrl,
                              hintText: '00',
                              keyboardType: TextInputType.number,
                              suffixIcon: Align(
                                widthFactor: 1.0,
                                heightFactor: 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: AppDimens.spaceMd),
                                  child: Text('sec', style: AppTextStyles.labelMedium.copyWith(color: colors.textSecondary)),
                                ),
                              ),
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
                              _formatPace(_calcDisplayPace()),
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppDimens.spaceLg),
                      ZSectionLabel(label: 'Effort', isOptional: true),
                      const SizedBox(height: AppDimens.spaceSm),
                      Wrap(
                        spacing: AppDimens.spaceSm,
                        runSpacing: AppDimens.spaceSm,
                        children: List.generate(_kEffortLabels.length, (i) => ZChip(
                          label: _kEffortLabels[i],
                          isActive: _effortIndex == i,
                          onTap: () => setState(() => _effortIndex = _effortIndex == i ? null : i),
                        )),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      ZSectionLabel(label: 'Notes', isOptional: true),
                      const SizedBox(height: AppDimens.spaceSm),
                      ZTextArea(
                        controller: _notesCtrl,
                        placeholder: 'How did it go?',
                        maxLength: 500,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, AppDimens.spaceSm + bottomPad),
                  child: ZButton(
                    label: 'Save Run',
                    onPressed: _canSave ? _save : null,
                    isLoading: _isSaving,
                  ),
                ),
              ],
            ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.useMetric, required this.onToggle});
  final bool useMetric;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
          border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'km',
              style: TextStyle(
                fontSize: 13,
                fontWeight: useMetric ? FontWeight.w700 : FontWeight.w400,
                color: useMetric ? colors.primary : Colors.grey,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('·', style: TextStyle(color: Colors.grey)),
            ),
            Text(
              'mi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: !useMetric ? FontWeight.w700 : FontWeight.w400,
                color: !useMetric ? colors.primary : Colors.grey,
              ),
            ),
          ],
        ),
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
              backgroundColor: AppColorsOf(ctx).primary,
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
                  color: AppColorsOf(context).primary.withValues(alpha: 0.2),
                  textColor: AppColorsOf(context).primary,
                ),
              ]),
            ),
          ),
        )),
      ],
    );
  }
}
