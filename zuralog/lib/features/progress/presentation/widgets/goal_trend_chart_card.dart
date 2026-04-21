/// Trend chart card for the Goal Detail page.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/goal_metrics.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

enum _Range { week, month, all }

class GoalTrendChartCard extends StatefulWidget {
  const GoalTrendChartCard({super.key, required this.goal});

  final Goal goal;

  @override
  State<GoalTrendChartCard> createState() => _GoalTrendChartCardState();
}

class _GoalTrendChartCardState extends State<GoalTrendChartCard> {
  _Range _range = _Range.month;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final visuals = goalVisuals(widget.goal);
    final values = _slice(widget.goal.progressHistory, _range);
    final lighter = Color.lerp(Colors.white, visuals.color, 0.6) ?? visuals.color;

    return ZFeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.goal.title} history',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RangeTabs(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _ChartPainter(
                values: values,
                target: widget.goal.targetValue,
                color: visuals.color,
                lighter: lighter,
                gridColor: AppColors.dividerDefault,
                projectedDays: _projectedRemainingDays(widget.goal),
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_rangeStartLabel(_range), style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
              Text(_rangeMidLabel(_range), style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
              Text('Today', style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  static List<double> _slice(List<double> all, _Range r) {
    if (all.isEmpty) return const [];
    final n = switch (r) {
      _Range.week => 7,
      _Range.month => 30,
      _Range.all => all.length,
    };
    final start = all.length - n;
    return start <= 0 ? all : all.sublist(start);
  }

  static int _projectedRemainingDays(Goal goal) {
    final v = velocityPerDay(goal);
    if (v == 0) return 0;
    final remaining = goal.targetValue - goal.currentValue;
    if (remaining <= 0) return 0;
    return (remaining / v.abs()).ceil();
  }

  String _rangeStartLabel(_Range r) {
    switch (r) {
      case _Range.week:
        return '7 days ago';
      case _Range.month:
        return '30 days ago';
      case _Range.all:
        return widget.goal.startDate;
    }
  }

  String _rangeMidLabel(_Range r) {
    switch (r) {
      case _Range.week:
        return '3 days ago';
      case _Range.month:
        return '15 days ago';
      case _Range.all:
        return 'midpoint';
    }
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.value, required this.onChanged});
  final _Range value;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RangeTab(label: 'Week', selected: value == _Range.week, onTap: () => onChanged(_Range.week)),
          _RangeTab(label: 'Month', selected: value == _Range.month, onTap: () => onChanged(_Range.month)),
          _RangeTab(label: 'All', selected: value == _Range.all, onTap: () => onChanged(_Range.all)),
        ],
      ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.warmWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.textOnWarmWhite : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.target,
    required this.color,
    required this.lighter,
    required this.gridColor,
    required this.projectedDays,
  });
  final List<double> values;
  final double target;
  final Color color;
  final Color lighter;
  final Color gridColor;
  final int projectedDays;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final yMin = (minV < target ? minV : target) - 0.5;
    final yMax = (maxV > target ? maxV : target) + 0.5;
    final range = (yMax - yMin).abs() < 0.0001 ? 1.0 : (yMax - yMin);

    double xFor(int i, int total) => total <= 1 ? 0 : (i / (total - 1)) * size.width;
    double yFor(double v) => size.height - ((v - yMin) / range) * size.height;

    // Target line (dashed).
    final targetY = yFor(target);
    final targetPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, targetY), Offset(x + 4, targetY), targetPaint);
      x += 8;
    }

    // Trend area + line.
    final n = values.length;
    final pts = <Offset>[for (var i = 0; i < n; i++) Offset(xFor(i, n), yFor(values[i]))];
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Today halo + dot.
    final today = pts.last;
    canvas.drawCircle(today, 10, Paint()..color = lighter.withValues(alpha: 0.3));
    canvas.drawCircle(today, 6, Paint()..color = lighter);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values ||
      old.target != target ||
      old.color != color ||
      old.projectedDays != projectedDays;
}
