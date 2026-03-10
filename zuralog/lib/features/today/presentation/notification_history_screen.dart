/// Notification History Screen — pushed from Today header bell icon.
///
/// Scrollable list of all past push notifications grouped by day.
/// Tapping a notification deep-links to the relevant insight or metric.
///
/// Full implementation: Phase 3, Task 3.3.
/// Design elevation: Phase 3 elevation pass — editorial animations & micro-interactions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/animations/z_fade_slide_in.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/loading/z_loading_skeleton.dart';

// ── NotificationHistoryScreen ─────────────────────────────────────────────────

/// Full notification history grouped by day.
///
/// Accessible via the bell icon in the Today tab app bar.
/// Marks each notification as read when it is viewed.
class NotificationHistoryScreen extends ConsumerWidget {
  /// Creates the [NotificationHistoryScreen].
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return ZuralogScaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardBackgroundDark,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref
              .read(notificationsProvider.future)
              .catchError(
                (_) => const NotificationPage(
                  items: [],
                  totalCount: 0,
                  page: 1,
                  hasMore: false,
                ),
              );
        },
        child: notificationsAsync.when(
          data: (page) {
            if (page.items.isEmpty) {
              return const _EmptyState();
            }
            final grouped = _groupByDay(page.items);
            final dayKeys = grouped.keys.toList();

            // Flatten to a linear item-index for stagger timing.
            var globalIndex = 0;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppDimens.spaceXxl),
              itemCount: dayKeys.length,
              itemBuilder: (context, dayIndex) {
                final dayKey = dayKeys[dayIndex];
                final items = grouped[dayKey]!;

                // Capture the starting index for this day's first row.
                final dayStartIndex = globalIndex;
                globalIndex += items.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day section header — staggered by dayIndex.
                    ZFadeSlideIn(
                      delay: Duration(
                        milliseconds: dayStartIndex * 50,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimens.spaceMd,
                          AppDimens.spaceLg,
                          AppDimens.spaceMd,
                          AppDimens.spaceSm,
                        ),
                        child: Text(
                          dayKey,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Notification rows — each staggered 50ms apart.
                    for (var i = 0; i < items.length; i++)
                      ZFadeSlideIn(
                        delay: Duration(
                          milliseconds: (dayStartIndex + i) * 50 + 30,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceXs,
                          ),
                          child: _NotificationRow(
                            item: items[i],
                            onTap: () => _handleNotificationTap(
                              context,
                              ref,
                              items[i],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const _LoadingList(),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
        ),
      ),
    );
  }
}

// ── _NotificationRow ──────────────────────────────────────────────────────────

class _NotificationRow extends ConsumerStatefulWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  ConsumerState<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends ConsumerState<_NotificationRow> {
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Auto-mark as read when this row is rendered/visible.
    if (!widget.item.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(todayRepositoryProvider)
            .markNotificationRead(widget.item.id)
            .catchError((_) {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = widget.item.isRead;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        ref.read(hapticServiceProvider).light();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left 3px accent bar for unread — replaces the old border.
              if (!isRead)
                Container(
                  width: 3,
                  color: AppColors.primary,
                ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackgroundDark,
                    borderRadius: isRead
                        ? BorderRadius.circular(AppDimens.radiusCard)
                        : const BorderRadius.only(
                            topRight: Radius.circular(AppDimens.radiusCard),
                            bottomRight: Radius.circular(AppDimens.radiusCard),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unread dot indicator.
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 5,
                          right: AppDimens.spaceSm,
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.transparent
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: isRead
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textPrimaryDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.item.body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.item.body,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 14,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (widget.item.receivedAt != null) ...[
                              const SizedBox(height: AppDimens.spaceXs),
                              Text(
                                _timeString(widget.item.receivedAt!),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.item.deepLinkRoute != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppDimens.spaceXs,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: AppDimens.iconSm,
                            // Tinted with primary at 50% — matches insight card.
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / Loading / Error states ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'No notifications yet',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up.",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      itemCount: 6,
      itemBuilder: (_, i) => const Padding(
        padding: EdgeInsets.only(bottom: AppDimens.spaceSm),
        child: ZLoadingSkeleton(width: double.infinity, height: 72),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Could not load notifications',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Groups a flat list of notifications into day-keyed sections.
///
/// Keys are human-readable day labels: "Today", "Yesterday", or "Mon Mar 3".
Map<String, List<NotificationItem>> _groupByDay(
  List<NotificationItem> items,
) {
  final result = <String, List<NotificationItem>>{};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  for (final item in items) {
    final dt = item.receivedAt;
    final String key;
    if (dt == null) {
      key = 'Earlier';
    } else {
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day == today) {
        key = 'Today';
      } else if (day == yesterday) {
        key = 'Yesterday';
      } else {
        key = _shortDate(day);
      }
    }
    result.putIfAbsent(key, () => []).add(item);
  }
  return result;
}

/// Returns a short date label, e.g. "Mon Mar 3".
String _shortDate(DateTime dt) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[dt.weekday - 1]} ${months[dt.month - 1]} ${dt.day}';
}

/// Returns a human-readable time string for a notification timestamp.
String _timeString(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return _shortDate(dt);
}

/// Handles a notification tap by deep-linking to the appropriate screen.
void _handleNotificationTap(
  BuildContext context,
  WidgetRef ref,
  NotificationItem item,
) {
  final route = item.deepLinkRoute;
  final id = item.deepLinkId;

  if (route == null) return;

  switch (route) {
    case 'insightDetail':
      if (id != null) {
        context.pushNamed(
          RouteNames.insightDetail,
          pathParameters: {'id': id},
        );
      }
    case 'data':
      context.go(RouteNames.dataPath);
    case 'coach':
      context.go(RouteNames.coachPath);
    default:
      // If the route is a full path, navigate directly.
      if (route.startsWith('/')) context.go(route);
  }
}
