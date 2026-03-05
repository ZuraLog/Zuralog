/// Zuralog Edge Agent — App Shell (5-Tab Bottom Navigation Scaffold).
///
/// [AppShell] is the persistent scaffold rendered by [StatefulShellRoute].
/// It houses the active branch navigator and a frosted-glass 5-tab
/// [NavigationBar] at the bottom.
///
/// **5 tabs:** Today · Data · Coach · Progress · Trends
///
/// **Profile Side Panel:** A right-side push-reveal drawer controlled by
/// [sidePanelOpenProvider]. Tapping the [ProfileAvatarButton] in any tab
/// AppBar opens the panel; tapping the backdrop or navigating from inside
/// closes it. The main content slides left while the panel slides in from
/// the right (320px wide, 400ms easeInOutCubic).
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
import 'package:zuralog/core/state/side_panel_provider.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/profile_side_panel.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Width of the side panel when fully open.
const double _kPanelWidth = 320.0;

/// Duration for the push-reveal open/close animation.
const Duration _kPanelDuration = Duration(milliseconds: 400);

/// Easing for the push-reveal.
const Curve _kPanelCurve = Curves.easeInOutCubic;

// ── AppShell ──────────────────────────────────────────────────────────────────

/// The root scaffold for all tabbed screens.
///
/// Wraps the GoRouter [navigationShell] with a frosted-glass [NavigationBar]
/// and a right-side [ProfileSidePanelWidget] push-reveal drawer.
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
    // Close side panel on tab switch.
    if (ref.read(sidePanelOpenProvider)) {
      ref.read(sidePanelOpenProvider.notifier).state = false;
    }
    ref.read(hapticServiceProvider).selectionTick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPanelOpen = ref.watch(sidePanelOpenProvider);

    return Scaffold(
      // extendBody lets tab content render behind the translucent nav bar.
      extendBody: true,
      body: Stack(
        children: [
          // ── Main content (slides left when panel opens) ───────────────────
          AnimatedSlide(
            offset: isPanelOpen
                ? Offset(-_kPanelWidth / MediaQuery.sizeOf(context).width, 0)
                : Offset.zero,
            duration: _kPanelDuration,
            curve: _kPanelCurve,
            child: navigationShell,
          ),

          // ── Backdrop (tapping closes panel) ──────────────────────────────
          AnimatedOpacity(
            opacity: isPanelOpen ? 0.35 : 0.0,
            duration: _kPanelDuration,
            curve: _kPanelCurve,
            child: IgnorePointer(
              ignoring: !isPanelOpen,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(sidePanelOpenProvider.notifier).state = false,
                child: const ColoredBox(
                  color: AppColors.black,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),

          // ── Side panel (slides in from right) ────────────────────────────
          AnimatedPositioned(
            duration: _kPanelDuration,
            curve: _kPanelCurve,
            top: 0,
            bottom: 0,
            right: isPanelOpen
                ? 0
                : -_kPanelWidth,
            width: _kPanelWidth,
            child: ProfileSidePanelWidget(
              onClose: () =>
                  ref.read(sidePanelOpenProvider.notifier).state = false,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FrostedNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(ref, index),
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
    // Dark mode → near-opaque OLED black so icons remain visible over blur.
    // Light mode → translucent white for frosted glass effect.
    final bgColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final opacity = isDark ? 0.92 : AppDimens.navBarFrostOpacity;

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
            color: bgColor.withValues(alpha: opacity),
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
