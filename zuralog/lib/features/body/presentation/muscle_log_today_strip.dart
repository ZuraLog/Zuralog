library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/muscle_log.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';

class MuscleLogTodayStrip extends StatelessWidget {
  const MuscleLogTodayStrip({
    super.key,
    required this.logs,
    required this.onLogTap,
  });

  final List<MuscleLog> logs;
  final void Function(MuscleLog log) onLogTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOGGED TODAY',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ...logs.map((log) => MuscleLogRow(log: log, onTap: () => onLogTap(log))),
      ],
    );
  }
}

class MuscleLogRow extends StatelessWidget {
  const MuscleLogRow({super.key, required this.log, required this.onTap});

  final MuscleLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final dotColor = switch (log.state) {
      MuscleState.fresh => AppColors.categoryActivity,
      MuscleState.worked => AppColors.categoryNutrition,
      MuscleState.sore => AppColors.categoryHeart,
      MuscleState.neutral => colors.textSecondary,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.spaceXs,
          horizontal: AppDimens.spaceXs,
        ),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              log.muscleGroup.label,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
            ),
          ),
          Text(
            log.state.label,
            style: AppTextStyles.bodySmall.copyWith(color: dotColor),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            log.loggedAtTime,
            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Icon(
            log.synced ? Icons.cloud_done : Icons.cloud_upload,
            size: 12,
            color: log.synced
                ? AppColors.categoryActivity.withValues(alpha: 0.55)
                : colors.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Icon(Icons.chevron_right_rounded, size: 16, color: colors.textSecondary),
        ]),
      ),
    );
  }
}
