/// Health Dashboard Screen — Tab 1 (Data) root screen.
///
/// Phase 8 rewrite: integrates the full masonry tile grid with all Phase 3-7
/// widgets — [HealthScoreStrip], [CategoryFilterChips],
/// [GlobalTimeRangeSelector], [TileGrid], [SearchOverlay], and [TileEditOverlay] — into a single cohesive screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/constants/app_constants.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/time_range.dart';
import 'package:zuralog/features/data/presentation/widgets/category_filter_chips.dart';
import 'package:zuralog/features/data/presentation/widgets/global_time_range_selector.dart';
import 'package:zuralog/features/data/presentation/widgets/health_score_strip.dart';
import 'package:zuralog/features/data/presentation/widgets/search_overlay.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_empty_states.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_grid.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/data_maturity_banner.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

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
  bool _showSearch = false;
  bool _reorderedDuringEdit = false;

  /// Per-category time range override. `null` means "inherit global range".
  /// Set when a category chip is activated; cleared when filter is cleared.
  TimeRange? _categoryTimeRange;

  /// Snapshot of the global time range when a category filter is activated.
  /// Restored when the filter is cleared so the global selector stays consistent.
  TimeRange? _globalTimeRangeSnapshot;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Restore persisted layout on cold-start after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardLayoutLoaderProvider.future).then((persistedLayout) {
        if (!mounted) return;
        if (persistedLayout != null) {
          ref.read(dashboardLayoutProvider.notifier).state = persistedLayout;
        } else {
          final dashData = ref.read(dashboardProvider).valueOrNull;
          if (dashData != null && dashData.visibleOrder.isNotEmpty) {
            ref.read(dashboardLayoutProvider.notifier).state = DashboardLayout(
              orderedCategories: dashData.visibleOrder,
              hiddenCategories: const {},
            );
          }
        }
      });
    });
  }

  // ── Edit mode ────────────────────────────────────────────────────────────────

  void _enterEditMode() {
    ref.read(hapticServiceProvider).medium();
    setState(() {
      _isEditMode = true;
      _reorderedDuringEdit = false;
    });
  }

  void _exitEditMode() {
    ref.read(hapticServiceProvider).medium();
    final didReorder = _reorderedDuringEdit;
    setState(() {
      _isEditMode = false;
      _reorderedDuringEdit = false;
    });
    // Only re-apply smart ordering when the tile order actually changed.
    if (didReorder) ref.invalidate(dashboardTilesProvider);
  }

  // ── Tile interactions ────────────────────────────────────────────────────────

  void _onTileTap(TileId tileId) {
    if (_isEditMode) return;
    context.push('/data/metric/${tileId.name}');
  }

  // ── Layout mutations ─────────────────────────────────────────────────────────

  void _onSizeChanged(TileId tileId, TileSize newSize) {
    final layout = ref.read(dashboardLayoutProvider);
    final sizes = Map<String, TileSize>.from(layout.tileSizes);
    sizes[tileId.name] = newSize;
    final updated = layout.copyWith(tileSizes: sizes);
    ref.read(dashboardLayoutProvider.notifier).state = updated;
    _persistLayout(updated);
  }

  void _onVisibilityToggled(TileId tileId) {
    ref.read(hapticServiceProvider).selectionTick();
    final layout = ref.read(dashboardLayoutProvider);
    final visibility = Map<String, bool>.from(layout.tileVisibility);
    final current = visibility[tileId.name] ?? true;
    visibility[tileId.name] = !current;
    final updated = layout.copyWith(tileVisibility: visibility);
    ref.read(dashboardLayoutProvider.notifier).state = updated;
    _persistLayout(updated);
  }

  void _onColorPick(TileId tileId) {
    final layout = ref.read(dashboardLayoutProvider);
    final colorOverride = layout.tileColorOverrides[tileId.name];
    final currentColor = colorOverride != null
        ? Color(colorOverride)
        : null;

    // Reuse the existing _ColorPickerSheet.
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ColorPickerSheet(
        categoryName: tileId.displayName,
        currentColor: currentColor ?? categoryColor(tileId.category),
        defaultColor: categoryColor(tileId.category),
        onColorSelected: (picked) {
          final currentLayout = ref.read(dashboardLayoutProvider);
          final overrides =
              Map<String, int>.from(currentLayout.tileColorOverrides);
          if (picked == null) {
            overrides.remove(tileId.name);
          } else {
            overrides[tileId.name] = picked.toARGB32();
          }
          final updated =
              currentLayout.copyWith(tileColorOverrides: overrides);
          ref.read(dashboardLayoutProvider.notifier).state = updated;
          _persistLayout(updated);
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    _reorderedDuringEdit = true;
    ref.read(hapticServiceProvider).light();
    final layout = ref.read(dashboardLayoutProvider);
    final orderedIds = ref.read(tileOrderingProvider);
    final names = orderedIds.map((id) => id.name).toList();
    if (newIndex > oldIndex) newIndex--;
    names.insert(newIndex, names.removeAt(oldIndex));
    final updated = layout.copyWith(tileOrder: names);
    ref.read(dashboardLayoutProvider.notifier).state = updated;
    _persistLayout(updated);
  }

  void _persistLayout(DashboardLayout layout) {
    unawaited(Future(() async {
      if (!mounted) return;
      try {
        await ref.read(dataRepositoryProvider).saveDashboardLayout(layout);
      } catch (e) {
        debugPrint('[Dashboard] saveDashboardLayout error: $e');
      }
    }));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.

    final colors = AppColorsOf(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final tilesAsync = ref.watch(dashboardTilesProvider);
    final orderedTileIds = ref.watch(tileOrderingProvider);
    final activeFilter = ref.watch(tileFilterProvider);
    final scoreAsync = ref.watch(healthScoreProvider);
    final hasNetworkError = ref.watch(dashboardHasNetworkErrorProvider);

    // Data maturity banner state.
    final dataDays = scoreAsync.valueOrNull?.dataDays ?? 0;
    final userProfile = ref.watch(userProfileProvider);
    final accountAge = userProfile?.createdAt != null
        ? DateTime.now().difference(userProfile!.createdAt!).inDays
        : 0;
    final dataBannerMode = accountAge >= kMinDataDaysForMaturity
        ? DataMaturityMode.stillBuilding
        : DataMaturityMode.progress;
    final showDataBanner =
        dataDays < kMinDataDaysForMaturity && !layout.bannerDismissed;

    // Build tile map for O(1) lookup.
    final tileMap = {
      for (final t in tilesAsync.valueOrNull ?? <TileData>[]) t.tileId: t,
    };

    // Filter by active category chip.
    final filteredTileIds = activeFilter == null
        ? orderedTileIds
        : orderedTileIds
            .where((id) => id.category == activeFilter)
            .toList();

    // Check onboarding state.
    final allTiles = tilesAsync.valueOrNull ?? [];
    final allNoSource =
        allTiles.isNotEmpty &&
        allTiles.every((t) => t.dataState == TileDataState.noSource);

    return Stack(
      children: [
        ZuralogScaffold(
          // ignore: deprecated_member_use
          addBottomNavPadding: true,
          appBar: ZuralogAppBar(
            title: 'Data',
            tooltipConfig: const ZuralogAppBarTooltipConfig(
              screenKey: 'health_dashboard',
              tooltipKey: 'welcome',
              message: 'This is your data command center. Tap the search icon '
                  'to find metrics, or the edit button to customize your grid.',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => setState(() => _showSearch = true),
                tooltip: 'Search metrics',
              ),
              if (_isEditMode)
                TextButton(
                  onPressed: _exitEditMode,
                  child: Text(
                    'Done',
                    style:
                        AppTextStyles.bodyLarge.copyWith(color: colors.primary),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: _enterEditMode,
                  tooltip: 'Customize',
                ),
            ],
          ),
          body: RefreshIndicator(
            color: colors.primary,
            onRefresh: () async {
              if (_isEditMode) return;
              ref.invalidate(dashboardTilesProvider);
              ref.invalidate(healthScoreProvider);
              ref.invalidate(dashboardProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Health Score Strip ────────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                    ),
                    child: HealthScoreStrip(),
                  ),
                ),

                // ── Data Maturity Banner ──────────────────────────────────
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
                        targetDays: kMinDataDaysForMaturity,
                        mode: dataBannerMode,
                        onDismiss: () {
                          final updated = layout.copyWith(bannerDismissed: true);
                          ref.read(dashboardLayoutProvider.notifier).state =
                              updated;
                          _persistLayout(updated);
                        },
                        onPermanentDismiss:
                            dataBannerMode == DataMaturityMode.stillBuilding
                                ? () {
                                    final updated =
                                        layout.copyWith(bannerDismissed: true);
                                    ref
                                        .read(dashboardLayoutProvider.notifier)
                                        .state = updated;
                                    _persistLayout(updated);
                                  }
                                : null,
                      ),
                    ),
                  ),

                // ── Category Filter Chips ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimens.spaceSm,
                      bottom: AppDimens.spaceSm,
                    ),
                    child: CategoryFilterChips(
                      selected: activeFilter,
                      onSelected: (cat) {
                        ref.read(tileFilterProvider.notifier).state = cat;
                        setState(() {
                          if (cat != null) {
                            // Snapshot the global range so we can restore it when filter is cleared.
                            _globalTimeRangeSnapshot = ref.read(dashboardTimeRangeProvider);
                            _categoryTimeRange = _globalTimeRangeSnapshot;
                          } else {
                            // Restore global range when filter is cleared.
                            if (_globalTimeRangeSnapshot != null) {
                              ref.read(dashboardTimeRangeProvider.notifier).state =
                                  _globalTimeRangeSnapshot!;
                            }
                            _globalTimeRangeSnapshot = null;
                            _categoryTimeRange = null;
                          }
                        });
                      },
                    ),
                  ),
                ),

                // ── Global Time Range Selector ────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: GlobalTimeRangeSelector(),
                  ),
                ),

                // ── Per-category Time Range Selector ──────────────────────
                // Shown only when a category chip is active. Inherits the
                // global range on activation but can be changed independently.
                if (activeFilter != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimens.spaceSm,
                      ),
                      child: _CategoryTimeRangeSelector(
                        selected: _categoryTimeRange ??
                            ref.watch(dashboardTimeRangeProvider),
                        onChanged: (range) {
                          setState(() => _categoryTimeRange = range);
                          // Write to dashboardTimeRangeProvider so tiles re-fetch with the new range.
                          ref.read(dashboardTimeRangeProvider.notifier).state = range;
                        },
                      ),
                    ),
                  ),

                // ── Onboarding empty state or Tile Grid ───────────────────
                if (allNoSource && hasNetworkError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceLg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          Text(
                            'Data source unavailable',
                            style: AppTextStyles.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimens.spaceXs),
                          const Text(
                            'Pull down to retry when your connection is restored.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (allNoSource)
                  SliverToBoxAdapter(
                    child: OnboardingEmptyState(
                      onConnectDevice: () => context
                          .push(RouteNames.settingsIntegrationsPath),
                      onLogManually: () => context.go('/today'),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: tilesAsync.isLoading
                          ? const _DashboardSkeletonBox(key: ValueKey('loading'))
                          : _TileGridBox(
                              key: ValueKey(activeFilter),
                              orderedTileIds: filteredTileIds,
                              tiles: tileMap,
                              layout: layout,
                              isEditMode: _isEditMode,
                              onTileTap: _onTileTap,
                              onSizeChanged: _onSizeChanged,
                              onVisibilityToggled: _onVisibilityToggled,
                              onColorPick: _onColorPick,
                              onReorder: _onReorder,
                            ),
                    ),
                  ),

                // ── "Ask Coach about [Category]" CTA ──────────────────────
                if (activeFilter != null && !allNoSource)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, 0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          'Ask Coach about ${activeFilter.displayName}',
                        ),
                        onPressed: () {
                          ref.read(coachPrefillProvider.notifier).state =
                              'Tell me about my ${activeFilter.displayName} data';
                          context.go('/coach');
                        },
                      ),
                    ),
                  ),

                // ── Bottom padding ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AppDimens.bottomClearance(context) +
                        AppDimens.spaceMd,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Search Overlay ────────────────────────────────────────────────
        if (_showSearch)
          SearchOverlay(
            tiles: tilesAsync.valueOrNull ?? [],
            onClose: () => setState(() => _showSearch = false),
            onTileSelected: (tileId) {
              setState(() => _showSearch = false);
              context.push('/data/metric/${tileId.name}');
            },
          ),
      ],
    );
  }

}

