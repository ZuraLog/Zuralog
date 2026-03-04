/// Health Dashboard Screen — Tab 1 (Data) root screen.
///
/// Customizable grid/list of health category cards. Users can reorder via
/// drag-and-drop (long-press to enter edit mode, drag to reorder) and
/// toggle per-category visibility. Each card shows today's primary value and
/// a 7-day sparkline trend. Layout is persisted via the user preferences API.
///
/// Includes the Health Score hero at the top. Tap a category card to push
/// [CategoryDetailScreen].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/category_card.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── HealthDashboardScreen ─────────────────────────────────────────────────────

/// Health Dashboard — root screen for the Data tab.
class HealthDashboardScreen extends ConsumerStatefulWidget {
  /// Creates the [HealthDashboardScreen].
  const HealthDashboardScreen({super.key});

  @override
  ConsumerState<HealthDashboardScreen> createState() =>
      _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends ConsumerState<HealthDashboardScreen> {
  bool _isEditMode = false;

  void _toggleEditMode() {
    ref.read(hapticServiceProvider).medium();
    setState(() => _isEditMode = !_isEditMode);
  }

  @override
  Widget build(BuildContext context) {
    final scoreAsync = ref.watch(healthScoreProvider);
    final dashAsync = ref.watch(dashboardProvider);
    final layout = ref.watch(dashboardLayoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Data',
          style: AppTextStyles.h2,
        ),
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                'Done',
                style: AppTextStyles.body.copyWith(color: AppColors.primary),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _toggleEditMode,
              tooltip: 'Customize',
            ),
          const Padding(
            padding: EdgeInsets.only(right: AppDimens.spaceMd),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(healthScoreProvider);
          ref.invalidate(dashboardProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Health Score Hero ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: scoreAsync.when(
                  loading: () => _HealthScoreHeroSkeleton(),
                  error: (err, stack) => const SizedBox.shrink(),
                  data: (score) => _HealthScoreHero(score: score),
                ),
              ),
            ),

            // ── Section title ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text(
                  _isEditMode ? 'Customize Dashboard' : 'Categories',
                  style: AppTextStyles.h3.copyWith(
                    color: _isEditMode
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            // ── Category cards ───────────────────────────────────────────────
            dashAsync.when(
              loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: _CardSkeleton(),
                  ),
                  childCount: 6,
                ),
              ),
              error: (e, st) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          'Could not load data',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (dashboard) {
                // Seed layout from API on first load if still at default.
                final currentLayout = ref.read(dashboardLayoutProvider);
                if (dashboard.visibleOrder.isNotEmpty &&
                    currentLayout.orderedCategories ==
                        DashboardLayout.defaultLayout.orderedCategories) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(dashboardLayoutProvider.notifier).state =
                        DashboardLayout(
                      orderedCategories: dashboard.visibleOrder,
                      hiddenCategories: currentLayout.hiddenCategories,
                    );
                  });
                }

                // Build ordered visible list from layout.
                final allSummaries = {
                  for (final s in dashboard.categories)
                    s.category.name: s,
                };

                // Merge: use layout order, fall back to API order for new cats.
                final orderedNames = layout.orderedCategories.isNotEmpty
                    ? layout.orderedCategories
                    : HealthCategory.values.map((c) => c.name).toList();

                final items = [
                  for (final name in orderedNames)
                    if (allSummaries.containsKey(name))
                      allSummaries[name]!,
                  // Append any summaries not in the layout (newly added).
                  for (final s in dashboard.categories)
                    if (!orderedNames.contains(s.category.name)) s,
                ];

                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.spaceLg),
                        child: Text(
                          'No health data yet.\nConnect an integration to get started.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (_isEditMode) {
                  return _EditableList(
                    items: items,
                    layout: layout,
                    onReorder: (oldIdx, newIdx) => _onReorder(
                      ref,
                      items,
                      layout,
                      oldIdx,
                      newIdx,
                    ),
                    onVisibilityToggle: (catName) => _onToggleVisibility(
                      ref,
                      layout,
                      catName,
                    ),
                  );
                }

                // Normal view: show only visible cards.
                final visibleItems = items
                    .where((s) =>
                        !layout.hiddenCategories.contains(s.category.name))
                    .toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final summary = visibleItems[i];
                      final cat = summary.category;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppDimens.spaceMd,
                          AppDimens.spaceXs,
                          AppDimens.spaceMd,
                          i == visibleItems.length - 1
                              ? AppDimens.bottomNavHeight + AppDimens.spaceMd
                              : AppDimens.spaceXs,
                        ),
                        child: CategoryCard(
                          title: cat.displayName,
                          categoryColor: categoryColor(cat),
                          primaryValue: summary.primaryValue,
                          unit: summary.unit,
                          deltaPercent: summary.deltaPercent,
                          trend: summary.trend,
                          onTap: () => context.push(
                            '/data/category/${cat.name}',
                          ),
                        ),
                      );
                    },
                    childCount: visibleItems.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onReorder(
    WidgetRef ref,
    List<CategorySummary> items,
    DashboardLayout layout,
    int oldIdx,
    int newIdx,
  ) {
    ref.read(hapticServiceProvider).light();
    final names = items.map((s) => s.category.name).toList();
    if (newIdx > oldIdx) newIdx--;
    names.insert(newIdx, names.removeAt(oldIdx));
    final updated = DashboardLayout(
      orderedCategories: names,
      hiddenCategories: layout.hiddenCategories,
    );
    ref.read(dashboardLayoutProvider.notifier).state = updated;
    // Persist to API (fire-and-forget).
    unawaited(Future(() async {
      try {
        await ref.read(dataRepositoryProvider).saveDashboardLayout(updated);
      } catch (e) {
        debugPrint('[Dashboard] saveDashboardLayout error (reorder): $e');
      }
    }));
  }

  void _onToggleVisibility(
    WidgetRef ref,
    DashboardLayout layout,
    String catName,
  ) {
    ref.read(hapticServiceProvider).selectionTick();
    final hidden = Set<String>.from(layout.hiddenCategories);
    if (hidden.contains(catName)) {
      hidden.remove(catName);
    } else {
      hidden.add(catName);
    }
    final updated = DashboardLayout(
      orderedCategories: layout.orderedCategories,
      hiddenCategories: hidden,
    );
    ref.read(dashboardLayoutProvider.notifier).state = updated;
    unawaited(Future(() async {
      try {
        await ref.read(dataRepositoryProvider).saveDashboardLayout(updated);
      } catch (e) {
        debugPrint('[Dashboard] saveDashboardLayout error (visibility): $e');
      }
    }));
  }
}

