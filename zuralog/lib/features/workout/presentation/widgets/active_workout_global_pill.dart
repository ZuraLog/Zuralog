/// Zuralog — Global Active Workout Pill.
///
/// Floating pill shown above the bottom nav cluster on every tab
/// when a workout is active, EXCEPT the workout screen itself.
/// Tapping the pill returns the user to the workout session.
///
/// Composition rules:
/// - Reads [activeWorkoutSnapshotProvider] so it stays atomic with the
///   session + rest providers.
/// - Suppresses itself when the current matched location starts with
///   [RouteNames.workoutSessionPath]. In practice the workout session
///   screen is pushed OUTSIDE the shell, so [AppShell] is unmounted
///   when on that route anyway — the check is defense-in-depth.
/// - Uses [AnimatedSize] so the surrounding bottom-nav column rebalances
///   smoothly rather than jumping layout when the pill appears / hides.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/providers/active_workout_provider.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Floating pill shown above the bottom-nav cluster when a workout is
/// active. Tap returns the user to the live workout session screen.
class ActiveWorkoutGlobalPill extends ConsumerWidget {
  const ActiveWorkoutGlobalPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(activeWorkoutSnapshotProvider);
    final currentLoc = GoRouterState.of(context).matchedLocation;
    final isOnWorkoutScreen =
        currentLoc.startsWith(RouteNames.workoutSessionPath);

    final shouldShow = snapshot.hasActiveSession && !isOnWorkoutScreen;

    // AnimatedSize collapses the vertical space when the pill is hidden,
    // so its absence never shifts the bottom-nav cluster's height.
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: const Cubic(0.05, 0.7, 0.1, 1.0),
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        child: shouldShow
            ? ActivePillBody(
                snapshot: snapshot,
                key: const ValueKey('pill'),
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}

/// Rendered body of the pill. Exposed (non-private) so widget tests can
/// target it with `find.byType`.
@visibleForTesting
class ActivePillBody extends ConsumerWidget {
  const ActivePillBody({required this.snapshot, super.key});

  final ActiveWorkoutSnapshot snapshot;

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Discard workout?',
      body: "Your exercises and sets won't be saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep',
      isDestructive: true,
    );
    if (confirmed == true) {
      ref.read(workoutSessionProvider.notifier).discardSession();
      ref.read(restTimerProvider.notifier).skip();
    }
  }

  void _resume(BuildContext context) {
    HapticFeedback.selectionClick();
    GoRouter.of(context).push(RouteNames.workoutSessionPath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final isResting = snapshot.isResting;

    final elapsed = snapshot.workoutElapsed;
    final rest = snapshot.rest.remaining;
    final elapsedStr = _fmtDuration(elapsed);
    final restStr = _fmtDuration(rest);

    final textColor = isResting ? colors.primary : colors.textPrimary;
    final iconColor = isResting ? colors.primary : colors.textSecondary;
    final bgColor = isResting
        ? colors.primary.withValues(alpha: 0.12)
        : colors.surfaceOverlay;
    final borderColor = isResting
        ? colors.primary.withValues(alpha: 0.40)
        : colors.textSecondary.withValues(alpha: 0.18);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, AppDimens.spaceXs, 0, 0),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status label — icon + live timer text.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isResting
                            ? Icons.timer_outlined
                            : Icons.fitness_center_rounded,
                        size: AppDimens.iconMd,
                        color: iconColor,
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Text(
                        isResting ? 'Rest  $restStr' : 'Workout  $elapsedStr',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: textColor,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                // Separator.
                Container(width: 1, height: 32, color: borderColor),
                // Resume.
                TextButton(
                  onPressed: () => _resume(context),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    'Resume',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Separator.
                Container(width: 1, height: 32, color: borderColor),
                // Discard.
                IconButton(
                  onPressed: () => _discard(context, ref),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: AppDimens.iconSm,
                    color: colors.error,
                  ),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }
}
