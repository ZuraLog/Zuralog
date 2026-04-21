/// Generic/fallback body for insights without a dedicated category variant.
/// Renders the chart and details from `detail.dataPoints` when available.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_primary_chart.dart';

List<Widget> genericInsightSlivers(
  BuildContext context,
  WidgetRef ref,
  InsightDetail detail,
) {
  if (detail.dataPoints.isEmpty) return const [];
  final color = categoryColorFromString(detail.category);
  return [
    SliverToBoxAdapter(
      child: InsightPrimaryChart(
        title: detail.chartTitle ?? 'Trend',
        categoryColor: color,
        points: [
          for (final p in detail.dataPoints)
            InsightPrimaryChartPoint(
              label: p.label,
              value: p.value,
              isToday: false,
            ),
        ],
        formatTooltip: (v) {
          final unit = detail.chartUnit ?? '';
          return '${v.toStringAsFixed(1)} $unit'.trim();
        },
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
  ];
}
