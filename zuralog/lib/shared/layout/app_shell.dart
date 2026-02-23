/// Zuralog Edge Agent — App Shell (Bottom Navigation Scaffold).
///
/// [AppShell] is the persistent scaffold rendered by [StatefulShellRoute].
/// It houses the tab body (the active branch's navigator) and a frosted-glass
/// [NavigationBar] at the bottom with three destinations: Dashboard, Coach,
/// and Apps.
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
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// The root scaffold for all tabbed screens.
///
/// Wraps [navigationShell] as the body and renders a frosted-glass
/// [NavigationBar] at the bottom. Tabs correspond to the three main
/// feature areas of the app.
///
/// Usage: This widget is constructed exclusively by the [StatefulShellRoute]
/// builder in [app_router.dart]; do not instantiate it elsewhere.
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface;

    return Scaffold(
      // extendBody allows the shell body to render beneath the nav bar,
      // so content can scroll behind the frosted glass.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FrostedNavigationBar(
        currentIndex: navigationShell.currentIndex,
        surfaceColor: surfaceColor,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  /// Switches to the tapped tab branch.
  ///
  /// Passing [initialLocation: true] restores the branch to its initial
  /// location when the user re-taps an already-active tab, matching
  /// the standard iOS behavior of returning to the root.
  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          // Translucent tint overlay — blends with the blurred background.
          color: surfaceColor.withValues(alpha: 0.85),
          child: NavigationBar(
            // Transparent so the frosted-glass container's color shows through.
            backgroundColor: Colors.transparent,
            // Remove the default surface tint from Material 3.
            surfaceTintColor: Colors.transparent,
            // Elevation 0 to avoid a shadow that would clash with the blur.
            elevation: 0,
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            indicatorColor: AppColors.primary.withValues(alpha: 0.3),
            destinations: AppShell._destinations,
          ),
        ),
      ),
    );
  }
}
