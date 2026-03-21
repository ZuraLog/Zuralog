/// Zuralog — Tile Empty State Widgets.
///
/// State-specific content widgets for metric tiles. Each widget renders the
/// content area of a tile in a particular empty state. They are agnostic of
/// the tile shell — [MetricTile] selects the correct one based on
/// [TileDataState].
///
/// Widgets:
/// - [GhostTileContent]          — TileDataState.noSource
/// - [SyncingTileContent]        — TileDataState.syncing
/// - [NoDataForRangeTileContent] — TileDataState.noDataForRange
/// - [OnboardingEmptyState]      — brand new user (full-screen grid replacement)
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/widgets/shimmer.dart';

// ── GhostTileContent ──────────────────────────────────────────────────────────

/// Content area for a tile in the [TileDataState.noSource] state.
///
/// Renders at 40% opacity with a dashed border, a metric icon, and a
/// "Connect" button.
class GhostTileContent extends StatelessWidget {
  const GhostTileContent({
    super.key,
    required this.categoryColor,
    required this.onConnect,
  });

  final Color categoryColor;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.40,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: categoryColor),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart_rounded,
                color: categoryColor.withValues(alpha: 0.6),
                size: 28,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: AppTextStyles.labelSmall,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _DashedBorderPainter ──────────────────────────────────────────────────────

/// Draws a dashed rectangular border with rounded corners.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const radius = 12.0;
    const dashWidth = 6.0;
    const dashGap = 4.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final remaining = metric.length - distance;
        final segLength = dashWidth < remaining ? dashWidth : remaining;
        canvas.drawPath(
          metric.extractPath(distance, distance + segLength),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── SyncingTileContent ────────────────────────────────────────────────────────

/// Content area for a tile in the [TileDataState.syncing] state.
///
/// Shows an animated shimmer skeleton whose layout mirrors a loaded tile:
/// header row → primary value → unit → chart area.
/// Uses [AppShimmer] for the sweep animation — no own [AnimationController].
class SyncingTileContent extends StatelessWidget {
  const SyncingTileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: category dot + metric name + spacer + emoji icon
          Row(
            children: [
              ShimmerBox(height: 8, width: 8, isCircle: true),
              const SizedBox(width: 6),
              ShimmerBox(height: 8, width: 80),
              const Spacer(),
              ShimmerBox(height: 14, width: 14),
            ],
          ),
          const SizedBox(height: 8),
          // Primary value
          ShimmerBox(height: 28, width: 60),
          const SizedBox(height: 4),
          // Unit label
          ShimmerBox(height: 8, width: 40),
          const SizedBox(height: 8),
          // Chart area — fills remaining height
          Expanded(
            child: ShimmerBox(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NoDataForRangeTileContent ─────────────────────────────────────────────────

/// Content area for a tile in the [TileDataState.noDataForRange] state.
///
/// Shows the most recent known value with a secondary "Last: {relativeTime}"
/// label, identical in appearance to a loaded tile but with no live data for
/// the current time range.
class NoDataForRangeTileContent extends StatelessWidget {
  const NoDataForRangeTileContent({
    super.key,
    required this.lastKnownValue,
    required this.lastUpdated,
  });

  /// The most recent known value string (e.g. "8,432").
  final String lastKnownValue;

  /// ISO-8601 timestamp of the last successful data sync.
  final String lastUpdated;

  /// Returns a human-readable relative time string (e.g. "2d ago").
  ///
  /// [now] defaults to [DateTime.now()]; pass an explicit value in tests to
  /// make the output deterministic.
  String _relativeTime(String iso, {DateTime? now}) {
    final DateTime? dt = DateTime.tryParse(iso);
    if (dt == null) return 'unknown';
    final ref = now ?? DateTime.now();
    final diff = ref.difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final relTime = _relativeTime(lastUpdated);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lastKnownValue,
          style: AppTextStyles.displayMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Last: $relTime',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ── OnboardingEmptyState ──────────────────────────────────────────────────────

/// Full-screen replacement for the tile grid when the user has no data sources.
///
/// Shows a welcome card, a 2-column grid of ghost starter tiles, and
/// primary/secondary CTAs.
class OnboardingEmptyState extends StatelessWidget {
  const OnboardingEmptyState({
    super.key,
    required this.onConnectDevice,
    required this.onLogManually,
  });

  final VoidCallback onConnectDevice;
  final VoidCallback onLogManually;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    const starterTiles = [
      (label: 'Steps', color: AppColors.categoryActivity),
      (label: 'Sleep Duration', color: AppColors.categorySleep),
      (label: 'Weight', color: AppColors.categoryBody),
      (label: 'Mood', color: AppColors.categoryWellness),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Start tracking your health',
                  style: AppTextStyles.displaySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect a device or log your first entry to see your metrics here.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Ghost starter tiles (2-column grid)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final tile in starterTiles)
                SizedBox(
                  height: 140,
                  child: GhostTileContent(
                    categoryColor: tile.color,
                    onConnect: onConnectDevice,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Primary CTA
          ElevatedButton(
            onPressed: onConnectDevice,
            child: const Text('Connect a Device'),
          ),
          const SizedBox(height: 8),
          // Secondary CTA
          TextButton(
            onPressed: onLogManually,
            child: const Text('Log Manually'),
          ),
        ],
      ),
    );
  }
}
