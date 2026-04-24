library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show MetricDataPoint;
import 'package:zuralog/features/data/domain/tile_visualization_config.dart'
    show BarChartConfig, BarPoint;
import 'package:zuralog/features/workout/domain/steps_summary.dart';
import 'package:zuralog/features/workout/providers/steps_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

Future<void> showStepsDetailSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => const _StepsDetailSheet(),
  );
}

class _StepsDetailSheet extends ConsumerWidget {
  const _StepsDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(stepsHistoryProvider);
    final smartTargetEnabled = ref.watch(smartTargetEnabledProvider);
    final recoveryAwareEnabled = ref.watch(recoveryAwareEnabledProvider);
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceOverlay,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusCard),
          ),
        ),
        padding: EdgeInsets.only(bottom: bottomPad),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceLg,
          ),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Steps',
              style: AppTextStyles.displaySmall
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceXxs),
            Text(
              'Last 7 days',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            summaryAsync.when(
              loading: () => const ZLoadingSkeleton(
                width: double.infinity,
                height: 200,
              ),
              error: (_, _) => const ZErrorState(
                message: 'Could not load step history.',
              ),
              data: (summary) => _SheetBody(
                summary: summary,
                smartTargetEnabled: smartTargetEnabled,
                recoveryAwareEnabled: recoveryAwareEnabled,
                onToggleSmartTarget: () =>
                    ref.read(smartTargetEnabledProvider.notifier).toggle(),
                onToggleRecoveryAware: () =>
                    ref.read(recoveryAwareEnabledProvider.notifier).toggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet body ────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.summary,
    required this.smartTargetEnabled,
    required this.recoveryAwareEnabled,
    required this.onToggleSmartTarget,
    required this.onToggleRecoveryAware,
  });

  final StepsSummary summary;
  final bool smartTargetEnabled;
  final bool recoveryAwareEnabled;
  final VoidCallback onToggleSmartTarget;
  final VoidCallback onToggleRecoveryAware;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: ZChart(
            config: _toBarConfig(summary.dataPoints),
            mode: ChartMode.full,
            color: AppColors.categoryActivity,
            unit: 'steps',
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _StatsRow(summary: summary),
        const SizedBox(height: AppDimens.spaceLg),
        _ToggleRow(
          icon: Icons.track_changes_rounded,
          label: 'Smart Target',
          description: smartTargetEnabled && summary.smartTarget > 0
              ? 'Your sweet spot today: ${_fmt(summary.smartTarget)} steps'
              : 'Shows a personalized daily sweet spot',
          value: smartTargetEnabled,
          onToggle: onToggleSmartTarget,
        ),
        if (smartTargetEnabled) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _ToggleRow(
            icon: Icons.bedtime_rounded,
            label: 'Recovery-aware',
            description:
                'Adjusts your sweet spot based on sleep and body data',
            value: recoveryAwareEnabled,
            onToggle: onToggleRecoveryAware,
          ),
        ],
        if (summary.consecutiveDays > 1) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _InfoRow(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.categoryNutrition,
            text: 'Moving ${summary.consecutiveDays} days in a row',
          ),
        ],
        if (summary.sourceName != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _InfoRow(
            icon: Icons.phone_iphone_rounded,
            color: colors.textSecondary,
            text: 'Reading from ${summary.sourceName}',
          ),
        ],
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return '$n';
  }

  static BarChartConfig _toBarConfig(List<MetricDataPoint> points) {
    return BarChartConfig(
      bars: [
        for (var i = 0; i < points.length; i++)
          BarPoint(
            label: _dayLabel(points[i].timestamp),
            value: points[i].value,
            isToday: i == points.length - 1,
          ),
      ],
      showAvgLine: true,
    );
  }

  static String _dayLabel(String iso) {
    try {
      final d = DateTime.parse(iso);
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[d.weekday % 7];
    } catch (_) {
      return '';
    }
  }
}

// ── Three stats row ───────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary});

  final StepsSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            label: 'Today',
            value: _fmt(summary.todayCount),
            accent: AppColors.categoryActivity,
          ),
        ),
        _Divider(colors: colors),
        Expanded(
          child: _StatCell(
            label: '7-day avg',
            value: _fmt(summary.weekAverage.round()),
            accent: colors.textPrimary,
          ),
        ),
        _Divider(colors: colors),
        Expanded(
          child: _StatCell(
            label: 'Best this week',
            value: _fmt(summary.bestThisWeek),
            accent: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall
              .copyWith(fontSize: 10, color: colors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.titleLarge
              .copyWith(color: accent, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.colors});

  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: colors.border,
        margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXs),
      );
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.categoryActivity),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          ZToggle(
            value: value,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppDimens.spaceXs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