// ── _EditableList ─────────────────────────────────────────────────────────────

class _EditableList extends StatelessWidget {
  const _EditableList({
    required this.items,
    required this.layout,
    required this.onReorder,
    required this.onVisibilityToggle,
  });

  final List<CategorySummary> items;
  final DashboardLayout layout;
  final void Function(int oldIdx, int newIdx) onReorder;
  final void Function(String catName) onVisibilityToggle;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      sliver: SliverReorderableList(
        itemCount: items.length,
        onReorder: onReorder,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, animChild) => Material(
              elevation: 4 * animation.value,
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
          );
        },
        itemBuilder: (context, i) {
          final summary = items[i];
          final cat = summary.category;
          final isVisible =
              !layout.hiddenCategories.contains(cat.name);
          return ReorderableDelayedDragStartListener(
            key: ValueKey(cat.name),
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceXs,
              ),
              child: CategoryCard(
                title: cat.displayName,
                categoryColor: categoryColor(cat),
                primaryValue: summary.primaryValue,
                unit: summary.unit,
                isVisible: isVisible,
                isEditMode: true,
                onVisibilityToggle: () =>
                    onVisibilityToggle(cat.name),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── _HealthScoreHero ──────────────────────────────────────────────────────────

class _HealthScoreHero extends StatelessWidget {
  const _HealthScoreHero({required this.score});
  final HealthScoreData score;

  Color get _scoreColor {
    if (score.score >= 70) return AppColors.healthScoreGreen;
    if (score.score >= 40) return AppColors.healthScoreAmber;
    return AppColors.healthScoreRed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score.score / 100,
                  strokeWidth: 6,
                  backgroundColor:
                      _scoreColor.withValues(alpha: 0.18),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_scoreColor),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '${score.score}',
                  style: AppTextStyles.h2.copyWith(
                    color: _scoreColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Score',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _scoreLabel(score.score),
                  style: AppTextStyles.h3.copyWith(
                    color: _scoreColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (score.commentary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    score.commentary!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLabel(int s) {
    if (s >= 85) return 'Excellent';
    if (s >= 70) return 'Good';
    if (s >= 55) return 'Fair';
    if (s >= 40) return 'Needs Attention';
    return 'Critical';
  }
}

// ── Skeleton widgets ──────────────────────────────────────────────────────────

class _HealthScoreHeroSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: shimmer,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer =
        isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: shimmer,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
