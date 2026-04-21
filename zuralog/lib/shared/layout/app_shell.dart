/// Zuralog Edge Agent — App Shell (3-Tab Bottom Navigation Scaffold).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/state/log_sheet_provider.dart';
import 'package:zuralog/core/theme/app_colors.dart' show AppColorsOf;
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_motion.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastSheetTap;
  bool _isLogSheetOpen = false;
  bool _navCollapsed = false;

  void _setNavCollapsed(bool collapsed) {
    if (_navCollapsed == collapsed) return;
    setState(() => _navCollapsed = collapsed);
  }

  // Position-based collapse with hysteresis:
  //  • pixels ≤ [_kExpandAt]  → expand (at or near top)
  //  • pixels ≥ [_kCollapseAt] → collapse (clearly scrolled down)
  //  • in the dead band in between → no change (prevents jitter)
  //
  // We listen to the base [ScrollNotification] (not just [UserScrollNotification])
  // so momentum-flick scrolls past the top also expand the nav, which fixes
  // the "scrolled all the way up but it didn't expand" bug.
  static const double _kExpandAt = 8;
  static const double _kCollapseAt = 48;

  bool _handleScrollNotification(ScrollNotification n) {
    // Only react to the primary vertical scrollable (ignore nested horizontal
    // carousels, inner bottom-sheet scrollables, etc.).
    if (n.depth != 0) return false;
    if (n.metrics.axis != Axis.vertical) return false;

    final pixels = n.metrics.pixels - n.metrics.minScrollExtent;
    if (pixels <= _kExpandAt) {
      _setNavCollapsed(false);
    } else if (pixels >= _kCollapseAt) {
      _setNavCollapsed(true);
    }
    return false;
  }

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

    setState(() => _isLogSheetOpen = true);
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
    ).whenComplete(() {
      if (mounted) setState(() => _isLogSheetOpen = false);
    });
  }

  void _onDestinationSelected(int index) {
    // Any tab switch immediately expands the nav so users never get stuck in
    // the compact state.
    _setNavCollapsed(false);
    ref.read(hapticServiceProvider).selectionTick();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: widget.navigationShell,
      ),
      bottomNavigationBar: _BottomNavCluster(
        currentIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        isLogSheetOpen: _isLogSheetOpen,
        onLogPressed: _openLogSheet,
        isCollapsed: _navCollapsed,
        onExpandRequest: () => _setNavCollapsed(false),
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
/// - Surface background at [AppDimens.navBarFrostOpacity] with backdrop blur showing through.
/// - Dark mode active tab: Sage tint (rgba(207,225,185,0.12)) pill, Sage text (#CFE1B9).
/// - Light mode active tab: Deep Forest (#344E41) solid pill, Warm Cream (#E8EDE0) text.
/// - Inactive tabs: Text Secondary (#9B9894 dark / #6B6864 light).
/// - Icons 22px, labels Label Medium scaled to 11pt for 3-tab fit.
/// - Bottom padding: safe area + 18px.
class _FrostedNavigationBar extends StatefulWidget {
  const _FrostedNavigationBar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.expandedWidth,
    this.isCollapsed = false,
    this.onExpandRequest,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isCollapsed;
  final VoidCallback? onExpandRequest;

  /// Natural full width of the expanded nav. The expanded content is
  /// always laid out at this width regardless of the current animated
  /// container width — the outer ClipRRect clips visually while the
  /// width animation runs, preventing Flutter's overflow indicator
  /// from painting during the collapse/expand transition.
  final double expandedWidth;

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
      upperBound: 2.5,
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
    final activePillBg = colors.primary.withValues(
      alpha: colors.isDark ? 0.12 : 1.0,
    );
    final activeItemColor = colors.isDark ? colors.primary : colors.textOnSage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapePill),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.navBarBlurSigma,
          sigmaY: AppDimens.navBarBlurSigma,
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: colors.surface.withValues(
              alpha: AppDimens.navBarFrostOpacity,
            ),
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: widget.isCollapsed
                ? _buildCompact(colors, activePillBg, activeItemColor)
                : _buildExpanded(colors, activePillBg, activeItemColor),
          ),
        ),
      ),
    );
  }

  /// Single-tab pill — shows the active tab's icon + label only. Tapping
  /// anywhere on the pill calls [onExpandRequest] so the user can switch
  /// tabs again without having to scroll the page.
  Widget _buildCompact(
    dynamic colors,
    Color activePillBg,
    Color activeItemColor,
  ) {
    final tab = _FrostedNavigationBar._tabs[widget.currentIndex];
    return Semantics(
      key: const ValueKey('nav-compact'),
      button: true,
      label: 'Expand navigation. Current: ${tab.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onExpandRequest,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
            child: ColoredBox(
              color: activePillBg,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: ZPatternOverlay(
                      variant: ZPatternVariant.sage,
                      opacity: 0.35,
                      animate: true,
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.activeIcon,
                          size: 20,
                          color: activeItemColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: activeItemColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Original three-tab navigation with sliding sage pill. Always
  /// renders at [widget.expandedWidth] regardless of the animated
  /// parent container width — the outer ClipRRect clips to the
  /// current pill width during the collapse transition, which avoids
  /// the overflow markers that appear when the inner Row is asked to
  /// render in an intermediate narrow space.
  Widget _buildExpanded(
    dynamic colors,
    Color activePillBg,
    Color activeItemColor,
  ) {
    return OverflowBox(
      key: const ValueKey('nav-expanded'),
      alignment: Alignment.centerLeft,
      minWidth: 0,
      maxWidth: double.infinity,
      child: SizedBox(
        width: widget.expandedWidth,
        height: 64,
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
                                // OverflowBox forces a wide non-square context
                                // so BoxFit.cover creates vertical overflow,
                                // giving the alignment drift room to move.
                                // ClipRRect above handles the visual clipping.
                                child: OverflowBox(
                                  maxWidth: double.infinity,
                                  maxHeight: double.infinity,
                                  child: SizedBox(
                                    width: 160,
                                    height: 48,
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
                            onTap: () => widget.onDestinationSelected(index),
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
                                        isActive ? tab.activeIcon : tab.icon,
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
      );
  }
}

// ── Log Pill Button ───────────────────────────────────────────────────────────

/// A 64×64 circular primary-filled pill hosting the `+` log icon.
///
/// The icon rotates 45° when [isOpen] is true and reverses back to 0° when
/// [isOpen] flips to false. The parent owns the `isOpen` flag — this widget
/// is a pure view over that flag plus a tap callback.
class _LogPillButton extends StatefulWidget {
  const _LogPillButton({super.key, required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  State<_LogPillButton> createState() => _LogPillButtonState();
}

class _LogPillButtonState extends State<_LogPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isOpen ? 1.0 : 0.0,
    );
    _turns = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_rotation);
  }

  @override
  void didUpdateWidget(covariant _LogPillButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      if (widget.isOpen) {
        _rotation.forward();
      } else {
        _rotation.reverse();
      }
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // In dark mode: fill is Sage, icon is Deep Forest (#344E41).
    // In light mode: fill is Deep Forest, icon is textOnSage (Warm Cream).
    final fill = colors.primary;
    final iconColor = colors.isDark
        ? const Color(0xFF344E41)
        : colors.textOnSage;

    // Shadow removed so the log pill's silhouette matches the frosted nav
    // pill's flat edge — the two sibling pills now read as the same 64pt
    // height. Brand pattern overlay ties the log pill visually to the
    // frosted nav and honours the "pattern never static" house rule.
    return Semantics(
      button: true,
      label: 'Log new entry',
      child: Material(
        color: fill,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ZPatternOverlay(
                  variant: ZPatternVariant.sage,
                  opacity: 0.45,
                  blendMode: BlendMode.multiply,
                  animate: true,
                ),
                Center(
                  child: RotationTransition(
                    turns: _turns,
                    child: Icon(Icons.add_rounded, size: 22, color: iconColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Test-only public alias for [_LogPillButton].
@visibleForTesting
class LogPillButtonForTest extends StatelessWidget {
  const LogPillButtonForTest({
    super.key,
    required this.isOpen,
    required this.onTap,
  });

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _LogPillButton(
    key: const Key('bottom-nav-log-pill'),
    isOpen: isOpen,
    onTap: onTap,
  );
}

// ── Bottom Nav Cluster ────────────────────────────────────────────────────────

/// Groups the frosted nav pill and the log pill into a single centered row
/// at the bottom safe-area offset. Owns the bottom-margin padding so the
/// nav bar widget no longer has to.
///
/// Supports a scroll-aware collapse: when [isCollapsed] is true the nav
/// pill shrinks to a single-tab width showing only the current tab, and
/// tapping it calls [onExpandRequest] to restore the full nav. The log
/// pill always stays the same — it's the primary action, always tappable.
class _BottomNavCluster extends StatelessWidget {
  const _BottomNavCluster({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isLogSheetOpen,
    required this.onLogPressed,
    this.isCollapsed = false,
    this.onExpandRequest,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isLogSheetOpen;
  final VoidCallback onLogPressed;
  final bool isCollapsed;
  final VoidCallback? onExpandRequest;

  /// Width of the nav pill when collapsed to a single tab.
  static const double _collapsedWidth = 112;

  /// Width of the log pill itself (see [_LogPillButton]).
  static const double _logPillWidth = 56;

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMdPlus,
        0,
        AppDimens.spaceMdPlus,
        bottomSafeArea + 18,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedWidth =
              (constraints.maxWidth - _logPillWidth - AppDimens.spaceSm)
                  .clamp(_collapsedWidth, double.infinity);
          // Nav + gap + log pill always sums to the same total so the
          // Row never overflows during the animation: when nav shrinks,
          // the gap grows by the exact same amount. Both sides animate
          // on identical duration + curve so they stay in sync.
          final navWidth =
              isCollapsed ? _collapsedWidth : expandedWidth;
          final gapWidth = expandedWidth + AppDimens.spaceSm - navWidth;
          const animDuration = Duration(milliseconds: 280);
          const animCurve = Curves.easeOutCubic;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: animDuration,
                curve: animCurve,
                width: navWidth,
                child: _FrostedNavigationBar(
                  currentIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  isCollapsed: isCollapsed,
                  onExpandRequest: onExpandRequest,
                  expandedWidth: expandedWidth,
                ),
              ),
              AnimatedContainer(
                duration: animDuration,
                curve: animCurve,
                width: gapWidth,
              ),
              _LogPillButton(
                key: const Key('bottom-nav-log-pill'),
                isOpen: isLogSheetOpen,
                onTap: onLogPressed,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Test-only public alias for [_BottomNavCluster].
@visibleForTesting
class BottomNavClusterForTest extends StatelessWidget {
  const BottomNavClusterForTest({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isLogSheetOpen,
    required this.onLogPressed,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isLogSheetOpen;
  final VoidCallback onLogPressed;

  @override
  Widget build(BuildContext context) => _BottomNavCluster(
    currentIndex: currentIndex,
    onDestinationSelected: onDestinationSelected,
    isLogSheetOpen: isLogSheetOpen,
    onLogPressed: onLogPressed,
  );
}
