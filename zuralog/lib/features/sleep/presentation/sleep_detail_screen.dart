/// Sleep detail screen — reached by tapping the Sleep pillar card on the Today tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/presentation/widgets/sleep_ai_summary_card.dart';
import 'package:zuralog/features/sleep/presentation/widgets/sleep_factors_section.dart';
import 'package:zuralog/features/sleep/presentation/widgets/sleep_hero_card.dart';
import 'package:zuralog/features/sleep/presentation/widgets/sleep_hr_section.dart';
import 'package:zuralog/features/sleep/presentation/widgets/sleep_stage_section.dart';
import 'package:zuralog/features/sleep/presentation/widgets/sleep_trend_section.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/shared/widgets/animations/z_staggered_list.dart';

class SleepDetailScreen extends ConsumerWidget {
  const SleepDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(sleepDaySummaryProvider);
    final summary = summaryAsync.valueOrNull ?? SleepDaySummary.empty;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Sleep'),
            pinned: true,
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            sliver: SliverToBoxAdapter(
              child: ZStaggeredList(
                children: [
                  SleepHeroCard(summary: summary),
                  const SizedBox(height: AppDimens.spaceMd),
                  if (summary.stages != null && summary.stages!.hasAnyData) ...[
                    SleepStageSection(stages: summary.stages!),
                    const SizedBox(height: AppDimens.spaceMd),
                  ],
                  if (summary.sleepingHr != null &&
                      summary.sleepingHr!.curve.isNotEmpty) ...[
                    SleepHrSection(sleepingHr: summary.sleepingHr!),
                    const SizedBox(height: AppDimens.spaceMd),
                  ],
                  SleepAiSummaryCard(
                    aiSummary: summary.aiSummary,
                    generatedAt: summary.aiGeneratedAt,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  const SleepTrendSection(),
                  if (summary.factors.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.spaceMd),
                    SleepFactorsSection(factors: summary.factors),
                  ],
                  if (summary.hasData && summary.stages == null) ...[
                    const SizedBox(height: AppDimens.spaceMd),
                    _UnlockWearableCallout(),
                  ],
                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockWearableCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.categorySleep.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(
          color: AppColors.categorySleep.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.watch_rounded,
            size: AppDimens.iconMd,
            color: AppColors.categorySleep,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              'Connect a wearable to see your sleep stage breakdown and sleeping heart rate.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
