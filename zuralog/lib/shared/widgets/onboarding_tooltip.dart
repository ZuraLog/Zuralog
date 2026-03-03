/// Zuralog — OnboardingTooltip widget.
///
/// Renders a contextual coaching bubble anchored to a target widget.
/// Shows once per screen key, then persists the "seen" state in
/// [SharedPreferences]. Sequential display is enforced per screen:
/// only one tooltip is visible at a time.
///
/// ## Usage
/// ```dart
/// OnboardingTooltip(
///   screenKey: 'today_feed',
///   tooltipKey: 'health_score',
///   message: 'This is your daily health score.',
///   child: HealthScoreWidget(...),
/// )
/// ```
///
/// ## Design spec
/// - Background: `surface-700` equivalent (`#3A3A3C` dark, `#EBEBF0` light)
/// - Body text: `AppTextStyles.caption`
/// - Border radius: 12
/// - Pointer arrow: 8px equilateral triangle below the bubble
/// - "Got it" dismiss button: `AppColors.primary` text
/// - Max width: 240px
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'onboarding_tooltip_provider.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const double _kMaxWidth = 240.0;
const double _kBorderRadius = 12.0;
const double _kArrowSize = 8.0;
const EdgeInsets _kPadding =
    EdgeInsets.symmetric(horizontal: 14, vertical: 10);

// ── OnboardingTooltip ─────────────────────────────────────────────────────────

/// Wraps [child] with an optional onboarding coaching bubble.
///
/// The bubble is shown automatically when the screen/key combination has not
/// been seen before. Tapping "Got it" dismisses it and persists the seen state.
///
/// [screenKey] — unique identifier for the screen (e.g. `'today_feed'`).
/// [tooltipKey] — unique identifier for this tooltip within the screen
///               (e.g. `'health_score'`). Combined with [screenKey] to form
///               the persistence key.
/// [message] — the coaching text displayed in the bubble.
/// [preferBelow] — when `true` the bubble renders above and the arrow points
///                 down; when `false` the bubble is below with arrow above.
///                 Defaults to `true` (bubble above child).
class OnboardingTooltip extends ConsumerWidget {
  /// Creates an [OnboardingTooltip].
  const OnboardingTooltip({
    super.key,
    required this.screenKey,
    required this.tooltipKey,
    required this.message,
    required this.child,
    this.preferBelow = false,
  });

  /// Screen-level namespace for this tooltip.
  final String screenKey;

  /// Tooltip-level key within the screen namespace.
  final String tooltipKey;

  /// The coaching text to display.
  final String message;

  /// The widget the tooltip is anchored above (or below).
  final Widget child;

  /// When `false` (default), bubble renders above the child (arrow points down).
  /// When `true`, bubble renders below the child (arrow points up).
  final bool preferBelow;

  String get _persistenceKey => '$screenKey.$tooltipKey';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tooltipSeenProvider.notifier);
    final tooltipsEnabled =
        ref.watch(tooltipsEnabledProvider).valueOrNull ?? true;
    final seenMap =
        ref.watch(tooltipSeenProvider).valueOrNull ?? const <String, bool>{};
    final isSeen = seenMap[_persistenceKey] ?? false;

    if (!tooltipsEnabled || isSeen) return child;

    return _TooltipOverlay(
      message: message,
      preferBelow: preferBelow,
      onDismiss: () => notifier.markSeen(_persistenceKey),
      child: child,
    );
  }
}

// ── _TooltipOverlay ───────────────────────────────────────────────────────────

/// Internal widget that stacks the tooltip bubble above/below the child.
class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.message,
    required this.preferBelow,
    required this.onDismiss,
    required this.child,
  });

  final String message;
  final bool preferBelow;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEBEBF0);
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxWidth),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: _kPadding,
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(_kBorderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: AppTextStyles.caption.copyWith(color: textColor),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Got it',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final arrow = CustomPaint(
      size: const Size(_kArrowSize * 2, _kArrowSize),
      painter: _ArrowPainter(
        color: bubbleBg,
        pointingDown: !preferBelow,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: preferBelow
          ? [child, const SizedBox(height: 4), arrow, bubble]
          : [bubble, arrow, const SizedBox(height: 4), child],
    );
  }
}

// ── _ArrowPainter ─────────────────────────────────────────────────────────────

/// Paints a small equilateral triangle arrow for the tooltip pointer.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.pointingDown});

  final Color color;
  final bool pointingDown;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (pointingDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color || old.pointingDown != pointingDown;
}
