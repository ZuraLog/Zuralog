/// Zuralog — Health Score Strip widget.
///
/// Compact horizontal strip showing the current health score, 7-day trend
/// stats, a delta badge, and a chevron to navigate to the score breakdown.
///
/// States:
/// - Loading  → shimmer skeleton row
/// - No data  → gray ring, "—" score, "Not enough data yet" subtitle
/// - Error    → same as no-data state
/// - Has data → score ring with color-coded fill, score number, avg · range
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

// ── HealthScoreStrip ──────────────────────────────────────────────────────────

/// Compact strip widget showing the user's health score and 7-day stats.
///
/// Tapping anywhere on the strip navigates to `/data/score`.
class HealthScoreStrip extends ConsumerWidget {
  const HealthScoreStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(healthScoreProvider);
    final colors = AppColorsOf(context);

    final semanticLabel = scoreAsync.when(
      loading: () => 'Health score. Loading.',
      error: (err, st) => 'Health score: not enough data yet. Tap to view breakdown.',
      data: (scoreData) {
        if (scoreData.score == 0) {
          return 'Health score: not enough data yet. Tap to view breakdown.';
        }
        return 'Health score: ${scoreData.score} out of 100. Tap to view breakdown.';
      },
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/data/score-breakdown'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
            ),
            child: Stack(
              children: [
                // Hero pattern — brand bible: "Hero: Health Score summary"
                const Positioned.fill(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.original,
                    opacity: 0.18,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: scoreAsync.when(
                    loading: () => const _SkeletonRow(),
                    error: (e, _) => const _ScoreRow(data: null),
                    data: (data) => _ScoreRow(data: data),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _ScoreRow ─────────────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.data});

  /// `null` means error state — treated same as no-score.
  final HealthScoreData? data;

  static bool _isNoScore(HealthScoreData? d) =>
      d == null || (d.score == 0 && d.dataDays == 0);

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final noScore = _isNoScore(data);
    final score = data?.score ?? 0;
    final ringColor =
        noScore ? colors.textTertiary : _scoreColor(score);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Score ring ──────────────────────────────────────────────
        SizedBox(
          width: 36,
          height: 36,
          child: CustomPaint(
            key: const ValueKey('score_ring'),
            painter: _ScoreRingPainter(
              value: noScore ? 0.0 : score / 100.0,
              color: ringColor,
              trackColor: colors.border,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Score number + label ────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              noScore ? '—' : '$score',
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Health Score',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),

        const Spacer(),

        // ── Right side: stats / subtitle ────────────────────────────
        if (noScore)
          Text(
            'Not enough data yet',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 11,
              color: colors.textTertiary,
            ),
          )
        else ...[
          _StatsText(data: data!),
          const SizedBox(width: 6),
          _DeltaBadge(weekChange: data?.weekChange),
        ],
        const SizedBox(width: 6),

        // ── Chevron ─────────────────────────────────────────────────
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: colors.textTertiary,
        ),
      ],
    );
  }
}

// ── _StatsText ────────────────────────────────────────────────────────────────

class _StatsText extends StatelessWidget {
  const _StatsText({required this.data});
  final HealthScoreData data;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final trend = data.trend;

    // Compute 7-day avg, min, max from trend list if available.
    if (trend.isEmpty) {
      return const SizedBox.shrink();
    }

    final nonZero = trend.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    final avg = (nonZero.reduce((a, b) => a + b) / nonZero.length).round();
    final minVal = nonZero.reduce(math.min).round();
    final maxVal = nonZero.reduce(math.max).round();

    return Text(
      '$avg avg · $minVal–$maxVal',
      style: AppTextStyles.labelSmall.copyWith(
        fontSize: 11,
        color: colors.textTertiary,
      ),
    );
  }
}

// ── _DeltaBadge ───────────────────────────────────────────────────────────────

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.weekChange});
  final int? weekChange;

  @override
  Widget build(BuildContext context) {
    final delta = weekChange;
    if (delta == null) return const SizedBox.shrink();

    final isPositive = delta >= 0;
    final color =
        isPositive ? AppColors.healthScoreGreen : AppColors.healthScoreRed;
    final label = isPositive ? '↑$delta' : '↓${delta.abs()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── _SkeletonRow ──────────────────────────────────────────────────────────────

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score ring circle
          ShimmerBox(height: 36, width: 36, isCircle: true),
          const SizedBox(width: 10),
          // Score number + "Health Score" label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(height: 18, width: 32),
              const SizedBox(height: 4),
              ShimmerBox(height: 12, width: 72),
            ],
          ),
          const Spacer(),
          // Stats text area
          ShimmerBox(height: 12, width: 80),
          const SizedBox(width: 12),
          // Chevron placeholder
          ShimmerBox(height: 18, width: 18),
        ],
      ),
    );
  }
}

// ── _ScoreRingPainter ─────────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  /// Progress value 0.0–1.0.
  final double value;
  final Color color;
  final Color trackColor;

  static const double _strokeWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 o'clock

    // Track (background arc).
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    // Progress arc.
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor;
}

// ── _scoreColor ───────────────────────────────────────────────────────────────

Color _scoreColor(int score) {
  if (score >= 70) return AppColors.healthScoreGreen;
  if (score >= 40) return AppColors.healthScoreAmber;
  return AppColors.healthScoreRed;
}
