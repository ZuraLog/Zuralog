// zuralog/lib/features/sleep/presentation/widgets/sleep_trend_section.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';

class SleepTrendSection extends ConsumerStatefulWidget {
  const SleepTrendSection({super.key});

  @override
  ConsumerState<SleepTrendSection> createState() => _SleepTrendSectionState();
}

class _SleepTrendSectionState extends ConsumerState<SleepTrendSection> {
  String _range = '7d';

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final trendAsync = ref.watch(sleepTrendProvider(_range));
    final days = trendAsync.valueOrNull ?? const [];

    final bars = days
        .map((d) => BarPoint(
              label: d.date.length >= 10 ? d.date.substring(5) : d.date,
              value: d.durationMinutes?.toDouble() ?? 0,
              isToday: d.isToday,
            ))
        .toList();

    final avgMinutes = bars.isEmpty
        ? null
        : bars.fold<double>(0, (s, b) => s + b.value) / bars.length;

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sleep Trend',
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
            if (avgMinutes != null) ...[
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Avg ${_fmtDur(avgMinutes.round())}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            if (bars.isNotEmpty)
              SizedBox(
                height: 120,
                child: BarRenderer(
                  config: BarChartConfig(
                    bars: bars,
                    goalValue: 480,
                    showAvgLine: true,
                  ),
                  color: AppColors.categorySleep,
                  renderCtx: ChartRenderContext.fromMode(
                    ChartMode.tall,
                  ).copyWith(
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

  static String _fmtDur(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
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
                  ? AppColors.categorySleep.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              border: Border.all(
                color: isSelected
                    ? AppColors.categorySleep.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              r,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? AppColors.categorySleep
                    : AppColorsOf(context).textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
