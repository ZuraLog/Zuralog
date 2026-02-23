/// Zuralog Dashboard — AI Insight Card Widget.
///
/// Renders the hero AI-insight card at the top of the Dashboard screen.
/// Uses a deep forest-to-teal diagonal gradient background to convey
/// intelligence and depth. A shimmer placeholder is shown while the
/// insight is loading.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';

// ── Gradient constants ────────────────────────────────────────────────────────

/// Gradient stops for the insight card (same in light and dark modes — the
/// deep forest colours are dark enough to look great on both backgrounds).
const List<Color> _kInsightGradient = [
  Color(0xFF2D4A2D), // Deep forest green
  Color(0xFF1E3A3A), // Dark teal
  Color(0xFF3D5A4A), // Sage-forest blend
];

// ── Main widget ───────────────────────────────────────────────────────────────

/// The AI Insight hero card.
///
/// Displays the [insight] text over a premium diagonal gradient background.
/// Tapping the card invokes [onTap], typically navigating to the chat screen.
///
/// When [insight] is `null`, a loading shimmer placeholder is rendered with
/// the same dimensions to prevent layout shift.
///
/// Example:
/// ```dart
/// InsightCard(
///   insight: DashboardInsight(insight: 'You slept 8 hours last night…'),
///   onTap: () => context.go(RouteNames.chatPath),
/// )
/// ```
class InsightCard extends StatelessWidget {
  /// Creates an [InsightCard].
  ///
  /// [insight] is required; pass `null` to render the loading shimmer.
  /// [onTap] is optional but strongly recommended for navigation.
  const InsightCard({
    super.key,
    required this.insight,
    this.onTap,
  });

  /// The AI-generated insight data to display.
  final DashboardInsight insight;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              gradient: const LinearGradient(
                colors: _kInsightGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Label row ────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: AppDimens.iconSm,
                      color: Colors.white,
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    Text(
                      'AI Insight',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimens.spaceMd),

                // ── Insight text ─────────────────────────────────────────
                Expanded(
                  child: Text(
                    insight.insight,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ── Tap hint ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Chat with Coach',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

/// Loading placeholder for [InsightCard].
///
/// Rendered while [dashboardInsightProvider] is in the loading state.
/// Matches [InsightCard]'s dimensions to prevent layout shift.
class InsightCardShimmer extends StatefulWidget {
  /// Creates an [InsightCardShimmer].
  const InsightCardShimmer({super.key});

  @override
  State<InsightCardShimmer> createState() => _InsightCardShimmerState();
}

/// Animates a pulsing opacity effect on the gradient placeholder.
class _InsightCardShimmerState extends State<InsightCardShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              gradient: const LinearGradient(
                colors: _kInsightGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      },
    );
  }
}
