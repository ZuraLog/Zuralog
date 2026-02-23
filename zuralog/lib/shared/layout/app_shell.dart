/// Zuralog Edge Agent — App Shell (Bottom Navigation Scaffold).
///
/// [AppShell] is the persistent scaffold rendered by [StatefulShellRoute].
/// It houses the tab body (the active branch's navigator) and a frosted-glass
/// [NavigationBar] at the bottom with three destinations: Dashboard, Coach,
/// and Apps.
///
/// **Push-reveal side panel:** When [sidePanelOpenProvider] is `true` the
/// entire scaffold (content + bottom nav) slides LEFT by 80 % of the screen
/// width using an animated [Transform.translate]. The [ProfileSidePanelWidget]
/// occupies the right 80 % of the screen simultaneously. Both areas are
/// visible at the same time — no scrim / dimming is applied to the 20 %
/// visible content strip.
///
/// Tapping anywhere on the 20 % visible content strip dismisses the panel.
///
/// **Frosted glass effect:** A [BackdropFilter] with a Gaussian blur is
/// applied beneath the [NavigationBar] to create a translucent overlay that
/// blurs the content scrolling behind it, matching the design spec.
///
/// **Tab persistence:** Tab state is preserved across switches because the
/// router uses [StatefulShellRoute.indexedStack], meaning each branch keeps
/// its navigator stack alive while inactive.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/state/side_panel_provider.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/profile_side_panel.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// The fraction of the screen width the panel occupies (right side).
const double _kPanelFraction = 0.80;

/// Duration of the push-reveal animation.
const Duration _kAnimDuration = Duration(milliseconds: 280);

// ── AppShell ──────────────────────────────────────────────────────────────────

/// The root scaffold for all tabbed screens.
///
/// Converts to a [ConsumerStatefulWidget] so it can watch [sidePanelOpenProvider]
/// and drive the push-reveal animation. The widget tree is:
///
/// ```
/// Stack (fills screen)
/// ├── AnimatedBuilder → Transform.translate (entire scaffold slides left)
/// │   └── Scaffold (body + frosted bottom nav)
/// │       └── GestureDetector (tap-to-close when panel is open)
/// └── AnimatedBuilder → Transform.translate (panel slides in from right)
///     └── ProfileSidePanelWidget (the 80 % right panel)
/// ```
///
/// Usage: This widget is constructed exclusively by the [StatefulShellRoute]
/// builder in [app_router.dart]; do not instantiate it elsewhere.
class AppShell extends ConsumerStatefulWidget {
  /// Creates an [AppShell] with the given [navigationShell].
  ///
  /// [navigationShell] is provided by the GoRouter framework and must not
  /// be stored beyond the lifetime of the build call.
  const AppShell({super.key, required this.navigationShell});

  /// The stateful navigation shell from GoRouter that manages branch stacks.
  final StatefulNavigationShell navigationShell;

