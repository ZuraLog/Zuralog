/// Zuralog — Progress Tab Riverpod Providers.
///
/// All state for the Progress tab (Progress Home, Goals, Achievements,
/// Weekly Report, Journal) is managed here. Screens read from these
/// providers and trigger invalidations via [ref.invalidate].
///
/// Provider inventory:
/// - [progressRepositoryProvider]   — singleton repository
/// - [progressHomeProvider]         — async aggregated Progress Home data
/// - [goalsProvider]                — async list of all user goals
/// - [achievementsProvider]         — async achievement gallery
/// - [weeklyReportProvider]         — async latest weekly report
/// - [journalProvider]              — async first page of journal entries
/// - [selectedGoalIdProvider]       — transient: ID of goal being viewed
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/progress/data/progress_repository.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [ProgressRepositoryInterface] wired to the shared [apiClientProvider].
///
/// Always uses the real [ProgressRepository] backed by the Cloud Brain API.
/// Mock repositories are available for unit tests via provider overrides.
final progressRepositoryProvider = Provider<ProgressRepositoryInterface>((ref) {
  return ProgressRepository(apiClient: ref.read(apiClientProvider));
});

// ── Progress Home ─────────────────────────────────────────────────────────────

/// Async provider for the aggregated Progress Home screen data.
///
/// Invalidate with [ref.invalidate(progressHomeProvider)] after a
/// pull-to-refresh or after mutating goals/streaks.
///
/// Uses the never-error pattern: catches all exceptions and returns
/// empty data so the UI always reaches the `data:` branch.
final progressHomeProvider = FutureProvider<ProgressHomeData>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  try {
    return await repo.getProgressHome();
  } catch (_) {
    return const ProgressHomeData(
      goals: [],
      streaks: [],
      wow: WoWSummary(weekLabel: '', metrics: []),
      recentAchievements: [],
    );
  }
});

// ── Goals ─────────────────────────────────────────────────────────────────────

/// Async provider for the full list of user goals.
///
/// Invalidate with [ref.invalidate(goalsProvider)] after any CRUD operation.
///
/// Uses the never-error pattern: catches all exceptions and returns
/// an empty list so the UI always reaches the `data:` branch.
final goalsProvider = FutureProvider<GoalList>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  try {
    return await repo.getGoals();
  } catch (_) {
    return const GoalList(goals: []);
  }
});

/// Transient state: the ID of the goal currently being viewed/edited.
///
/// Set before navigating to [GoalDetailScreen] or [GoalCreateEditSheet].
/// Null when no goal is selected.
final selectedGoalIdProvider = StateProvider<String?>((ref) => null);

// ── Achievements ──────────────────────────────────────────────────────────────

/// Async provider for the full achievement gallery (locked + unlocked).
///
/// Invalidate with [ref.invalidate(achievementsProvider)] after a
/// pull-to-refresh.
///
/// Uses the never-error pattern: catches all exceptions and returns
/// an empty list so the UI always reaches the `data:` branch.
final achievementsProvider = FutureProvider<AchievementList>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  try {
    return await repo.getAchievements();
  } catch (_) {
    return const AchievementList(achievements: []);
  }
});

// ── Weekly Report ─────────────────────────────────────────────────────────────

/// Async provider for the latest weekly report.
///
/// Invalidate with [ref.invalidate(weeklyReportProvider)] after a
/// pull-to-refresh.
///
/// Uses the never-error pattern: catches all exceptions and returns
/// an empty report so the UI always reaches the `data:` branch.
final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  try {
    return await repo.getWeeklyReport();
  } catch (_) {
    return const WeeklyReport(
      id: '',
      periodStart: '',
      periodEnd: '',
      cards: [],
    );
  }
});

// ── Journal ───────────────────────────────────────────────────────────────────

/// Async provider for the first page of journal entries (newest first).
///
/// Invalidate with [ref.invalidate(journalProvider)] after creating,
/// editing, or deleting an entry.
///
/// Uses the never-error pattern: catches all exceptions and returns
/// an empty page so the UI always reaches the `data:` branch.
final journalProvider = FutureProvider<JournalPage>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  try {
    return await repo.getJournal();
  } catch (_) {
    return const JournalPage(entries: [], hasMore: false);
  }
});
