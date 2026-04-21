/// Zuralog — Workout Resume Gate.
///
/// One-shot widget that runs a single check on cold start for a stranded
/// in-progress workout draft and, if one exists and is still fresh, shows a
/// [ZAlertDialog] offering to resume or discard it. Wraps the router's
/// `builder` child so the dialog can push onto the live GoRouter Navigator.
///
/// Design notes:
/// - This is intentionally *not* wired into the router's `redirect` callback
///   because that callback runs on every navigation. A one-shot gate at the
///   root keeps the hot navigation path clean.
/// - The gate never mutates the draft itself beyond discarding; tapping
///   "Resume" navigates to the session screen and lets `WorkoutSessionNotifier`
///   rehydrate its own state from SharedPreferences.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/workout/data/workout_resume_service.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Provides a cheap, synchronous [WorkoutResumeService] backed by the
/// already-initialized [prefsProvider].
final workoutResumeServiceProvider = Provider<WorkoutResumeService>((ref) {
  return WorkoutResumeService(ref.watch(prefsProvider));
});

/// Wraps [child] (typically the router's child) and, once per app launch,
/// prompts the user to resume an in-progress workout if one is stored.
class WorkoutResumeGate extends ConsumerStatefulWidget {
  const WorkoutResumeGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WorkoutResumeGate> createState() => _WorkoutResumeGateState();
}

class _WorkoutResumeGateState extends ConsumerState<WorkoutResumeGate> {
  /// Guards against re-entry — the gate must prompt at most once per launch.
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // Defer to the next frame so the first navigator route has mounted and
    // [GoRouter.of] is reachable from the dialog's context.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_checked) return;
    _checked = true;
    if (!mounted) return;

    final service = ref.read(workoutResumeServiceProvider);
    final resumable = service.checkResumable();
    if (resumable == null) return;

    if (!mounted) return;

    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Resume your workout?',
      body: _formatBody(resumable),
      confirmLabel: 'Resume',
      cancelLabel: 'Discard',
    );

    if (!mounted) return;

    if (confirmed == true) {
      // The session screen reads the draft back via WorkoutSessionNotifier.
      GoRouter.of(context).push(RouteNames.workoutSessionPath);
    } else if (confirmed == false) {
      // Explicit discard — wipe draft AND any leftover rest-timer scalars.
      await service.discard();
      await ref.read(restTimerStorageProvider).clear();
    }
    // If the dialog was dismissed by tapping outside (null), leave the draft
    // alone so the prompt re-appears on the next cold start.
  }

  /// Builds a one-line body like `Started 14 min ago · 3 exercises`.
  String _formatBody(ResumableWorkout r) {
    final minutes = r.age.inMinutes;
    final agoStr = minutes < 1
        ? 'just now'
        : minutes == 1
            ? '1 min ago'
            : '$minutes min ago';
    final ex = r.exerciseCount;
    final exStr = ex == 0
        ? 'no exercises yet'
        : ex == 1
            ? '1 exercise'
            : '$ex exercises';
    return 'Started $agoStr · $exStr';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
