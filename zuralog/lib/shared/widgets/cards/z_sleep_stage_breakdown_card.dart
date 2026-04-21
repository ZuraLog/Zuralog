/// Zuralog Design System — Sleep Stage Breakdown Card.
///
/// A dedicated visual for one night's sleep stages — Deep / REM / Light /
/// Awake — rendered as a donut ring with a total-minutes hub and a
/// per-stage legend (minutes + percentage).
///
/// Previously lived privately inside `sleep_insight_body.dart`. Promoted
/// to the shared library so every Sleep-specific surface (Today insight
/// body, Data tab detail screen) can reuse the exact same look.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/animations/z_fade_slide_in.dart';

/// A card that breaks one night's total sleep down into Deep / REM / Light /
/// Awake stages.
///
/// Renders a donut ring for the stage split with the total minutes in the
/// centre and a per-stage legend on the right showing minutes + percentage.
///
/// Callers pass the four stage minute values directly. When every input is
/// `0` the card shows a `—` placeholder — prefer hiding the card upstream
/// if you don't want it to appear at all when there's no data.
class ZSleepStageBreakdownCard extends StatelessWidget {
  /// Creates a [ZSleepStageBreakdownCard].
  const ZSleepStageBreakdownCard({
    super.key,
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
    required this.categoryColor,
    this.title = "Tonight's stages",
    this.delay = const Duration(milliseconds: 120),
  });

  /// Minutes spent in deep sleep.
  final int deepMinutes;

  /// Minutes spent in REM sleep.
  final int remMinutes;

  /// Minutes spent in light sleep.
  final int lightMinutes;

  /// Minutes awake during the night.
  final int awakeMinutes;

  /// Category accent color. Retained on the public API for consistency with
  /// the other insight cards, even though the stage ring uses its own
  /// fixed palette (Deep/REM/Light/Awake) today.
  final Color categoryColor;

  /// Card title.
  final String title;

  /// Stagger delay for the fade-in.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final segments = <_StageSegment>[
      _StageSegment('Deep', deepMinutes, const Color(0xFF2F4A3A)),
      _StageSegment('REM', remMinutes, const Color(0xFF6D9A7A)),
      _StageSegment('Light', lightMinutes, const Color(0xFFCFE1B9)),
      _StageSegment('Awake', awakeMinutes, const Color(0xFFE07A5F)),
    ];
    final total = segments.fold<int>(0, (a, s) => a + s.minutes);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: delay,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _StageRingPainter(
                        segments: segments,
                        trackColor: colors.border.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDuration(total),
                              style: AppTextStyles.titleMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'total',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: colors.textSecondary,
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
                      children: [
                        for (final s in segments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  total > 0
                                      ? '${((s.minutes / total) * 100).round()}%'
                                      : '—',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    _formatDuration(s.minutes),
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internals ────────────────────────────────────────────────────────────────

class _StageSegment {
  const _StageSegment(this.label, this.minutes, this.color);
  final String label;
  final int minutes;
  final Color color;
}

class _StageRingPainter extends CustomPainter {
  _StageRingPainter({required this.segments, required this.trackColor});
  final List<_StageSegment> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - 6;
    const stroke = 12.0;
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, track);
    final total = segments.fold<int>(0, (a, s) => a + s.minutes);
    if (total <= 0) return;
    const gap = 0.04;
    double start = -math.pi / 2;
    for (final s in segments) {
      if (s.minutes <= 0) continue;
      final sweep = (s.minutes / total) * (math.pi * 2);
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        sweep - gap,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StageRingPainter old) =>
      old.segments != segments || old.trackColor != trackColor;
}

String _formatDuration(int minutes) {
  if (minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
