/// Zuralog — HealthScoreWidget.
///
/// Animated ring/gauge displaying a composite health score (0-100).
///
/// ## Size variants
/// - **hero**: 120pt diameter ring. Includes 7-day trend sparkline and AI
///   commentary text slot below the ring.
/// - **compact**: 48pt diameter ring. Ring + score number only.
///
/// ## Color stops
/// | Score | Color            | Token                   |
/// |-------|------------------|-------------------------|
/// | 0-39  | Red  (#FF3B30)   | AppColors.healthScoreRed   |
/// | 40-69 | Amber (#FF9F0A)  | AppColors.healthScoreAmber |
/// | 70-100| Green (#30D158)  | AppColors.healthScoreGreen |
///
/// ## Animation
/// 800ms `easeOutCubic` fill animation on initial load and score change.
///
/// ## Usage
/// ```dart
/// HealthScoreWidget.hero(
///   score: 82,
///   trend: [74, 78, 80, 79, 83, 81, 82],
///   commentary: 'Great consistency this week.',
///   onTap: () => context.push('/data'),
/// )
///
/// HealthScoreWidget.compact(score: 82)
/// ```
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Hero ring outer diameter.
const double _kHeroDiameter = 120.0;

/// Compact ring outer diameter.
const double _kCompactDiameter = 48.0;

/// Ring stroke width as a fraction of diameter.
const double _kStrokeFraction = 0.12;

/// Fill animation duration.
const Duration _kAnimDuration = Duration(milliseconds: 800);

// ── HealthScoreWidget ─────────────────────────────────────────────────────────

/// Animated ring/gauge for the Zuralog health score.
class HealthScoreWidget extends StatelessWidget {
  // ── Constructors ───────────────────────────────────────────────────────────

  /// Hero variant — 120pt ring with sparkline and commentary.
  const HealthScoreWidget.hero({
    super.key,
    required this.score,
    this.trend,
    this.commentary,
    this.onTap,
  })  : _diameter = _kHeroDiameter,
        _showSparkline = true,
        _showCommentary = true;

  /// Compact variant — 48pt ring with score number only.
  const HealthScoreWidget.compact({
    super.key,
    required this.score,
    this.onTap,
  })  : _diameter = _kCompactDiameter,
        _showSparkline = false,
        _showCommentary = false,
        trend = null,
        commentary = null;

  // ── Properties ─────────────────────────────────────────────────────────────

  /// Health score 0-100. Null renders an empty/loading ring.
  final int? score;

  /// 7-day trend values (oldest first). Used for sparkline in hero variant.
  final List<double>? trend;

  /// AI commentary string displayed below the sparkline (hero variant only).
  final String? commentary;

  /// Optional tap callback — wraps widget in [GestureDetector] when provided.
  final VoidCallback? onTap;

  final double _diameter;
  final bool _showSparkline;
  final bool _showCommentary;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the ring fill color for [value] based on health score thresholds.
  static Color colorForScore(int? value) {
    if (value == null) return AppColors.textTertiary;
    if (value <= 39) return AppColors.healthScoreRed;
    if (value <= 69) return AppColors.healthScoreAmber;
    return AppColors.healthScoreGreen;
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = colorForScore(score);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget ring = _AnimatedRing(
      score: score,
      diameter: _diameter,
      ringColor: ringColor,
      textColor: textColor,
    );

    Widget content = ring;

    if (_showSparkline || _showCommentary) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ring,
          if (_showSparkline && trend != null && trend!.length >= 2) ...[
            const SizedBox(height: 12),
            _Sparkline(values: trend!, color: ringColor),
          ],
          if (_showCommentary && commentary != null) ...[
            const SizedBox(height: 8),
            Text(
              commentary!,
              style: AppTextStyles.caption.copyWith(color: secondaryColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// ── _AnimatedRing ─────────────────────────────────────────────────────────────

/// Internal widget that drives the 800ms easeOutCubic fill animation.
class _AnimatedRing extends StatefulWidget {
  const _AnimatedRing({
    required this.score,
    required this.diameter,
    required this.ringColor,
    required this.textColor,
  });

  final int? score;
  final double diameter;
  final Color ringColor;
  final Color textColor;

  @override
  State<_AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<_AnimatedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kAnimDuration);
    _buildAnimation(widget.score);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedRing old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _buildAnimation(widget.score, from: old.score);
      _ctrl
        ..reset()
        ..forward();
    }
  }

  void _buildAnimation(int? newScore, {int? from}) {
    final begin = from != null ? (from / 100.0) : 0.0;
    final end = newScore != null ? (newScore / 100.0).clamp(0.0, 1.0) : 0.0;
    _progress = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strokeWidth = widget.diameter * _kStrokeFraction;
    final colors = AppColorsOf(context);
    final trackColor = colors.cardBackground.withValues(alpha: 0.3);

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _progress.value,
              ringColor: widget.ringColor,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: widget.score != null
                  ? Text(
                      '${widget.score}',
                      style: widget.diameter >= 80
                          ? AppTextStyles.h1.copyWith(
                              color: widget.textColor,
                              fontSize: widget.diameter * 0.28,
                              fontWeight: FontWeight.w700,
                            )
                          : AppTextStyles.caption.copyWith(
                              color: widget.textColor,
                              fontWeight: FontWeight.w700,
                            ),
                    )
                  : SizedBox(
                      width: widget.diameter * 0.2,
                      height: widget.diameter * 0.2,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textTertiary,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ── _RingPainter ──────────────────────────────────────────────────────────────

/// Paints the track and fill arcs for the health score ring.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 o'clock

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw track (full circle).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      trackPaint,
    );

    // Draw fill arc.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

// ── _Sparkline ────────────────────────────────────────────────────────────────

/// 7-day mini trend line rendered with fl_chart's [LineChart].
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return SizedBox(
      height: 28,
      width: _kHeroDiameter,
      child: LineChart(
        LineChartData(
          minY: values.reduce(math.min) - 5,
          maxY: values.reduce(math.max) + 5,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
