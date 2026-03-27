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
/// - Surface (#1E1E1E) background with backdrop blur showing through.
/// - Active tab: Sage tint pill (rgba(207,225,185,0.12)) behind icon+label,
///   Sage text (#CFE1B9).
/// - Inactive tabs: Text Secondary (#9B9894).
/// - Icons 20-22px, labels Label Medium (13pt Medium 500).
/// - Bottom padding: safe area + 18px.
class _FrostedNavigationBar extends StatelessWidget {
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

  /// Sage tint pill behind the active tab: rgba(207, 225, 185, 0.12).
  static const Color _sageTint = Color(0x1FCFE1B9);

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      // 20px horizontal margin from screen edges, 18px + safe area from bottom.
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
              // Surface background at 0.92 opacity — translucent enough for
              // the blur to show through but solid enough to read the labels.
              color: colors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isActive = index == currentIndex;
                final tab = _tabs[index];

                return Expanded(
                  child: Semantics(
                    label: tab.label,
                    selected: isActive,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDestinationSelected(index),
                      child: SizedBox(
                        // Ensures minimum 44px touch target height.
                        height: 64,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? _sageTint : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppDimens.shapePill,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? tab.activeIcon : tab.icon,
                                  size: 22,
                                  color: isActive
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tab.label,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: isActive
                                        ? colors.primary
                                        : colors.textSecondary,
                                    // Scaled down from 13pt to 11pt so all 5
                                    // labels (including "Progress") fit inside
                                    // the pill without clipping.
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
          ),
        ),
      ),
    );
  }
}
