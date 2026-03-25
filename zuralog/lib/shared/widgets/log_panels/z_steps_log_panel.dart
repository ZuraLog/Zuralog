/// Zuralog — Steps Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Steps tile.
/// Allows manual entry of a step count. Shows a sync banner when today's
/// step data has arrived from Apple Health or Health Connect, and displays
/// progress toward the user's configured daily step goal.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── ZStepsLogPanel ─────────────────────────────────────────────────────────────

/// Inline log panel for manual step count entry.
///
/// Shows a numeric [TextField] for the step count, a sync banner when today's
/// step data is available from a connected health app (Apple Health or Health
/// Connect), goal progress, and a mode toggle (add vs. override).
///
/// The Save button is enabled only when `_steps > 0`. When the current value
/// matches the synced value the button label changes to "Confirm Steps".
///
/// The [onSave] callback receives the step count as an [int] and mode string.
class ZStepsLogPanel extends ConsumerStatefulWidget {
  const ZStepsLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user taps "Save Steps" / "Confirm Steps". Receives the
  /// step count and mode string ('add' or 'override'). Returns a [Future] so
  /// the caller can await the async repository call before closing the sheet.
  final Future<void> Function(int steps, String mode) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZStepsLogPanel> createState() => _ZStepsLogPanelState();
}

class _ZStepsLogPanelState extends ConsumerState<ZStepsLogPanel> {
  int _steps = 0;
  final TextEditingController _controller = TextEditingController();

  /// Step count received from the most recent sync — null until data arrives.
  int? _syncedSteps;

  /// Display name of the source that provided the synced value (e.g. "Apple Health").
  /// Captured once at sync time so the banner never reads from a stale provider value.
  String? _syncedSource;

  bool get _canSave => _steps > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final parsed = int.tryParse(value) ?? 0;
    setState(() => _steps = parsed);
  }

  Future<void> _handleSave() async {
    final mode = ref.read(stepsLogModeProvider).valueOrNull ?? StepsLogMode.add;
    final modeString = mode == StepsLogMode.override_ ? 'override' : 'add';
    await widget.onSave(_steps, modeString);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool _isToday(String? iso) {
    if (iso == null) return false;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  String _sourceDisplayName(String source) => switch (source) {
    'apple_health'   => 'Apple Health',
    'health_connect' => 'Health Connect',
    _                => '',
  };

  String _formatStepGoal(double target) {
    final n = target.toInt();
    if (n >= 1000) {
      return '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Listen for synced step data from the cloud brain.
    // ref.listen (not ref.watch) — this is a side-effect that pre-fills the
    // field once on open; we don't want it re-running on every rebuild.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      latestLogValuesProvider(latestLogValuesKey(const {'steps'})),
      (_, next) {
        next.whenData((latest) {
          final raw = latest['steps'];
          if (raw is! Map<String, dynamic>) return;
          final s = raw;
          if (_syncedSteps == null) {
            final steps = (s['steps'] as num?)?.toInt();
            final loggedAt = s['logged_at'] as String?;
            final source = s['source'] as String? ?? 'manual';
            if (steps != null && _isToday(loggedAt) && source != 'manual') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _syncedSteps = steps;
                    _steps = steps;
                    _controller.text = steps.toString();
                    _syncedSource = _sourceDisplayName(source);
                  });
                }
              });
            }
          }
        });
      },
    );

    // Read daily goals to find any configured step goal.
    final goals = ref.watch(dailyGoalsProvider).valueOrNull ?? const [];
    final stepGoal = goals.where(
      (g) =>
          g.unit.toLowerCase() == 'steps' || g.label.toLowerCase() == 'steps',
    ).firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Step count input ──────────────────────────────────────────────
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Enter step count',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary),
            ),
            onChanged: _onChanged,
            cursorColor: AppColors.primary,
          ),

          // ── Sync banner (only shown when today's data has arrived) ─────────
          if (_syncedSteps != null) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Text(
                '✓ Synced from ${_syncedSource ?? ''} — '
                '$_syncedSteps steps today. You can override below.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppDimens.spaceMd),

          // ── Mode toggle ───────────────────────────────────────────────────
          ref.watch(stepsLogModeProvider).when(
            loading: () => const SizedBox.shrink(),
            error: (err, st) => const SizedBox.shrink(),
            data: (mode) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add to today\'s total',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Switch(
                    value: mode == StepsLogMode.add,
                    onChanged: (val) {
                      ref.read(stepsLogModeProvider.notifier).setMode(
                        val ? StepsLogMode.add : StepsLogMode.override_,
                      );
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // ── Goal display ──────────────────────────────────────────────────
          Text(
            stepGoal == null
                ? 'Goal: —'
                : 'Goal: ${_formatStepGoal(stepGoal.target)} · '
                  '${(stepGoal.fraction * 100).round()}% done',
            style:
                AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Save button ───────────────────────────────────────────────────
          FilledButton(
            onPressed: _canSave ? _handleSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusButton),
              ),
              minimumSize: const Size.fromHeight(AppDimens.touchTargetMin),
            ),
            child: Text(
              (_syncedSteps != null && _steps == _syncedSteps)
                  ? 'Confirm Steps'
                  : 'Save Steps',
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
