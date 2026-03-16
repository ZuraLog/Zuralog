/// Zuralog Edge Agent — App Shell (5-Tab Bottom Navigation Scaffold).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/state/log_sheet_provider.dart';
import 'package:zuralog/core/state/side_panel_provider.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/profile_side_panel.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_sheet.dart';

const double _kPanelWidth = 320.0;
const Duration _kPanelDuration = Duration(milliseconds: 300);

class AppShell extends ConsumerStatefulWidget {
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
                color: AppColors.black.withValues(alpha: 0.45),
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
    // Dark mode → charcoal tint at 0.85 opacity so blur shows through.
    // Light mode → translucent scaffold bg for frosted glass effect.
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final opacity = isDark ? 0.85 : AppDimens.navBarFrostOpacity;

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
                return AppTextStyles.bodySmall
                    .copyWith(color: AppColors.primary);
              }
              return AppTextStyles.bodySmall
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
