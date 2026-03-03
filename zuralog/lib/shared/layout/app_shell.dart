/// Zuralog Edge Agent — App Shell (5-Tab Bottom Navigation Scaffold).
///
/// [AppShell] is the persistent scaffold rendered by [StatefulShellRoute].
/// It houses the active branch navigator and a frosted-glass 5-tab
/// [NavigationBar] at the bottom.
///
/// **5 tabs:** Today · Data · Coach · Progress · Trends
///
/// Settings, Profile, and Integrations are accessed from header icons on
/// individual screens — not from the bottom bar.
///
/// **Frosted glass effect:** A [BackdropFilter] with Gaussian blur is applied
/// beneath the [NavigationBar]. The translucent background blurs the content
/// scrolling behind it, matching the design spec (surface-900 at 70% opacity).
///
/// **Tab persistence:** State is preserved across switches via
/// [StatefulShellRoute.indexedStack] — each branch keeps its navigator stack
/// alive while inactive.
///
/// **Haptic feedback:** A selection tick fires on every tab switch, respecting
/// the user's haptic preference via [hapticServiceProvider].
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── AppShell ──────────────────────────────────────────────────────────────────

/// The root scaffold for all tabbed screens.
///
/// Wraps the GoRouter [navigationShell] with a frosted-glass [NavigationBar]
/// containing 5 destinations: Today, Data, Coach, Progress, Trends.
///
/// Usage: Constructed exclusively by the [StatefulShellRoute] builder in
/// [app_router.dart]; do not instantiate elsewhere.
class AppShell extends ConsumerWidget {
  /// Creates the [AppShell] for the given [navigationShell].
  const AppShell({super.key, required this.navigationShell});

  /// The stateful navigation shell from GoRouter managing per-branch stacks.
  final StatefulNavigationShell navigationShell;

  /// The 5 tab destinations in display order.
  ///
  /// Order must match the [StatefulShellBranch] index in [app_router.dart]:
  /// 0=Today, 1=Data, 2=Coach, 3=Progress, 4=Trends.
  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.wb_sunny_outlined),
      selectedIcon: Icon(Icons.wb_sunny_rounded),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Data',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'Coach',
    ),
    NavigationDestination(
      icon: Icon(Icons.track_changes_outlined),
      selectedIcon: Icon(Icons.track_changes_rounded),
      label: 'Progress',
    ),
    NavigationDestination(
      icon: Icon(Icons.trending_up_rounded),
      selectedIcon: Icon(Icons.trending_up_rounded),
      label: 'Trends',
    ),
  ];

  /// Switches to the given [index] branch and fires a haptic selection tick.
  ///
  /// Re-tapping the active tab restores the branch to its initial location
  /// (standard iOS "scroll to top / pop to root" behaviour).
  void _onDestinationSelected(WidgetRef ref, int index) {
    ref.read(hapticServiceProvider).selectionTick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // extendBody lets tab content render behind the translucent nav bar.
      // Each tab root screen must add appropriate bottom padding to avoid
      // content being obscured by the nav bar.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FrostedNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onDestinationSelected(ref, index),
      ),
    );
  }
}

// ── Frosted Navigation Bar ────────────────────────────────────────────────────

/// A frosted-glass [NavigationBar] with 5 destinations.
///
/// Uses [BackdropFilter] + Gaussian blur to blur the scrolling content behind
/// the bar. A translucent container gives the frosted tint. The
/// [NavigationBar] itself is fully transparent so the blur shows through.
///
/// Per design spec: no indicator pill — icon/label color change is sufficient
/// to communicate the active tab. The active color is [AppColors.primary]
/// (Sage Green) and inactive is [AppColors.textTertiary].
class _FrostedNavigationBar extends StatelessWidget {
  const _FrostedNavigationBar({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  /// The currently active tab index (0-based).
  final int currentIndex;

  /// Callback invoked with the tapped destination index.
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the scaffold background as the frosted glass tint colour.
    // Dark mode → #000000 at 70% (OLED black, translucent).
    // Light mode → #FFFFFF at 70% (white, translucent).
    final bgColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.navBarBlurSigma,
          sigmaY: AppDimens.navBarBlurSigma,
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            // Design spec: no indicator pill — color change only.
            indicatorColor: Colors.transparent,
            // Active: Sage Green. Inactive: text-tertiary (de-emphasised).
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppColors.primary);
              }
              return const IconThemeData(color: AppColors.textTertiary);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTextStyles.caption
                    .copyWith(color: AppColors.primary);
              }
              return AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary);
            }),
          ),
          child: Container(
            color: bgColor.withValues(alpha: AppDimens.navBarFrostOpacity),
            child: NavigationBar(
              // Transparent — frosted container provides the visual background.
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              // 200ms cross-fade for icon/label transitions.
              animationDuration: const Duration(milliseconds: 200),
              destinations: AppShell._destinations,
            ),
          ),
        ),
      ),
    );
  }
}
