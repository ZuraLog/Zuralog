/// Activity-variant body. Activity does not have a dedicated domain
/// module, so this body renders directly from the insight's
/// `dataPoints`. When there are no data points, nothing is rendered
/// and the screen falls back to reasoning + sources + coach pill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_hero_card.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_primary_chart.dart';

List<Widget> activityInsightSlivers(
  BuildContext context,
  WidgetRef ref,
  InsightDetail detail,
) {
  final slivers = <Widget>[];
  if (detail.dataPoints.isNotEmpty) {
    final lastPoint = detail.dataPoints.last;
    slivers.add(
      SliverToBoxAdapter(
        child: InsightHeroCard(
          eyebrow: detail.chartTitle ?? 'Activity',
          categoryIcon: Icons.directions_run_rounded,
          categoryColor: AppColors.categoryActivity,
          value:
              '${lastPoint.value.toStringAsFixed(0)} ${detail.chartUnit ?? ''}'
                  .trim(),
        ),
      ),
    );
    slivers.add(
      const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    );
    slivers.add(
      SliverToBoxAdapter(
        child: InsightPrimaryChart(
          title: detail.chartTitle ?? 'Trend',
          categoryColor: AppColors.categoryActivity,
          points: [
            for (var i = 0; i < detail.dataPoints.length; i++)
              InsightPrimaryChartPoint(
                label: detail.dataPoints[i].label,
                value: detail.dataPoints[i].value,
                isToday: i == detail.dataPoints.length - 1,
              ),
          ],
          formatTooltip: (v) {
            final unit = detail.chartUnit ?? '';
            return '${v.toStringAsFixed(0)} $unit'.trim();
          },
        ),
      ),
    );
  }
  return slivers;
}