// ── _CategoryTimeRangeSelector ────────────────────────────────────────────────

/// Per-category time range selector.
///
/// Shown below the global [GlobalTimeRangeSelector] when a category filter
/// chip is active (§3.3, §3.4, §8.2). Inherits the global range when a
/// category is first selected but can be changed independently for that
/// session. Does NOT persist — state lives in the screen.
class _CategoryTimeRangeSelector extends StatelessWidget {
  const _CategoryTimeRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.spaceMd,
            bottom: AppDimens.spaceXs,
          ),
          child: Text(
            'Category range',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ),
        SingleChildScrollView(
          key: const Key('category_time_range_selector'),
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Row(
            children: TimeRange.values.expand((range) {
              final isActive = selected == range;
              final bgColor =
                  isActive ? colors.primary : Colors.transparent;
              final borderColor =
                  isActive ? colors.primary : colors.border;
              final textColor =
                  isActive ? Colors.white : colors.textSecondary;
              return [
                GestureDetector(
                  onTap: () => onChanged(range),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 28,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusChip),
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      range.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: textColor,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
              ];
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── _TileGridBox ──────────────────────────────────────────────────────────────

/// Box-widget wrapper around [TileGrid] for use inside [AnimatedSwitcher].
///
/// Embeds TileGrid (a sliver widget) in a [CustomScrollView] with
/// [shrinkWrap] and [NeverScrollableScrollPhysics] so it sizes itself to its
/// content and the outer [CustomScrollView] in [HealthDashboardScreen]
/// controls scrolling.
class _TileGridBox extends StatelessWidget {
  const _TileGridBox({
    super.key,
    required this.orderedTileIds,
    required this.tiles,
    required this.layout,
    required this.isEditMode,
    required this.onTileTap,
    required this.onSizeChanged,
    required this.onVisibilityToggled,
    required this.onColorPick,
    required this.onReorder,
  });

  final List<TileId> orderedTileIds;
  final Map<TileId, TileData> tiles;
  final DashboardLayout layout;
  final bool isEditMode;
  final void Function(TileId) onTileTap;
  final void Function(TileId, TileSize) onSizeChanged;
  final void Function(TileId) onVisibilityToggled;
  final void Function(TileId) onColorPick;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    // shrinkWrap: true is intentional here. AnimatedSwitcher requires a box
    // widget, so TileGrid (a sliver) must be wrapped in a CustomScrollView.
    // With only 20 tiles this eagerly-measured scroll view has negligible
    // performance cost. NeverScrollableScrollPhysics prevents scroll conflicts
    // with the outer CustomScrollView.
    return CustomScrollView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        TileGrid(
          orderedTileIds: orderedTileIds,
          tiles: tiles,
          layout: layout,
          isEditMode: isEditMode,
          onTileTap: onTileTap,
          onSizeChanged: onSizeChanged,
          onVisibilityToggled: onVisibilityToggled,
          onColorPick: onColorPick,
          onReorder: onReorder,
        ),
      ],
    );
  }
}

// ── _ColorPickerSheet ─────────────────────────────────────────────────────────

/// Bottom sheet for picking a tile accent color override.
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
    final colors = AppColorsOf(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.elevatedSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
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

// ── Skeleton widgets ──────────────────────────────────────────────────────────

/// Animated layout-aware skeleton for a single metric tile card.
///
/// Internal structure mirrors [MetricTile]'s loaded layout:
/// header row → value → unit → chart area.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      label: 'Loading dashboard metrics',
      excludeSemantics: true,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
        ),
        padding: const EdgeInsets.all(12),
        child: AppShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: dot + name + spacer + icon slot
              Row(
                children: [
                  ShimmerBox(height: 8, width: 8, isCircle: true),
                  const SizedBox(width: 6),
                  ShimmerBox(height: 8, width: 64),
                  const Spacer(),
                  ShimmerBox(height: 14, width: 14),
                ],
              ),
              const SizedBox(height: 8),
              // Primary value
              ShimmerBox(height: 28, width: 56),
              const SizedBox(height: 4),
              // Unit label
              ShimmerBox(height: 8, width: 36),
              const SizedBox(height: 8),
              // Chart area — fills remaining height
              Expanded(
                child: ShimmerBox(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Box widget wrapping 6 [_CardSkeleton]s — used in [AnimatedSwitcher].
class _DashboardSkeletonBox extends StatelessWidget {
  const _DashboardSkeletonBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(6, (_) => const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        child: _CardSkeleton(),
      )),
    );
  }
}
