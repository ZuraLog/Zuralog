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
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/category_card.dart';
import 'package:zuralog/shared/widgets/data_maturity_banner.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/score_trend_hero.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── HealthDashboardScreen ─────────────────────────────────────────────────────

/// Health Dashboard — root screen for the Data tab.
class HealthDashboardScreen extends ConsumerStatefulWidget {
  /// Creates the [HealthDashboardScreen].
  const HealthDashboardScreen({super.key});

  @override
  ConsumerState<HealthDashboardScreen> createState() =>
      _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends ConsumerState<HealthDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isEditMode = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Restore persisted layout on cold-start after first frame.
    // If no layout is persisted, fall back to seeding from the dashboard API
    // response (if already loaded) or leave orderedCategories empty so the
    // HealthCategory.values fallback at build-time renders all cards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardLayoutLoaderProvider.future).then((persistedLayout) {
        if (!mounted) return;
        if (persistedLayout != null) {
          ref.read(dashboardLayoutProvider.notifier).state = persistedLayout;
        } else {
          // No persisted layout — seed from the dashboard data if it has
          // already resolved so the user sees the API-ordered categories
          // rather than the canonical enum order.
          final dashData = ref.read(dashboardProvider).valueOrNull;
          if (dashData != null && dashData.visibleOrder.isNotEmpty) {
            ref.read(dashboardLayoutProvider.notifier).state = DashboardLayout(
              orderedCategories: dashData.visibleOrder,
              hiddenCategories: const {},
            );
          }
          // If dashboardProvider hasn't resolved yet, orderedCategories
          // remains [] and the HealthCategory.values fallback in build()
          // shows all categories in canonical order — no cards are hidden.
        }
      });
    });
  }

  void _toggleEditMode() {
    ref.read(hapticServiceProvider).medium();
    setState(() => _isEditMode = !_isEditMode);
  }

  void _onColorPick(
    BuildContext context,
    WidgetRef ref,
    DashboardLayout layout,
    HealthCategory cat,
  ) {
    ref.read(hapticServiceProvider).light();
    final defaultColor = categoryColor(cat);
    final currentColorValue = layout.categoryColorOverrides[cat.name];
    final currentColor =
        currentColorValue != null ? Color(currentColorValue) : defaultColor;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ColorPickerSheet(
        categoryName: cat.displayName,
        currentColor: currentColor,
        defaultColor: defaultColor,
        onColorSelected: (picked) {
          final overrides =
              Map<String, int>.from(layout.categoryColorOverrides);
          if (picked == null) {
            overrides.remove(cat.name);
          } else {
            overrides[cat.name] = picked.toARGB32();
          }
          final updated = DashboardLayout(
            orderedCategories: layout.orderedCategories,
            hiddenCategories: layout.hiddenCategories,
            categoryColorOverrides: overrides,
          );
          ref.read(dashboardLayoutProvider.notifier).state = updated;
          unawaited(Future(() async {
            try {
              await ref
                  .read(dataRepositoryProvider)
                  .saveDashboardLayout(updated);
            } catch (e) {
              debugPrint('[Dashboard] saveDashboardLayout error (color): $e');
            }
          }));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
    final scoreAsync = ref.watch(healthScoreProvider);
    final dashAsync = ref.watch(dashboardProvider);
    final layout = ref.watch(dashboardLayoutProvider);

    // Data maturity banner state.
    final dataDays = scoreAsync.valueOrNull?.dataDays ?? 0;
    final userProfile = ref.watch(userProfileProvider);
    final accountAge = userProfile?.createdAt != null
        ? DateTime.now().difference(userProfile!.createdAt!).inDays
        : 0;
    final dataBannerMode = accountAge >= 7
        ? DataMaturityMode.stillBuilding
        : DataMaturityMode.progress;
    final showDataBanner = dataDays < 7 && !layout.bannerDismissed;

    return ZuralogScaffold(
      addBottomNavPadding: true,
      appBar: ZuralogAppBar(
        title: 'Data',
        tooltipConfig: const ZuralogAppBarTooltipConfig(
          screenKey: 'health_dashboard',
          tooltipKey: 'welcome',
          message: 'This is your data command center. Long-press a card to '
              'reorder, or tap the edit button to show/hide categories.',
        ),
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                'Done',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _toggleEditMode,
              tooltip: 'Customize',
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
            // ── Score Trend Hero ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: const ScoreTrendHero(),
              ),
            ),

            // ── Data Maturity Banner ─────────────────────────────────────────
            if (showDataBanner)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    0,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: DataMaturityBanner(
                    daysWithData: dataDays,
                    targetDays: 7,
                    mode: dataBannerMode,
                    onDismiss: () {
                      final updated = layout.copyWith(bannerDismissed: true);
                      ref.read(dashboardLayoutProvider.notifier).state = updated;
                      unawaited(Future(() async {
                        try {
                          await ref
                              .read(dataRepositoryProvider)
                              .saveDashboardLayout(updated);
                        } catch (e) {
                          debugPrint('[Dashboard] saveDashboardLayout error (banner): $e');
                        }
                      }));
                    },
                    onPermanentDismiss: dataBannerMode == DataMaturityMode.stillBuilding
                        ? () {
                            final updated = layout.copyWith(bannerDismissed: true);
                            ref.read(dashboardLayoutProvider.notifier).state = updated;
                            unawaited(Future(() async {
                              try {
                                await ref
                                    .read(dataRepositoryProvider)
                                    .saveDashboardLayout(updated);
                              } catch (e) {
                                debugPrint('[Dashboard] saveDashboardLayout error (banner): $e');
                              }
                            }));
                          }
                        : null,
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
                  style: AppTextStyles.titleMedium.copyWith(
                    color: _isEditMode
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            // ── Category cards ───────────────────────────────────────────────
            dashAsync.when(
              loading: () => SliverMainAxisGroup(
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceXs,
                        ),
                        child: const _CardSkeleton(),
                      ),
                      childCount: 6,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: AppDimens.bottomClearance(context),
                    ),
                  ),
                ],
              ),
              error: (e, st) => SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: AppDimens.bottomClearance(context),
                  ),
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
                             style: AppTextStyles.bodyLarge.copyWith(
                               color: AppColors.textSecondary,
                             ),
                           ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              data: (dashboard) {
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
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        AppDimens.spaceSm,
                        AppDimens.spaceMd,
                        AppDimens.bottomClearance(context),
                      ),
                      child: const _CategoriesEmptyState(),
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
                    onColorPick: (cat) =>
                        _onColorPick(context, ref, layout, cat),
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
                      final overrideValue =
                          layout.categoryColorOverrides[cat.name];
                      final cardColor = overrideValue != null
                          ? Color(overrideValue)
                          : categoryColor(cat);
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppDimens.spaceMd,
                            AppDimens.spaceXs,
                            AppDimens.spaceMd,
                            i == visibleItems.length - 1
                                ? AppDimens.bottomClearance(context)
                                : AppDimens.spaceXs,
                          ),
                        child: CategoryCard(
                          title: cat.displayName,
                          categoryColor: cardColor,
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
      categoryColorOverrides: layout.categoryColorOverrides,
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
      categoryColorOverrides: layout.categoryColorOverrides,
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
    required this.onColorPick,
  });

  final List<CategorySummary> items;
  final DashboardLayout layout;
  final void Function(int oldIdx, int newIdx) onReorder;
  final void Function(String catName) onVisibilityToggle;
  final void Function(HealthCategory cat) onColorPick;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.bottomClearance(context),
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
              color: Colors.transparent,
              child: animChild,
            ),
            child: child,
          );
        },
        itemBuilder: (context, i) {
          final summary = items[i];
          final cat = summary.category;
          final isVisible = !layout.hiddenCategories.contains(cat.name);
          final overrideValue = layout.categoryColorOverrides[cat.name];
          final cardColor = overrideValue != null
              ? Color(overrideValue)
              : categoryColor(cat);
          return ReorderableDragStartListener(
            key: ValueKey(cat.name),
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceXs,
              ),
              child: CategoryCard(
                title: cat.displayName,
                categoryColor: cardColor,
                primaryValue: summary.primaryValue,
                unit: summary.unit,
                isVisible: isVisible,
                isEditMode: true,
                onVisibilityToggle: () => onVisibilityToggle(cat.name),
                onColorPick: () => onColorPick(cat),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── _ColorPickerSheet ─────────────────────────────────────────────────────────

/// Bottom sheet for picking a category accent color override.
class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet({
    required this.categoryName,
    required this.currentColor,
    required this.defaultColor,
    required this.onColorSelected,
  });

  final String categoryName;
  final Color currentColor;
  final Color defaultColor;

  /// Called with the selected [Color], or `null` to reset to the default.
  final ValueChanged<Color?> onColorSelected;

  static const List<Color> _palette = [
    Color(0xFFCFE1B9), // Sage Green (brand)
    Color(0xFF30D158), // Green
    Color(0xFF34C759), // Light Green
    Color(0xFF007AFF), // Blue
    Color(0xFF0A84FF), // Bright Blue
    Color(0xFF5AC8FA), // Sky Blue
    Color(0xFF5E5CE6), // Indigo
    Color(0xFFBF5AF2), // Purple
    Color(0xFFFF2D55), // Red
    Color(0xFFFF6B6B), // Coral
    Color(0xFFFF9F0A), // Amber
    Color(0xFFFFD60A), // Yellow
    Color(0xFFFF6F00), // Orange
    Color(0xFF636366), // Grey
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceSm,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text('Accent Color', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimens.spaceMd),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Reset to default chip
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  onColorSelected(null);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: defaultColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: currentColor == defaultColor
                          ? Colors.white
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: currentColor == defaultColor
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ),
              ..._palette.map(
                (c) => GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onColorSelected(c);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: currentColor.toARGB32() == c.toARGB32()
                            ? Colors.white
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: currentColor.toARGB32() == c.toARGB32()
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ),
    ),
    );
  }
}

