/// Horizontal milestone track for the Goal Detail page.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/goal_metrics.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

class GoalMilestonesTrack extends StatelessWidget {
  const GoalMilestonesTrack({super.key, required this.goal});

  final Goal goal;

  /// Width allotted to each pin's centered column (dot + label + date).
  /// Sized to fit "~ Apr 27" without wrapping at fontSize 8.
  static const double _pinWidth = 56;
  static const double _pinHalfWidth = _pinWidth / 2;

  @override
  Widget build(BuildContext context) {
    final visuals = goalVisuals(goal);
    final reached = milestonesReached(goal);
    final pct = (goal.currentValue / goal.targetValue).clamp(0.0, 1.0);
    final projected = projectedEndDate(goal);

    return ZFeatureCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: SizedBox(
        height: 60,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Inset the track and pin range so pins don't overflow the card edges.
          final trackWidth = (width - _pinWidth).clamp(0.0, width);
          return Stack(
            children: [
              // Background track — runs between pin centers (inset).
              Positioned(
                left: _pinHalfWidth,
                right: _pinHalfWidth,
                top: 18,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              // Filled portion — proportional to current progress, anchored at the START pin's center.
              Positioned(
                left: _pinHalfWidth,
                top: 18,
                width: trackWidth * pct,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        visuals.color,
                        Color.lerp(Colors.white, visuals.color, 0.6) ?? visuals.color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              // Pins — each in a fixed-width column so labels stay centered and inside the card.
              for (final pin in _pins(visuals, reached, projected))
                Positioned(
                  left: pin.fraction * trackWidth,
                  top: 8,
                  width: _pinWidth,
                  child: _Pin(data: pin),
                ),
            ],
          );
        }),
      ),
    );
  }

  static List<_PinData> _pins(GoalVisuals v, int reached, DateTime? projected) {
    String dateLabel(int i) {
      if (i < 4) {
        const labels = ['Day 1', 'reached', 'reached', 'reached'];
        return labels[i];
      }
      if (projected == null) return '—';
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '~ ${months[projected.month - 1]} ${projected.day}';
    }
    return [
      _PinData(label: 'START', date: dateLabel(0), fraction: 0.0, done: true, color: v.color),
      _PinData(label: '25%', date: reached >= 1 ? 'reached' : '—', fraction: 0.25, done: reached >= 1, color: v.color),
      _PinData(label: '50%', date: reached >= 2 ? 'reached' : '—', fraction: 0.5, done: reached >= 2, color: v.color),
      _PinData(label: '75%', date: reached >= 3 ? 'reached' : '—', fraction: 0.75, done: reached >= 3, color: v.color),
      _PinData(label: '100%', date: dateLabel(4), fraction: 1.0, done: reached >= 4, color: v.color),
    ];
  }
}

class _PinData {
  const _PinData({
    required this.label,
    required this.date,
    required this.fraction,
    required this.done,
    required this.color,
  });
  final String label;
  final String date;
  final double fraction;
  final bool done;
  final Color color;
}

class _Pin extends StatelessWidget {
  const _Pin({required this.data});
  final _PinData data;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: data.done ? data.color : AppColors.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.canvas, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            data.done ? '✓' : '⌖',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: data.done ? AppColors.canvas : colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.label,
          style: AppTextStyles.labelSmall.copyWith(
            color: data.done ? Color.lerp(Colors.white, data.color, 0.6) : colors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
        Text(
          data.date,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}
