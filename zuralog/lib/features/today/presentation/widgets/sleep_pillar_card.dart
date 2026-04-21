/// Today Tab — Sleep Pillar Card.
/// Reads from [sleepDaySummaryProvider] for live data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class SleepPillarCard extends ConsumerWidget {
  const SleepPillarCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sleepDaySummaryProvider);
    final summary = summaryAsync.valueOrNull ?? SleepDaySummary.empty;

    if (!summary.hasData && !summaryAsync.isLoading) {
      return ZPillarCard(
        icon: Icons.bedtime_rounded,
        categoryColor: AppColors.categorySleep,
        label: 'Sleep',
        headline: 'No sleep yet',
        contextStat: 'No data yet',
        onTap: onTap,
      );
    }

    final stats = <PillarStat>[
      if (summary.bedtime != null)
        PillarStat(label: 'Bed', value: _formatTime(summary.bedtime!)),
      if (summary.wakeTime != null)
        PillarStat(label: 'Wake', value: _formatTime(summary.wakeTime!)),
      if (summary.stages?.deepMinutes != null)
        PillarStat(
          label: 'Deep',
          value: _formatDuration(summary.stages!.deepMinutes!),
        ),
    ];

    return ZPillarCard(
      icon: Icons.bedtime_rounded,
      categoryColor: AppColors.categorySleep,
      label: 'Sleep',
      headline: summary.durationMinutes != null
          ? _formatDuration(summary.durationMinutes!)
          : '\u2013',
      contextStat: summary.qualityLabel,
      secondaryStats: stats,
      onTap: onTap,
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
