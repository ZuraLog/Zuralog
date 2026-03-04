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

/// Singleton [ProgressRepository] wired to the shared [apiClientProvider].
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(apiClient: ref.read(apiClientProvider));
});

// ── Progress Home ─────────────────────────────────────────────────────────────

/// Async provider for the aggregated Progress Home screen data.
///
/// Invalidate with [ref.invalidate(progressHomeProvider)] after a
/// pull-to-refresh or after mutating goals/streaks.
final progressHomeProvider = FutureProvider<ProgressHomeData>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return repo.getProgressHome();
});

// ── Goals ─────────────────────────────────────────────────────────────────────

/// Async provider for the full list of user goals.
///
/// Invalidate with [ref.invalidate(goalsProvider)] after any CRUD operation.
final goalsProvider = FutureProvider<GoalList>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return repo.getGoals();
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
final achievementsProvider = FutureProvider<AchievementList>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return repo.getAchievements();
});

// ── Weekly Report ─────────────────────────────────────────────────────────────

/// Async provider for the latest weekly report.
///
/// Invalidate with [ref.invalidate(weeklyReportProvider)] after a
/// pull-to-refresh.
final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return repo.getWeeklyReport();
});

// ── Journal ───────────────────────────────────────────────────────────────────

/// Async provider for the first page of journal entries (newest first).
///
/// Invalidate with [ref.invalidate(journalProvider)] after creating,
/// editing, or deleting an entry.
final journalProvider = FutureProvider<JournalPage>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return repo.getJournal();
});
