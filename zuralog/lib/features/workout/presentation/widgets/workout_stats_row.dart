/// Zuralog — Workout Stats Row.
///
/// Three-column metric row at the top of [WorkoutSessionScreen]:
/// Duration (h:mm:ss, Activity accent) | Volume (e.g. "125.0 kg") | Sets.
/// Reads live state from the workout-session providers so this strip
/// updates once per second without the parent rebuilding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

/// Formats a [Duration] as `h:mm:ss`.
String formatWorkoutDuration(Duration d) {
  final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class WorkoutStatsRow extends ConsumerWidget {
  const WorkoutStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final durationAsync = ref.watch(workoutDurationProvider);
    final volume = ref.watch(workoutVolumeProvider);
    final sets = ref.watch(workoutSetsCompletedProvider);
    final units = ref.watch(unitsSystemProvider);
    final unit = unitLabel(
      units == UnitsSystem.metric ? 'metric' : 'imperial',
    );
    final duration = durationAsync.maybeWhen(
      data: (d) => d,
      orElse: () => Duration.zero,
    );
    final isPaused = ref.watch(
      workoutSessionProvider.select((s) => s?.isPaused ?? false),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: 'Duration',
              value: formatWorkoutDuration(duration),
              valueColor: isPaused ? colors.primary : AppColors.categoryActivity,
              sublabel: isPaused ? 'PAUSED' : null,
            ),
          ),
          Expanded(
            child: _StatCell(
              label: 'Volume',
              value: '${volume.toStringAsFixed(1)} $unit',
              valueColor: colors.textPrimary,
            ),
          ),
          Expanded(
            child: _StatCell(
              label: 'Sets',
              value: '$sets',
              valueColor: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.sublabel,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall
              .copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (sublabel != null) ...[
          const SizedBox(height: 2),
          Text(
            sublabel!,
            style: AppTextStyles.labelSmall.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
