/// Zuralog — Supplement Insights Screen.
///
/// Renders AI-generated correlation insights between the user's supplement
/// stack and their health metrics (sleep, HRV, energy, etc.) over the
/// last 60 days.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/supplement_insight.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Fetches AI-generated supplement correlation insights.
///
/// Intentionally package-visible (no leading underscore) so widget tests
/// can override it directly via [ProviderScope.overrides].
final insightsProvider =
    FutureProvider.autoDispose<SupplementInsightsResult>((ref) async {
  return ref.watch(todayRepositoryProvider).getSupplementInsights(days: 60);
});

/// Screen that displays AI-generated correlations between a user's supplement
/// stack and their tracked health metrics.
///
/// Shows a list of [_InsightCard] items when enough data is present, or a
/// friendly empty state when the user has fewer than 14 days of data.
class SupplementInsightsScreen extends ConsumerWidget {
  const SupplementInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Supplement Insights'),
        leading: const BackButton(),
      ),
      body: insightsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (_, _) => Center(
          child: Text(
            'Could not load insights.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textSecondary),
          ),
        ),
        data: (result) {
          if (!result.hasEnoughData) {
            return const ZEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Not enough data yet',
              message: 'Log your supplements for at least 14 days to see how '
                  'they connect to your sleep, HRV, and energy.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            itemCount: result.insights.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDimens.spaceSm),
            itemBuilder: (context, i) =>
                _InsightCard(item: result.insights[i]),
          );
        },
      ),
    );
  }
}

// ── _InsightCard ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.item});

  final SupplementInsightItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isPositive = item.direction == 'positive';
    final isNeutral = item.direction == 'neutral';

    return ZuralogCard(
      variant: ZCardVariant.feature,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNeutral
                ? Icons.remove_circle_outline
                : isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
            size: 20,
            color: isNeutral
                ? colors.textSecondary
                : isPositive
                    ? colors.success
                    : colors.error,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.metricLabel,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  item.insightText,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