  /// The three navigation destinations displayed in the bottom bar.
  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_rounded),
      label: 'Home',
      selectedIcon: Icon(Icons.home_rounded),
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_rounded),
      label: 'Coach',
      selectedIcon: Icon(Icons.chat_bubble_rounded),
    ),
    NavigationDestination(
      icon: Icon(Icons.extension_rounded),
      label: 'Apps',
      selectedIcon: Icon(Icons.extension_rounded),
    ),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: _kAnimDuration);
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);

    // Sync animation with the provider in case it is restored.
    final isOpen = ref.read(sidePanelOpenProvider);
    if (isOpen) _animCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// Closes the side panel by animating backward and clearing provider state.
  void _closePanel() {
    _animCtrl.reverse().then((_) {
      if (mounted) {
        ref.read(sidePanelOpenProvider.notifier).state = false;
      }
    });
  }

  /// Switches to the tapped tab branch.
  ///
  /// Passing [initialLocation: true] restores the branch to its initial
  /// location when the user re-taps an already-active tab, matching
  /// the standard iOS behavior of returning to the root.
  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Listen to provider so external callers (e.g. dashboard avatar) can
    // trigger the open animation.
    final isOpen = ref.watch(sidePanelOpenProvider);

    // If provider opened externally, sync the animation controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isOpen && _animCtrl.status == AnimationStatus.dismissed) {
        _animCtrl.forward();
      } else if (!isOpen && _animCtrl.status == AnimationStatus.completed) {
        _animCtrl.reverse();
      }
    });

    return Stack(
      children: [
        // ── Scaffold (slides left when panel opens) ──────────────────────
        AnimatedBuilder(
          animation: _slideAnim,
          builder: (context, child) {
            final dx = -screenWidth * _kPanelFraction * _slideAnim.value;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: GestureDetector(
            // Tap the 20 % visible strip to close the panel.
            onTap: isOpen ? _closePanel : null,
            child: Scaffold(
              // extendBody allows the shell body to render beneath the nav bar,
              // so content can scroll behind the frosted glass.
              extendBody: true,
              body: widget.navigationShell,
              bottomNavigationBar: _FrostedNavigationBar(
                currentIndex: widget.navigationShell.currentIndex,
                surfaceColor: surfaceColor,
                onDestinationSelected: _onDestinationSelected,
              ),
            ),
          ),
        ),

        // ── Side Panel (slides in from the right) ────────────────────────
        AnimatedBuilder(
          animation: _slideAnim,
          builder: (context, child) {
            // Panel sits at the right edge and slides in from off-screen right.
            // When fully open: panel left edge = 20 % of screen width.
            // When fully closed: panel left edge = 100 % (off-screen).
            final panelWidth = screenWidth * _kPanelFraction;
            final panelLeft = screenWidth - panelWidth * _slideAnim.value;
            return Positioned(
              top: 0,
              bottom: 0,
              left: panelLeft,
              width: panelWidth,
              child: child!,
            );
          },
          child: ProfileSidePanelWidget(onClose: _closePanel),
        ),
      ],
    );
  }
}

// ── Frosted Navigation Bar ────────────────────────────────────────────────────

/// A frosted-glass [NavigationBar] rendered inside a [BackdropFilter].
///
/// The [ClipRect] confines the blur to the navigation bar area, and
/// [BackdropFilter] applies a Gaussian blur to whatever is behind it.
/// The translucent [Container] on top of the blur gives the frosted-glass
/// effect a tinted fill, and the [NavigationBar] itself is transparent so
/// the background shows through.
class _FrostedNavigationBar extends StatelessWidget {
  /// Creates a [_FrostedNavigationBar].
  ///
  /// - [currentIndex] — the currently selected tab index (0-based).
  /// - [surfaceColor] — the theme's surface color used for the frosted tint.
  /// - [onDestinationSelected] — callback when a destination is tapped.
  const _FrostedNavigationBar({
    required this.currentIndex,
    required this.surfaceColor,
    required this.onDestinationSelected,
  });

  /// The active tab index.
  final int currentIndex;

  /// The base surface color used for the frosted tint overlay.
  final Color surfaceColor;

  /// Callback invoked with the tapped destination index.
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.navBarBlurSigma,
          sigmaY: AppDimens.navBarBlurSigma,
        ),
        child: Container(
          // Translucent tint overlay — blends with the blurred background.
          color: surfaceColor.withValues(alpha: AppDimens.navBarFrostOpacity),
          child: NavigationBar(
            // Transparent so the frosted-glass container's color shows through.
            backgroundColor: Colors.transparent,
            // Remove the default surface tint from Material 3.
            surfaceTintColor: Colors.transparent,
            // Elevation 0 to avoid a shadow that would clash with the blur.
            elevation: 0,
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            // indicatorColor deferred to NavigationBarTheme in AppTheme (AppColors.primary at 0.2 opacity).
            destinations: AppShell._destinations,
          ),
        ),
      ),
    );
  }
}
