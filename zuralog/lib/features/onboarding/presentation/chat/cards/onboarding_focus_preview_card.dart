/// Zuralog — Onboarding Focus Preview Card.
///
/// Dropped into the chat right after the user picks their main focus.
/// The card adapts to the category:
///
///   - Sleep      → horizontal stacked sleep-stages bar
///   - Activity   → 7-day vertical step bar chart with a sage target line
///   - Nutrition  → macro doughnut (Protein / Carbs / Fat)
///   - Overall    → four concentric pillar rings
///
/// Each chart is painted with a custom painter — keeps the card
/// self-contained and fast to render in the chat transcript.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingFocusPreviewCard extends StatelessWidget {
  const OnboardingFocusPreviewCard({
    super.key,
    required this.focusId,
  });

  final String focusId;

  static const double _cardRadius = 22;
  static const double _chartHeight = 120;

  @override
  Widget build(BuildContext context) {
    final label = _categoryLabel(focusId);
    final accent = _categoryAccent(focusId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'YOUR ${label.toUpperCase()} SNAPSHOT',
                style: AppTextStyles.labelSmall.copyWith(
                  color: accent,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          SizedBox(
            height: _chartHeight,
            child: _chartFor(focusId, accent),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            _caption(focusId),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              letterSpacing: -0.1,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartFor(String id, Color accent) {
    switch (id) {
      case 'sleep':
        return const _SleepStagesChart();
      case 'activity':
        return const _ActivityWeekChart();
      case 'nutrition':
        return const _NutritionMacroDonut();
      case 'overall':
      default:
        return const _WellnessRingsChart();
    }
  }

  String _caption(String id) {
    switch (id) {
      case 'sleep':
        return "This is the shape of a healthy night — I'll track yours against it.";
      case 'activity':
        return 'I\'ll watch your movement week over week and nudge you toward consistency.';
      case 'nutrition':
        return "I'll learn your macro balance and spot patterns in how you eat.";
      case 'overall':
      default:
        return 'I\'ll balance all four pillars so nothing gets neglected.';
    }
  }

  String _categoryLabel(String id) {
    switch (id) {
      case 'sleep':
        return 'Sleep';
      case 'activity':
        return 'Activity';
      case 'nutrition':
        return 'Nutrition';
      case 'overall':
      default:
        return 'Wellness';
    }
  }

  Color _categoryAccent(String id) {
    switch (id) {
      case 'sleep':
        return AppColors.categorySleep;
      case 'activity':
        return AppColors.categoryActivity;
      case 'nutrition':
        return AppColors.categoryNutrition;
      case 'overall':
      default:
        return AppColors.primary;
    }
  }
}

// ── Sleep: horizontal stacked stages bar ─────────────────────────────────────

class _SleepStagesChart extends StatelessWidget {
  const _SleepStagesChart();

  // Typical healthy sleep stage breakdown. Percentages sum to 100.
  static const List<_Stage> _stages = [
    _Stage(label: 'Deep',  percent: 0.18, color: Color(0xFF3B3A9A)),
    _Stage(label: 'REM',   percent: 0.22, color: Color(0xFF5E5CE6)),
    _Stage(label: 'Light', percent: 0.50, color: Color(0xFF8A88EE)),
    _Stage(label: 'Awake', percent: 0.10, color: Color(0xFFB8B6F4)),
  ];

  static const double _barHeight = 24;
  static const double _barRadius = 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '8h',
              style: AppTextStyles.displayMedium.copyWith(
                color: AppColors.warmWhite,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'target',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd - 4),
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(_barRadius),
          child: SizedBox(
            height: _barHeight,
            child: Row(
              children: [
                for (final stage in _stages)
                  Expanded(
                    flex: (stage.percent * 1000).round(),
                    child: Container(color: stage.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Legend
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final stage in _stages) _LegendDot(stage: stage),
          ],
        ),
      ],
    );
  }
}

class _Stage {
  const _Stage({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final double percent;
  final Color color;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.stage});
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: stage.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          stage.label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondaryDark,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Activity: 7-day step bar chart ───────────────────────────────────────────

class _ActivityWeekChart extends StatelessWidget {
  const _ActivityWeekChart();

  // Mock realistic step counts across a week — picks the minimum to
  // show a meaningful spread.
  static const List<int> _weeklySteps = [
    8200, 9100, 7800, 10200, 8900, 11500, 7600,
  ];
  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const int _target = 10000;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSteps = _weeklySteps.reduce(math.max);
        final chartMax = math.max(maxSteps, _target);

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ActivityBarsPainter(
            steps: _weeklySteps,
            target: _target,
            chartMax: chartMax,
            dayLabels: _dayLabels,
          ),
        );
      },
    );
  }
}

class _ActivityBarsPainter extends CustomPainter {
  _ActivityBarsPainter({
    required this.steps,
    required this.target,
    required this.chartMax,
    required this.dayLabels,
  });

  final List<int> steps;
  final int target;
  final int chartMax;
  final List<String> dayLabels;

  static const double _barWidth = 12;
  static const double _barRadius = 3;
  static const double _labelHeight = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final chartBottom = size.height - _labelHeight;
    final chartTop = 4.0;
    final plotHeight = chartBottom - chartTop;

