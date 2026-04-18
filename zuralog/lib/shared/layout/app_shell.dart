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
      body: widget.navigationShell,
      bottomNavigationBar: _BottomNavCluster(
        currentIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        isLogSheetOpen: _isLogSheetOpen,
        onLogPressed: _openLogSheet,
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
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ZPatternOverlay(
                  variant: ZPatternVariant.sage,
                  opacity: 0.38,
                  animate: true,
                ),
                Center(
                  child: RotationTransition(
                    turns: _turns,
                    child: Icon(Icons.add_rounded, size: 24, color: iconColor),
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
class _BottomNavCluster extends StatelessWidget {
  const _BottomNavCluster({
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
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMdPlus,
        0,
        AppDimens.spaceMdPlus,
        bottomSafeArea + 18,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _FrostedNavigationBar(
              currentIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _LogPillButton(
            key: const Key('bottom-nav-log-pill'),
            isOpen: isLogSheetOpen,
            onTap: onLogPressed,
          ),
        ],
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
