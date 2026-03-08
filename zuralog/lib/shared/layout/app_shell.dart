/// Zuralog Edge Agent — App Shell (5-Tab Bottom Navigation Scaffold).
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

const double _kPanelWidth = 320.0;
const Duration _kPanelDuration = Duration(milliseconds: 300);

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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

  void _onDestinationSelected(WidgetRef ref, int index) {
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
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main content — always full size, no transforms.
          navigationShell,

          // Backdrop — only present when panel is open.
          if (isPanelOpen)
            GestureDetector(
              onTap: () =>
                  ref.read(sidePanelOpenProvider.notifier).state = false,
              child: ColoredBox(
                color: AppColors.black.withValues(alpha: 0.45),
                child: const SizedBox.expand(),
              ),
            ),

          // Side panel — slides in from the right.
          // IgnorePointer prevents the off-screen panel from intercepting
          // taps on the AppBar (bell, avatar, hamburger, bolt) when closed.
          IgnorePointer(
            ignoring: !isPanelOpen,
            child: AnimatedPositioned(
              duration: _kPanelDuration,
              curve: Curves.easeInOutCubic,
              top: 0,
              bottom: 0,
              right: isPanelOpen ? 0 : -_kPanelWidth,
              width: _kPanelWidth,
              child: ProfileSidePanelWidget(
                onClose: () =>
                    ref.read(sidePanelOpenProvider.notifier).state = false,
              ),
            ),
          ),
        ],
      ),
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