// ── _CategoriesEmptyState ─────────────────────────────────────────────────────

/// Shown when the dashboard has no category data yet — typically for a
/// brand-new user who hasn't connected any integrations.
///
/// Welcoming and action-oriented: guides the user toward connecting an app
/// or logging their first data point manually.
class _CategoriesEmptyState extends StatelessWidget {
  const _CategoriesEmptyState();

  static const _categories = [
    _CategoryPreviewItem(
      label: 'Activity',
      color: AppColors.categoryActivity,
    ),
    _CategoryPreviewItem(
      label: 'Sleep',
      color: AppColors.categorySleep,
    ),
    _CategoryPreviewItem(
      label: 'Heart',
      color: AppColors.categoryHeart,
    ),
    _CategoryPreviewItem(
      label: 'Nutrition',
      color: AppColors.categoryNutrition,
    ),
    _CategoryPreviewItem(
      label: 'Body',
      color: AppColors.categoryBody,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview cards — ghost/dimmed to show what's coming
        ..._categories.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            child: _GhostCategoryCard(item: item),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        // Call-to-action card
        GestureDetector(
          onTap: () => context.push(RouteNames.settingsIntegrationsPath),
          child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: const Icon(
                  Icons.cable_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect your first app',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Your categories fill in automatically once you connect a health app.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }
}

@immutable
class _CategoryPreviewItem {
  const _CategoryPreviewItem({required this.label, required this.color});
  final String label;
  final Color color;
}

/// A dimmed, ghost version of a category card — shows the placeholder layout
/// that will be filled once the user has real data.
class _GhostCategoryCard extends StatelessWidget {
  const _GhostCategoryCard({required this.item});
  final _CategoryPreviewItem item;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: IntrinsicHeight(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category color accent stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm + 2,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
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

// ── Skeleton widgets ──────────────────────────────────────────────────────────

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

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
