/// Today Timeline — paginated list of today's health events.
///
/// Displays raw health events from GET /api/v1/today/timeline with
/// infinite scroll (load-more on reaching the bottom). Manual events
/// can be swiped to delete (see Task 19).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── TodayTimelineSection ────────────────────────────────────────────────────

/// A sliver-compatible timeline section that shows today's health events.
///
/// Must be placed inside a [CustomScrollView] or [NestedScrollView].
/// Automatically triggers [TodayTimelineNotifier.load] on first build.
class TodayTimelineSection extends ConsumerStatefulWidget {
  const TodayTimelineSection({super.key});

  @override
  ConsumerState<TodayTimelineSection> createState() =>
      _TodayTimelineSectionState();
}

class _TodayTimelineSectionState extends ConsumerState<TodayTimelineSection> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load after the first frame to avoid modifying
    // providers during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(todayTimelineProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayTimelineProvider);
    final colors = AppColorsOf(context);

    // Initial loading state
    if (state.isLoading && state.events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Center(
            child: CircularProgressIndicator(color: colors.primary),
          ),
        ),
      );
    }

    // Error state with no data
    if (state.error != null && state.events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colors.textTertiary, size: 32),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Could not load timeline',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                TextButton(
                  onPressed: () =>
                      ref.read(todayTimelineProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Empty state
    if (state.events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Center(
            child: Text(
              'No events logged today',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    // Event list + optional load-more indicator
    final itemCount = state.events.length + (state.hasMore ? 1 : 0);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Load-more trigger at the bottom
          if (index == state.events.length) {
            // Trigger load when we reach the sentinel item
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(todayTimelineProvider.notifier).loadMore();
            });
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
              child: Center(
                child: state.isLoadingMore
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          final event = state.events[index];
          return _TimelineEventTile(event: event);
        },
        childCount: itemCount,
      ),
    );
  }
}

// ── _TimelineEventTile ──────────────────────────────────────────────────────

class _TimelineEventTile extends ConsumerWidget {
  const _TimelineEventTile({required this.event});

  final TodayEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final timeStr = _formatTime(event.recordedAt);
    final isManual = event.source == 'manual';

    final tile = Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: Row(
        children: [
          // Metric icon
          _metricIcon(event.metricType, colors),
          const SizedBox(width: AppDimens.spaceSm),
          // Metric info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatMetricType(event.metricType),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatValue(event.value)} ${event.unit}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Time + source
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatSource(event.source),
                style: AppTextStyles.bodySmall.copyWith(
                  color: isManual ? colors.primary : colors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Wrap manual events with Dismissible for swipe-to-delete (Task 19)
    if (isManual) {
      return Dismissible(
        key: ValueKey(event.eventId),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppDimens.spaceMd),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete event?'),
              content: Text(
                'Remove this ${_formatMetricType(event.metricType)} entry?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (_) async {
          // Optimistically remove from the list
          ref.read(todayTimelineProvider.notifier).removeEvent(event.eventId);
          try {
            final repo = ref.read(todayRepositoryProvider);
            await repo.deleteEvent(event.eventId);
            // Invalidate related providers so totals refresh
            ref.invalidate(todayLogSummaryProvider);
            ref.invalidate(healthScoreProvider);
          } catch (e) {
            // Reload timeline on failure to restore the deleted item
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to delete event')),
              );
            }
            ref.read(todayTimelineProvider.notifier).load();
          }
        },
        child: tile,
      );
    }

    return tile;
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  static String _formatMetricType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _formatSource(String source) {
    return switch (source) {
      'manual' => 'Manual',
      'apple_health' => 'Apple Health',
      'health_connect' => 'Health Connect',
      _ => source,
    };
  }

  static Widget _metricIcon(String metricType, AppColorsOf colors) {
    final IconData icon = switch (metricType) {
      'steps' => Icons.directions_walk,
      'weight' => Icons.monitor_weight_outlined,
      'sleep_hours' => Icons.bedtime_outlined,
      'water_liters' || 'water' => Icons.water_drop_outlined,
      'heart_rate_avg' || 'resting_heart_rate' => Icons.favorite_outlined,
      'active_calories' || 'nutrition_calories' => Icons.local_fire_department_outlined,
      'hrv_ms' => Icons.timeline,
      'vo2_max' => Icons.air,
      'mood' => Icons.emoji_emotions_outlined,
      'energy' => Icons.bolt_outlined,
      'stress' => Icons.psychology_outlined,
      _ => Icons.analytics_outlined,
    };
    return Icon(icon, size: 20, color: colors.primary);
  }
}
