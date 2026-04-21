/// Zuralog — Rest Timer Morph Slot.
///
/// Inline slot that sits directly above `_BottomActions` in the workout
/// session screen. Renders the mini pill when the rest timer is visible
/// and minimized, and collapses to zero height otherwise. The collapse/
/// expand is animated with [AnimatedSize] so the pill appears to grow out
/// of (and disappear back into) the top edge of the bottom action bar.
///
/// Pairs with `RestTimerOverlay`'s fade + scale animation so the full
/// sheet and the mini pill feel like a single morphing element.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/workout/presentation/widgets/rest_timer_sheet.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

/// Inline slot that morphs between empty and the mini pill.
///
/// The inline slot is only populated when the timer is visible AND
/// minimized. When the full sheet is expanded, the slot collapses to
/// zero height (the sheet itself renders as a `Positioned` overlay in
/// the screen's Stack).
class RestTimerMorph extends ConsumerWidget {
  const RestTimerMorph({super.key});

  /// Matches `RestTimerOverlay`'s sheet animation so the pill and sheet
  /// feel like a single morphing element.
  static const Duration _sizeDuration = Duration(milliseconds: 320);

  /// Material 3 "emphasized decelerate" — a more expressive ease-out than
  /// the stock [Curves.easeOutCubic], used here to match the full sheet.
  static const Curve _sizeCurve = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Shorter crossfade for swapping the pill child in/out.
  static const Duration _switchDuration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final showPill = timer.isVisible && timer.isMinimized;

    // Stable child keys so `AnimatedSwitcher` crossfades between them.
    final Widget child = showPill
        ? const KeyedSubtree(
            key: ValueKey('rest-timer-morph-pill'),
            child: RestTimerMiniBanner(),
          )
        : const SizedBox.shrink(
            key: ValueKey('rest-timer-morph-empty'),
          );

    return AnimatedSize(
      duration: _sizeDuration,
      curve: _sizeCurve,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: _switchDuration,
        switchInCurve: _sizeCurve,
        switchOutCurve: _sizeCurve,
        transitionBuilder: (child, animation) {
          // Fade + subtle scale (0.96 → 1.0) so the pill feels like it's
          // emerging from / receding into the bottom action bar.
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}
