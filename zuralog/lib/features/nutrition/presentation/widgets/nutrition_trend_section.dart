// zuralog/lib/features/nutrition/presentation/widgets/nutrition_trend_section.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';

class NutritionTrendSection extends ConsumerStatefulWidget {
  const NutritionTrendSection({super.key});

  @override
  ConsumerState<NutritionTrendSection> createState() =>
      _NutritionTrendSectionState();
}

class _NutritionTrendSectionState extends ConsumerState<NutritionTrendSection> {
  String _range = '7d';

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final trendAsync = ref.watch(nutritionTrendProvider(_range));
    final days = trendAsync.valueOrNull ?? const [];

    final calorieBars = days
        .map((d) => BarPoint(
              label: d.date.length >= 10 ? d.date.substring(5) : d.date,
              value: d.calories ?? 0,
              isToday: d.isToday,
            ))
        .toList();

    final proteinBars = days
        .map((d) => BarPoint(
              label: d.date.length >= 10 ? d.date.substring(5) : d.date,
              value: d.proteinG ?? 0,
              isToday: d.isToday,
            ))
        .toList();

    // Averages exclude today's entry (it is incomplete — null in the source).
    final avgCalories = days.isEmpty
        ? null
        : () {
            final nonNull = days.where((d) => d.calories != null).toList();
            if (nonNull.isEmpty) return null;
            return nonNull.fold<double>(0, (s, d) => s + d.calories!) /
                nonNull.length;
          }();

    final avgProtein = days.isEmpty
        ? null
        : () {
            final nonNull = days.where((d) => d.proteinG != null).toList();
            if (nonNull.isEmpty) return null;
            return nonNull.fold<double>(0, (s, d) => s + d.proteinG!) /
                nonNull.length;
          }();

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + range toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nutrition Trend',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                _RangeToggle(
                  selected: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Calories chart
            Text(
              avgCalories != null
                  ? 'Calories  ·  Avg ${avgCalories.round()} kcal'
                  : 'Calories',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            if (calorieBars.isNotEmpty)
              SizedBox(
                height: 120,
                child: BarRenderer(
                  config: BarChartConfig(
                    bars: calorieBars,
                    goalValue: 2000,
                    showAvgLine: true,
                  ),
                  color: AppColors.categoryNutrition,
                  renderCtx: ChartRenderContext.fromMode(ChartMode.tall).copyWith(
                    showAxes: true,
                    showGrid: false,
                    animationProgress: 1.0,
                  ),
                ),
              )
            else
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No data for this period',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AppDimens.spaceLg),

            // Protein chart
            Text(
              avgProtein != null
                  ? 'Protein  ·  Avg ${avgProtein.round()}g'
                  : 'Protein',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            if (proteinBars.isNotEmpty)
              SizedBox(
                height: 120,
                child: BarRenderer(
                  config: BarChartConfig(
                    bars: proteinBars,
                    goalValue: 150,
                    showAvgLine: true,
                  ),
                  color: AppColors.categoryNutrition,
                  renderCtx: ChartRenderContext.fromMode(ChartMode.tall).copyWith(
                    showAxes: true,
                    showGrid: false,
                    animationProgress: 1.0,
                  ),
                ),
              )
            else
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No data for this period',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['7d', '30d'].map((r) {
        final isSelected = selected == r;
        return GestureDetector(
          onTap: () => onChanged(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.categoryNutrition.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              border: Border.all(
                color: isSelected
                    ? AppColors.categoryNutrition.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              r,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? AppColors.categoryNutrition
                    : AppColorsOf(context).textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