    // Target line (dashed sage).
    final targetY = chartBottom -
        (target / chartMax) * plotHeight;
    final dashPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    var dashX = 0.0;
    while (dashX < size.width) {
      canvas.drawLine(
        Offset(dashX, targetY),
        Offset(dashX + 4, targetY),
        dashPaint,
      );
      dashX += 8;
    }

    // Bars.
    final slotWidth = size.width / steps.length;
    final barPaint = Paint()..color = AppColors.categoryActivity;
    final peakPaint = Paint()..color = AppColors.primary;

    final peakIndex = steps.indexWhere(
      (s) => s == steps.reduce(math.max),
    );

    for (var i = 0; i < steps.length; i++) {
      final h = (steps[i] / chartMax) * plotHeight;
      final x = i * slotWidth + (slotWidth - _barWidth) / 2;
      final y = chartBottom - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, _barWidth, h),
        const Radius.circular(_barRadius),
      );
      canvas.drawRRect(rect, i == peakIndex ? peakPaint : barPaint);

      // Day label below.
      final textPainter = TextPainter(
        text: TextSpan(
          text: dayLabels[i],
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondaryDark,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          i * slotWidth + (slotWidth - textPainter.width) / 2,
          chartBottom + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityBarsPainter oldDelegate) =>
      oldDelegate.steps != steps ||
      oldDelegate.target != target ||
      oldDelegate.chartMax != chartMax;
}

// ── Nutrition: macro doughnut ────────────────────────────────────────────────

class _NutritionMacroDonut extends StatelessWidget {
  const _NutritionMacroDonut();

  // Approx daily macro split in grams. Calories-per-gram: P=4, C=4, F=9.
  // Visualized by energy share, not gram share.
  static const double _proteinG = 130;
  static const double _carbsG   = 220;
  static const double _fatG     = 70;

  @override
  Widget build(BuildContext context) {
    final proteinCal = _proteinG * 4;
    final carbsCal   = _carbsG   * 4;
    final fatCal     = _fatG     * 9;
    final totalCal   = proteinCal + carbsCal + fatCal;

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: [
                _DonutSegment(
                  value: proteinCal / totalCal,
                  color: AppColors.categoryHeart,
                ),
                _DonutSegment(
                  value: carbsCal / totalCal,
                  color: AppColors.categoryActivity,
                ),
                _DonutSegment(
                  value: fatCal / totalCal,
                  color: AppColors.categoryNutrition,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${totalCal.round()}',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.warmWhite,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'cal',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondaryDark,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spaceLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MacroLegendRow(
                label: 'Protein',
                grams: _proteinG,
                color: AppColors.categoryHeart,
              ),
              const SizedBox(height: 6),
              _MacroLegendRow(
                label: 'Carbs',
                grams: _carbsG,
                color: AppColors.categoryActivity,
              ),
              const SizedBox(height: 6),
              _MacroLegendRow(
                label: 'Fat',
                grams: _fatG,
                color: AppColors.categoryNutrition,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutSegment {
  const _DonutSegment({required this.value, required this.color});
  final double value; // 0..1
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments});

  final List<_DonutSegment> segments;

  static const double _strokeWidth = 10;
  static const double _gapRadians = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - _strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -math.pi / 2 + _gapRadians / 2;
    for (final seg in segments) {
      final sweep = seg.value * 2 * math.pi - _gapRadians;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += seg.value * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class _MacroLegendRow extends StatelessWidget {
  const _MacroLegendRow({
    required this.label,
    required this.grams,
    required this.color,
  });

  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.warmWhite,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Text(
          '${grams.round()}g',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ── Overall: four concentric pillar rings ────────────────────────────────────

class _WellnessRingsChart extends StatelessWidget {
  const _WellnessRingsChart();

  // Mock pillar scores.
  static const List<_PillarRing> _rings = [
    _PillarRing(label: 'Sleep',     value: 0.80, color: AppColors.categorySleep),
    _PillarRing(label: 'Activity',  value: 0.65, color: AppColors.categoryActivity),
    _PillarRing(label: 'Nutrition', value: 0.72, color: AppColors.categoryNutrition),
    _PillarRing(label: 'Wellness',  value: 0.88, color: AppColors.categoryWellness),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _ConcentricRingsPainter(rings: _rings),
          ),
        ),
        const SizedBox(width: AppDimens.spaceLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final r in _rings) ...[
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: r.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        r.label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warmWhite,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    Text(
                      '${(r.value * 100).round()}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PillarRing {
  const _PillarRing({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value; // 0..1
  final Color color;
}

class _ConcentricRingsPainter extends CustomPainter {
  _ConcentricRingsPainter({required this.rings});

  final List<_PillarRing> rings;

  static const double _strokeWidth = 5;
  static const double _ringGap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = (size.shortestSide / 2) - _strokeWidth;

    for (var i = 0; i < rings.length; i++) {
      final radius = outer - i * (_strokeWidth + _ringGap);
      final rect = Rect.fromCircle(center: center, radius: radius);

      final trackPaint = Paint()
        ..color = rings[i].color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
      canvas.drawCircle(center, radius, trackPaint);

      final arcPaint = Paint()
        ..color = rings[i].color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweep = rings[i].value * 2 * math.pi;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) =>
      oldDelegate.rings != rings;
}
