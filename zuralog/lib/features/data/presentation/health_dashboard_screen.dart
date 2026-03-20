/// Health Dashboard Screen — Tab 1 (Data) root screen.
///
/// Phase 8 rewrite: integrates the full masonry tile grid with all Phase 3-7
/// widgets — [HealthScoreStrip], [CategoryFilterChips],
/// [GlobalTimeRangeSelector], [TileGrid], [TileExpandedView],
/// [SearchOverlay], and [TileEditOverlay] — into a single cohesive screen.
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
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/category_filter_chips.dart';
import 'package:zuralog/features/data/presentation/widgets/global_time_range_selector.dart';
import 'package:zuralog/features/data/presentation/widgets/health_score_strip.dart';
import 'package:zuralog/features/data/presentation/widgets/search_overlay.dart';
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
  TileId? _expandedTileId;
  bool _showSearch = false;

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
      _expandedTileId = null; // collapse any expanded tile
    });
  }

  void _exitEditMode() {
    ref.read(hapticServiceProvider).medium();
    setState(() => _isEditMode = false);
    // Re-apply smart ordering after edits.
    ref.invalidate(dashboardTilesProvider);
  }

  // ── Tile interactions ────────────────────────────────────────────────────────

  void _onTileTap(TileId tileId) {
    if (_isEditMode) return;
    setState(() {
      if (_expandedTileId == tileId) {
        _expandedTileId = null; // collapse
      } else {
        _expandedTileId = tileId; // expand
      }
    });
  }

  void _onViewDetails(TileId tileId) {
    context.push('/data/category/${tileId.category.name}');
  }

  void _onAskCoach(TileId tileId, String primaryValue) {
    ref.read(coachPrefillProvider.notifier).state =
        'Tell me about my ${tileId.displayName}: $primaryValue';
    context.go('/coach');
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
        currentColor: currentColor ?? const Color(0xFF007AFF),
        defaultColor: const Color(0xFF007AFF),
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
                  icon: const Icon(Icons.tune_rounded),
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
                        // Collapse expanded tile when filter changes.
                        setState(() => _expandedTileId = null);
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

                // ── Onboarding empty state or Tile Grid ───────────────────
                if (allNoSource)
                  SliverToBoxAdapter(
                    child: _OnboardingEmptyState(
                      onConnectDevice: () => context
                          .push(RouteNames.settingsIntegrationsPath),
                      onLogManually: () => context.go('/today'),
                    ),
                  )
                else if (tilesAsync.isLoading)
                  _buildLoadingSlivers()
                else
                  TileGrid(
                    orderedTileIds: filteredTileIds,
                    tiles: tileMap,
                    layout: layout,
                    isEditMode: _isEditMode,
                    expandedTileId: _expandedTileId,
                    onTileTap: _onTileTap,
                    onViewDetails: _onViewDetails,
                    onAskCoach: _onAskCoach,
                    onSizeChanged: _onSizeChanged,
                    onVisibilityToggled: _onVisibilityToggled,
                    onColorPick: _onColorPick,
                    onReorder: _onReorder,
                  ),

                // ── "Ask Coach about [Category]" CTA ──────────────────────
                if (activeFilter != null && !allNoSource)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              setState(() {
                _showSearch = false;
                _expandedTileId = tileId;
                // Clear category filter so the tile is visible.
                ref.read(tileFilterProvider.notifier).state = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildLoadingSlivers() {
    return SliverMainAxisGroup(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceXs,
              ),
              child: _CardSkeleton(),
            ),
            childCount: 6,
          ),
        ),
      ],
    );
  }
}

// ── _OnboardingEmptyState ─────────────────────────────────────────────────────

/// Shown when all tiles are in [TileDataState.noSource] — brand-new user.
class _OnboardingEmptyState extends StatelessWidget {
  const _OnboardingEmptyState({
    required this.onConnectDevice,
    required this.onLogManually,
  });

  final VoidCallback onConnectDevice;
  final VoidCallback onLogManually;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimens.spaceMd),
          Icon(
            Icons.monitor_heart_rounded,
            size: 56,
            color: colors.textTertiary,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'No data yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Connect a health app or log your first data point manually '
            'to start seeing your metrics here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          FilledButton.icon(
            icon: const Icon(Icons.cable_rounded),
            label: const Text('Connect a device'),
            onPressed: onConnectDevice,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Log manually'),
            onPressed: onLogManually,
          ),
        ],
      ),
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

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
    );
  }
}
