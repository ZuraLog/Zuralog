library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';

class HeartTrendSection extends ConsumerStatefulWidget {
  const HeartTrendSection({super.key});

  @override
  ConsumerState<HeartTrendSection> createState() => _HeartTrendSectionState();
}

class _HeartTrendSectionState extends ConsumerState<HeartTrendSection> {
  String _range = '7d';

  static final _renderCtx = ChartRenderContext.fromMode(ChartMode.tall).copyWith(
    showAxes: true,
    showGrid: false,
    animationProgress: 1.0,
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final trendAsync = ref.watch(heartTrendProvider(_range));
    final days = trendAsync.valueOrNull ?? const <HeartTrendDay>[];

    List<ChartPoint> toPoints(double? Function(HeartTrendDay d) getter) =>
        days
            .where((d) => getter(d) != null)
            .map((d) => ChartPoint(
                  date: DateTime.parse(d.date),
                  value: getter(d)!,
                ))
            .toList();

    final rhrPoints = toPoints((d) => d.restingHr);
    final hrvPoints = toPoints((d) => d.hrvMs);

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Heart Trend',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: colors.textPrimary),
                  ),
                ),
                _RangeToggle(
                  selected: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // Resting HR chart
            Text(
              'Resting HR',
              style: AppTextStyles.labelSmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            rhrPoints.isNotEmpty
                ? SizedBox(
                    height: 120,
                    child: LineRenderer(
                      config: LineChartConfig(points: rhrPoints),
                      color: AppColors.categoryHeart,
                      renderCtx: _renderCtx,
                      unit: 'bpm',
                    ),
                  )
                : SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'No data for this period',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ),

            const SizedBox(height: AppDimens.spaceMd),

            // HRV chart
            Text(
              'HRV',
              style: AppTextStyles.labelSmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            hrvPoints.isNotEmpty
                ? SizedBox(
                    height: 120,
                    child: LineRenderer(
                      config: LineChartConfig(points: hrvPoints),
                      color: AppColors.categoryHeart,
                      renderCtx: _renderCtx,
                      unit: 'ms',
                    ),
                  )
                : SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'No data for this period',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: colors.textSecondary),
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
                  ? AppColors.categoryHeart.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              border: Border.all(
                color: isSelected
                    ? AppColors.categoryHeart.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              r,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? AppColors.categoryHeart
                    : AppColorsOf(context).textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
