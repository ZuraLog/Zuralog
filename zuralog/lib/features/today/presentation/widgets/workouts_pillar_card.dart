/// Today Tab — Workouts Pillar Card.
///
/// Shows this-week workout totals from local history (real data in all run
/// targets). Returns mock values only when USE_MOCK_DATA=true (make run-mock).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart' show kgToLbs;
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class WorkoutsPillarCard extends ConsumerWidget {
  const WorkoutsPillarCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(workoutWeeklySummaryProvider);
    final units = ref.watch(unitsSystemProvider);

    final displayVolume = units == UnitsSystem.imperial
        ? kgToLbs(summary.totalVolumeKg)
        : summary.totalVolumeKg;
    final volumeUnit = units == UnitsSystem.imperial ? 'lbs' : 'kg';
    final hasData = summary.workoutsThisWeek > 0;

    return ZPillarCard(
      icon: Icons.fitness_center_rounded,
      categoryColor: AppColors.categoryActivity,
      label: 'Workouts',
      headline: '${summary.workoutsThisWeek}',
      contextStat: 'This week',
      secondaryStats: [
        PillarStat(
          label: 'Sets',
          value: hasData ? '${summary.totalSets}' : '—',
        ),
        PillarStat(
          label: 'Volume',
          value: hasData ? _formatVolume(displayVolume, volumeUnit) : '—',
        ),
        PillarStat(
          label: 'Time',
          value: hasData ? _formatDuration(summary.totalDurationSeconds) : '—',
        ),
      ],
      onTap: onTap,
    );
  }

  static String _formatVolume(double volume, String unit) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k $unit';
    }
    return '${volume.toStringAsFixed(0)} $unit';
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
