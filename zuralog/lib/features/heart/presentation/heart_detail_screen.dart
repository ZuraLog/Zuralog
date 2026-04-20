/// Heart detail screen — reached by tapping the Heart pillar card on the Today tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/heart/presentation/widgets/heart_ai_summary_card.dart';
import 'package:zuralog/features/heart/presentation/widgets/heart_hero_card.dart';
import 'package:zuralog/features/heart/presentation/widgets/heart_trend_section.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class HeartDetailScreen extends ConsumerWidget {
  const HeartDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(heartDaySummaryProvider);
    final summary = summaryAsync.valueOrNull ?? HeartDaySummary.empty;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Heart'),
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
                  HeartHeroCard(summary: summary),
                  const SizedBox(height: AppDimens.spaceMd),
                  HeartAiSummaryCard(
                    aiSummary: summary.aiSummary,
                    generatedAt: summary.aiGeneratedAt,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  const HeartTrendSection(),
                  const SizedBox(height: AppDimens.spaceSm),
                  InkWell(
                    onTap: () => context.pushNamed(RouteNames.heartAllData),
                    borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceXs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'View All Data',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceXs),
                          const ZProBadge(showLock: true),
                          const SizedBox(width: AppDimens.spaceXs),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: AppDimens.iconSm,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
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
