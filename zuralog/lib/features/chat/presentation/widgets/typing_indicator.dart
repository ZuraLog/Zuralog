/// Zuralog Edge Agent — Typing Indicator Widget.
///
/// Animated three-dot indicator shown while the AI assistant is composing
/// a response. The dots animate with staggered vertical bounces using
/// an [AnimationController] and three [CurvedAnimation]s.
///
/// Styled identically to an AI message bubble: [AppColors.aiBubbleDark] /
/// [AppColors.aiBubbleLight] background, same border radii, and a small
/// bot avatar circle on the left.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

// ── Typing Indicator ──────────────────────────────────────────────────────────

/// A three-bouncing-dot animation widget styled as an AI message bubble.
///
/// Displays a bot avatar on the left and three animated dots to the right.
/// The dots bounce vertically with staggered 150ms delays, driven by a
/// looping [AnimationController].
///
/// The [AnimationController] is disposed in [State.dispose].
class TypingIndicator extends StatefulWidget {
  /// Creates a [TypingIndicator].
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  /// Primary animation controller driving all three dot animations.
  late final AnimationController _controller;

  /// Individual bounce animations for each of the three dots.
  late final List<Animation<double>> _dotAnims;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Stagger each dot by 150ms within the 900ms cycle.
    _dotAnims = List.generate(3, (i) {
      final begin = i * 0.15; // 0.0, 0.15, 0.30
      final end = begin + 0.4; // 0.4, 0.55, 0.70
      return Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(begin, end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor =
        isDark ? AppColors.aiBubbleDark : AppColors.aiBubbleLight;
    final dotColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Bot Avatar ─────────────────────────────────────────────────
          _BotAvatar(isDark: isDark),
          const SizedBox(width: AppDimens.spaceSm),

          // ── Bubble with animated dots ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4), // flat corner — AI side
                bottomRight: Radius.circular(20),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < 2 ? AppDimens.spaceXs : 0,
                      ),
                      child: Transform.translate(
                        offset: Offset(0, _dotAnims[i].value),
                        child: _Dot(color: dotColor),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// A small circular dot used inside the typing indicator bubble.
///
/// [color] is the fill color of the dot.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  /// The fill color of the dot.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A small circular avatar representing the AI bot.
///
/// [isDark] controls whether dark-mode colors are applied.
class _BotAvatar extends StatelessWidget {
  const _BotAvatar({required this.isDark});

  /// Whether dark-mode colors should be used.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: const Icon(
        Icons.psychology_rounded,
        color: AppColors.primary,
        size: 16,
      ),
    );
  }
}
