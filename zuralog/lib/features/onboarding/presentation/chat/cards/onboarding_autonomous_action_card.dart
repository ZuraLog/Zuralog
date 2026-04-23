/// Zuralog — Onboarding Autonomous Action Card.
///
/// Mid-conversation card that showcases the coach's *autonomous action*
/// capability — three tasks check off one-by-one in real time with a
/// sage ring that fills, then collapses into a checkmark. This is the
/// "look what the AI does for you" moment.
///
/// The card runs once on mount and then sits in its "done" state. It
/// does not re-animate on rebuild, so returning to the chat won't
/// replay the animation.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingAutonomousActionCard extends StatefulWidget {
  const OnboardingAutonomousActionCard({
    super.key,
    required this.focusLabel,
  });

  /// The user's picked focus — used to personalize task #2 ("Setting
  /// [focusLabel] as your priority").
  final String focusLabel;

  @override
  State<OnboardingAutonomousActionCard> createState() =>
      _OnboardingAutonomousActionCardState();
}

class _OnboardingAutonomousActionCardState
    extends State<OnboardingAutonomousActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // One controller drives the whole card. Each task gets a 1/3 slice.
  static const Duration _totalDuration = Duration(milliseconds: 3800);

  // Card styling.
  static const double _cardRadius = 22;

  // Per-task sub-timeline within its 1/3 slice:
  //   0.00 → 0.15  fade in + slide up 10 px
  //   0.15 → 0.75  ring fills sage
  //   0.75 → 1.00  ring collapses to a sage check circle
  static const double _phaseAppearStart = 0.00;
  static const double _phaseAppearEnd = 0.15;
  static const double _phaseRingEnd = 0.75;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks(widget.focusLabel);

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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'SETTING UP YOUR COACH',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < tasks.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == tasks.length - 1
                            ? 0
                            : AppDimens.spaceMd - 4,
                      ),
                      child: _TaskRow(
                        label: tasks[i],
                        localProgress: _progressForTask(i, tasks.length),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Normalizes the overall progress [_controller.value] into a [0, 1]
  /// slice for task index [i]. Outside the task's window the clamped
  /// value is 0 (before) or 1 (after).
  double _progressForTask(int i, int total) {
    final slice = 1.0 / total;
    final start = i * slice;
    final local = (_controller.value - start) / slice;
    return local.clamp(0.0, 1.0);
  }

  /// The three tasks the coach performs. Personalized to the user's
  /// focus. Kept short — each line has to fit one row comfortably.
  List<String> _tasks(String focusLabel) {
    return [
      'Creating your profile',
      'Setting $focusLabel as your priority',
      'Scheduling your morning briefing',
    ];
  }
}

/// One row in the task list. Drives its own icon animation based on the
/// [localProgress] value (0..1) the parent hands in.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.label,
    required this.localProgress,
  });

  final String label;
  final double localProgress;

  static const double _iconSize = 22;
  static const double _rowHeight = 28;

  @override
  Widget build(BuildContext context) {
    // Appear phase — fade + slide-up as the task enters.
    final appear = _curved(
      localProgress,
      _OnboardingAutonomousActionCardState._phaseAppearStart,
      _OnboardingAutonomousActionCardState._phaseAppearEnd,
    );

    return Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(0, (1.0 - appear) * 10),
        child: SizedBox(
          height: _rowHeight,
          child: Row(
            children: [
              SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: _TaskIcon(localProgress: localProgress),
              ),
              const SizedBox(width: AppDimens.spaceMd - 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: localProgress >= 1.0
                        ? AppColors.warmWhite
                        : AppColors.warmWhite.withValues(alpha: 0.82),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clamp + normalize [t] into the window [start, end].
  static double _curved(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }
}

/// The animated sage ring that fills, then snaps into a check mark.
class _TaskIcon extends StatelessWidget {
  const _TaskIcon({required this.localProgress});

  final double localProgress;

  @override
  Widget build(BuildContext context) {
    final ringProgress = _curved(
      localProgress,
      _OnboardingAutonomousActionCardState._phaseAppearEnd,
      _OnboardingAutonomousActionCardState._phaseRingEnd,
    );
    final isComplete =
        localProgress >= _OnboardingAutonomousActionCardState._phaseRingEnd;
    final checkScale = _curved(
      localProgress,
      _OnboardingAutonomousActionCardState._phaseRingEnd,
      1.0,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: isComplete
          ? _CheckIcon(
              key: const ValueKey('done'),
              scale: checkScale,
            )
          : _RingIcon(
              key: const ValueKey('ring'),
              progress: ringProgress,
            ),
    );
  }

  static double _curved(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }
}

/// Ring that fills clockwise from 0 to [progress].
class _RingIcon extends StatelessWidget {
  const _RingIcon({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        progress: progress,
        color: AppColors.primary,
        trackColor: AppColors.warmWhite.withValues(alpha: 0.12),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  static const double _strokeWidth = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - _strokeWidth;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    // Sweep clockwise from the top.
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = progress * 2 * 3.1415926535;
    canvas.drawArc(rect, -1.5707963267, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// The filled sage circle + check mark that replaces the ring once the
/// task is done. [scale] is the entrance animation value.
class _CheckIcon extends StatelessWidget {
  const _CheckIcon({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = 0.85 + 0.15 * scale; // gentle scale-in from 0.85 to 1.0
    return Transform.scale(
      scale: s,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.check_rounded,
          size: 14,
          color: Color(0xFF1A2E22),
        ),
      ),
    );
  }
}
