/// Zuralog Design System — Log Ring Widget.
///
/// A circular progress ring showing how many of the user's active log types
/// have been logged today. Tapping opens the log grid sheet.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/loading/z_loading_skeleton.dart';

/// Circular ring showing today's log completion.
///
/// [onTap] — called when the ring is tapped. The caller should open the
///   log grid sheet.
class ZLogRingWidget extends ConsumerWidget {
  const ZLogRingWidget({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringAsync = ref.watch(logRingProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColorsOf(context).cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColorsOf(context).border),
        ),
        child: ringAsync.when(
          loading: () => const _RingLoading(),
          error: (e, _) => const _RingError(),
          data: (state) => _RingContent(state: state),
        ),
      ),
    );
  }
}

// ── Content states ────────────────────────────────────────────────────────────

class _RingContent extends StatelessWidget {
  const _RingContent({required this.state});

  final LogRingState state;

  @override
  Widget build(BuildContext context) {
    final isEmpty = state.totalCount == 0;
    final colors = AppColorsOf(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(80, 80),
                painter: _RingPainter(
                  fraction: state.fraction,
                  trackColor: AppColors.primary.withValues(alpha: 0.12),
                  fillColor: AppColors.primary,
                ),
              ),
              if (isEmpty)
                Icon(
                  Icons.add_rounded,
                  color: colors.primary,
                  size: 24,
                )
              else
                Text(
                  '${state.loggedCount} / ${state.totalCount}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          isEmpty ? 'Start logging →' : 'logged today',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RingLoading extends StatelessWidget {
  const _RingLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ZLoadingSkeleton(width: 80, height: 80, borderRadius: 40),
        SizedBox(height: AppDimens.spaceSm),
        ZLoadingSkeleton(width: 60, height: 12),
      ],
    );
  }
}

class _RingError extends StatelessWidget {
  const _RingError();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.refresh_rounded,
      color: AppColorsOf(context).textTertiary,
      size: AppDimens.iconMd,
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
  });

  final double fraction;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.1;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    // Track (background ring).
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Fill (progress arc).
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}
