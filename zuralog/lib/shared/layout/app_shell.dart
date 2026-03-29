/// Zuralog Edge Agent — App Shell (5-Tab Bottom Navigation Scaffold).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/state/log_sheet_provider.dart';
import 'package:zuralog/core/state/side_panel_provider.dart';
import 'package:zuralog/core/theme/app_colors.dart' show AppColorsOf;
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_motion.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';
import 'package:zuralog/shared/widgets/profile_side_panel.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_sheet.dart';

const double _kPanelWidth = 320.0;
const Duration _kPanelDuration = Duration(milliseconds: 300);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastSheetTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(logSheetCallbackProvider.notifier).state = _openLogSheet;
    });
  }

  @override
  void dispose() {
    // Guard against the ProviderContainer being disposed before this widget
    // (can happen during hot restart or test teardown).
    try {
      ref.read(logSheetCallbackProvider.notifier).state = null;
    } catch (_) {}
    super.dispose();
  }

  void _openLogSheet() {
    final now = DateTime.now();
    if (_lastSheetTap != null &&
        now.difference(_lastSheetTap!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastSheetTap = now;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ZLogGridSheet(
        onFullScreenRoute: (routeName) {
          Navigator.of(context).pop();
          context.pushNamed(routeName);
        },
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (ref.read(sidePanelOpenProvider)) {
      ref.read(sidePanelOpenProvider.notifier).state = false;
    }
    ref.read(hapticServiceProvider).selectionTick();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPanelOpen = ref.watch(sidePanelOpenProvider);
    final isPanelVisible = ref.watch(sidePanelVisibleProvider);

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main content — always full size, no transforms.
          widget.navigationShell,

          // Backdrop — only present when panel is open.
          if (isPanelOpen)
            GestureDetector(
              onTap: () =>
                  ref.read(sidePanelOpenProvider.notifier).state = false,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const SizedBox.expand(),
              ),
            ),

          // Side panel — slides in from the right.
          //
          // The Positioned node is ONLY in the Stack while sidePanelVisibleProvider
          // is true (panel open or mid-close-animation). When false the node is
          // absent, so it cannot interfere with AppBar hit-testing on any tab.
          //
          // sidePanelVisibleProvider lives in Riverpod (not widget-local state)
          // so it survives GoRouter rebuilds. AnimatedSlide.onEnd clears it once
          // the close animation completes.
          if (isPanelVisible)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _kPanelWidth,
              child: ClipRect(
                child: AnimatedSlide(
                  duration: _kPanelDuration,
                  curve: Curves.easeInOutCubic,
                  offset: isPanelOpen ? Offset.zero : const Offset(1, 0),
                  onEnd: () {
                    // Animation finished. If the panel is now closed, remove
                    // the Positioned node from the Stack entirely.
                    if (!isPanelOpen) {
                      ref.read(sidePanelVisibleProvider.notifier).state = false;
                    }
                  },
                  child: ProfileSidePanelWidget(
                    onClose: () =>
                        ref.read(sidePanelOpenProvider.notifier).state = false,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _FrostedNavigationBar(
        currentIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}

// ── Frosted Floating Pill Navigation Bar ──────────────────────────────────────

/// Tab definition for the floating pill nav bar.
class _NavTab {
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A frosted-glass floating pill navigation bar.
///
/// Brand bible spec:
/// - Floating pill shape with 100px radius, 20px horizontal margin.
/// - Surface background at 0.92 opacity with backdrop blur showing through.
/// - Dark mode active tab: Sage tint (rgba(207,225,185,0.12)) pill, Sage text (#CFE1B9).
/// - Light mode active tab: Deep Forest (#344E41) solid pill, Warm Cream (#E8EDE0) text.
/// - Inactive tabs: Text Secondary (#9B9894 dark / #6B6864 light).
/// - Icons 22px, labels Label Medium scaled to 11pt for 5-tab fit.
/// - Bottom padding: safe area + 18px.
class _FrostedNavigationBar extends StatefulWidget {
  const _FrostedNavigationBar({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<_NavTab> _tabs = [
    _NavTab(
      icon: Icons.wb_sunny_outlined,
      activeIcon: Icons.wb_sunny_rounded,
      label: 'Today',
    ),
    _NavTab(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Data',
    ),
    _NavTab(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Coach',
    ),
    _NavTab(
      icon: Icons.track_changes_outlined,
      activeIcon: Icons.track_changes_rounded,
      label: 'Progress',
    ),
    _NavTab(
      icon: Icons.trending_up_rounded,
      activeIcon: Icons.trending_up_rounded,
      label: 'Trends',
    ),
  ];

  @override
  State<_FrostedNavigationBar> createState() => _FrostedNavigationBarState();
}

class _FrostedNavigationBarState extends State<_FrostedNavigationBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pillController;

  @override
  void initState() {
    super.initState();
    _pillController = AnimationController(
      vsync: this,
      value: widget.currentIndex.toDouble(),
      lowerBound: -0.5,
      upperBound: 4.5,
    );
  }

  @override
  void didUpdateWidget(covariant _FrostedNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      final sim = SpringSimulation(
        AppMotion.defaultSpatial,
        _pillController.value,
        widget.currentIndex.toDouble(),
        _pillController.velocity,
      );
      _pillController.animateWith(sim);
    }
  }

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final activePillBg =
        colors.primary.withValues(alpha: colors.isDark ? 0.12 : 1.0);
    final activeItemColor =
        colors.isDark ? colors.primary : colors.textOnSage;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMdPlus,
        0,
        AppDimens.spaceMdPlus,
        bottomSafeArea + 18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.navBarBlurSigma,
            sigmaY: AppDimens.navBarBlurSigma,
          ),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabCount = _FrostedNavigationBar._tabs.length;
                final tabWidth = constraints.maxWidth / tabCount;

                return Stack(
                  children: [
                    // Sliding pill — driven by spring physics.
                    AnimatedBuilder(
                      animation: _pillController,
                      builder: (context, _) {
                        return Positioned(
                          left: _pillController.value * tabWidth,
                          top: 0,
                          bottom: 0,
                          width: tabWidth,
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.shapePill,
                                ),
                                child: ColoredBox(
                                  color: activePillBg,
                                  child: const SizedBox.expand(
                                    child: ZPatternOverlay(
                                      variant: ZPatternVariant.sage,
                                      opacity: 0.35,
                                      animate: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Tab icons and labels.
                    Row(
                      children: List.generate(tabCount, (index) {
                        final isActive = index == widget.currentIndex;
                        final tab = _FrostedNavigationBar._tabs[index];

                        return Expanded(
                          child: Semantics(
                            label: tab.label,
                            selected: isActive,
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  widget.onDestinationSelected(index),
                              child: SizedBox(
                                height: 64,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isActive
                                              ? tab.activeIcon
                                              : tab.icon,
                                          size: 22,
                                          color: isActive
                                              ? activeItemColor
                                              : colors.textSecondary,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tab.label,
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                            color: isActive
                                                ? activeItemColor
                                                : colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
