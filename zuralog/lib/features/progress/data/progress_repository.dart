/// Zuralog — Progress Repository.
///
/// Data layer for the Progress tab. Wraps all API calls for:
///   - Progress Home aggregated data  (`GET /api/v1/progress/home`)
///   - Goals CRUD                     (`GET/POST/PATCH/DELETE /api/v1/goals`)
///   - Achievements gallery           (`GET /api/v1/achievements`)
///   - Weekly Report                  (`GET /api/v1/progress/weekly-report`)
///   - Journal entries                (`GET/POST/PATCH/DELETE /api/v1/journal`)
///
/// Provides a 5-minute in-memory TTL cache for read-heavy endpoints.
library;

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';

// ── ProgressRepositoryInterface ───────────────────────────────────────────────

/// Abstract contract for all Progress-tab data operations.
///
/// Implemented by [ProgressRepository] (real) and
/// [MockProgressRepository] (debug).
abstract interface class ProgressRepositoryInterface {
  /// Fetches the aggregated Progress Home screen data.
  Future<ProgressHomeData> getProgressHome();

  /// Fetches all goals for the authenticated user.
  Future<GoalList> getGoals();

  /// Creates a new goal. Invalidates goals cache on success.
  Future<Goal> createGoal({
    required GoalType type,
    required GoalPeriod period,
    required String title,
    required double targetValue,
    required String unit,
    String? deadline,
  });

  /// Updates an existing goal. Invalidates goals cache on success.
  Future<Goal> updateGoal({
    required String goalId,
    String? title,
    double? targetValue,
    String? unit,
    String? deadline,
  });

  /// Deletes a goal by ID. Invalidates goals cache on success.
  Future<void> deleteGoal(String goalId);

  /// Fetches the full achievement gallery (locked and unlocked).
  Future<AchievementList> getAchievements();

  /// Fetches the latest weekly report.
  Future<WeeklyReport> getWeeklyReport();

  /// Fetches a page of journal entries. [page] is 1-based.
  Future<JournalPage> getJournal({int page = 1});

  /// Creates a new journal entry. Invalidates journal cache on success.
  Future<JournalEntry> createJournalEntry({
    required String date,
    required int mood,
    required int energy,
    required int stress,
    int? sleepQuality,
    required String notes,
    required List<String> tags,
  });

  /// Updates an existing journal entry. Invalidates journal cache on success.
  Future<JournalEntry> updateJournalEntry({
    required String entryId,
    int? mood,
    int? energy,
    int? stress,
    int? sleepQuality,
    String? notes,
    List<String>? tags,
  });

  /// Deletes a journal entry by ID. Invalidates journal cache on success.
  Future<void> deleteJournalEntry(String entryId);

  /// Invalidates all caches, forcing fresh fetches on next access.
  void invalidateAll();
}

// ── ProgressRepository ────────────────────────────────────────────────────────

/// Repository for all Progress-tab network operations.
///
/// Injected via [progressRepositoryProvider]. All public methods throw
/// [DioException] on network errors unless a cached fallback is available.
class ProgressRepository implements ProgressRepositoryInterface {
  /// Creates a [ProgressRepository] backed by [apiClient].
  ProgressRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── Cache ──────────────────────────────────────────────────────────────────

  _CacheEntry<ProgressHomeData>? _homeCache;
  _CacheEntry<GoalList>? _goalsCache;
  _CacheEntry<AchievementList>? _achievementsCache;
  _CacheEntry<WeeklyReport>? _weeklyReportCache;
  _CacheEntry<JournalPage>? _journalCache;

  static const Duration _cacheTtl = Duration(minutes: 5);

  // ── Progress Home ─────────────────────────────────────────────────────────

  /// Fetches the aggregated Progress Home screen data.
  ///
  /// Falls back to stale cache on network error if available.
  @override
  Future<ProgressHomeData> getProgressHome() async {
    if (_homeCache != null && !_homeCache!.isExpired) {
      return _homeCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/progress/home');
      final data = ProgressHomeData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _homeCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_homeCache != null) return _homeCache!.value;
      // Return empty stub so screen can show onboarding state.
      return const ProgressHomeData(
        goals: [],
        streaks: [],
        wow: WoWSummary(weekLabel: '', metrics: []),
        recentAchievements: [],
      );
    }
  }

  // ── Goals ─────────────────────────────────────────────────────────────────

  /// Fetches all goals for the authenticated user.
  @override
  Future<GoalList> getGoals() async {
    if (_goalsCache != null && !_goalsCache!.isExpired) {
      return _goalsCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/goals');
      final data = GoalList.fromJson(response.data as Map<String, dynamic>);
      _goalsCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_goalsCache != null) return _goalsCache!.value;
      return const GoalList(goals: []);
    }
  }

  /// Creates a new goal. Invalidates goals cache on success.
  @override
  Future<Goal> createGoal({
    required GoalType type,
    required GoalPeriod period,
    required String title,
    required double targetValue,
    required String unit,
    String? deadline,
  }) async {
    final response = await _api.post(
      '/api/v1/goals',
      data: {
        'type': type.apiSlug,
        'period': period.apiSlug,
        'title': title,
        'target_value': targetValue,
        'unit': unit,
        if (deadline != null) 'deadline': deadline,
      },
    );
    _goalsCache = null;
    _homeCache = null;
    return Goal.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates an existing goal. Invalidates goals cache on success.
  @override
  Future<Goal> updateGoal({
    required String goalId,
    String? title,
    double? targetValue,
    String? unit,
    String? deadline,
  }) async {
    final response = await _api.patch(
      '/api/v1/goals/$goalId',
      body: {
        if (title != null) 'title': title,
        if (targetValue != null) 'target_value': targetValue,
        if (unit != null) 'unit': unit,
        if (deadline != null) 'deadline': deadline,
      },
    );
    _goalsCache = null;
    _homeCache = null;
    return Goal.fromJson(response.data as Map<String, dynamic>);
  }

  /// Deletes a goal by ID. Invalidates goals cache on success.
  @override
  Future<void> deleteGoal(String goalId) async {
    await _api.delete('/api/v1/goals/$goalId');
    _goalsCache = null;
    _homeCache = null;
  }

  // ── Achievements ──────────────────────────────────────────────────────────

  /// Fetches the full achievement gallery (locked and unlocked).
  @override
  Future<AchievementList> getAchievements() async {
    if (_achievementsCache != null && !_achievementsCache!.isExpired) {
      return _achievementsCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/achievements');
      final data = AchievementList.fromJson(
        response.data as Map<String, dynamic>,
      );
      _achievementsCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_achievementsCache != null) return _achievementsCache!.value;
      return const AchievementList(achievements: []);
    }
  }

  // ── Weekly Report ─────────────────────────────────────────────────────────

  /// Fetches the latest weekly report.
  @override
  Future<WeeklyReport> getWeeklyReport() async {
    if (_weeklyReportCache != null && !_weeklyReportCache!.isExpired) {
      return _weeklyReportCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/progress/weekly-report');
      final data = WeeklyReport.fromJson(
        response.data as Map<String, dynamic>,
      );
      _weeklyReportCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_weeklyReportCache != null) return _weeklyReportCache!.value;
      return WeeklyReport(
        id: '',
        periodStart: '',
        periodEnd: '',
        cards: [],
      );
    }
  }

  // ── Journal ───────────────────────────────────────────────────────────────

  /// Fetches a page of journal entries. [page] is 1-based.
  @override
  Future<JournalPage> getJournal({int page = 1}) async {
    if (page == 1 && _journalCache != null && !_journalCache!.isExpired) {
      return _journalCache!.value;
    }
    try {
      final response = await _api.get(
        '/api/v1/journal',
        queryParameters: {'page': page},
      );
      final data = JournalPage.fromJson(response.data as Map<String, dynamic>);
      if (page == 1) _journalCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (page == 1 && _journalCache != null) return _journalCache!.value;
      return const JournalPage(entries: [], hasMore: false);
    }
  }

  /// Creates a new journal entry. Invalidates journal cache on success.
  @override
  Future<JournalEntry> createJournalEntry({
    required String date,
    required int mood,
    required int energy,
    required int stress,
    int? sleepQuality,
    required String notes,
    required List<String> tags,
  }) async {
    final response = await _api.post(
      '/api/v1/journal',
      data: {
        'date': date,
        'mood': mood,
        'energy': energy,
        'stress': stress,
        if (sleepQuality != null) 'sleep_quality': sleepQuality,
        'notes': notes,
        'tags': tags,
      },
    );
    _journalCache = null;
    return JournalEntry.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates an existing journal entry. Invalidates journal cache on success.
  @override
  Future<JournalEntry> updateJournalEntry({
    required String entryId,
    int? mood,
    int? energy,
    int? stress,
    int? sleepQuality,
    String? notes,
    List<String>? tags,
  }) async {
    final response = await _api.patch(
      '/api/v1/journal/$entryId',
      body: {
        if (mood != null) 'mood': mood,
        if (energy != null) 'energy': energy,
        if (stress != null) 'stress': stress,
        if (sleepQuality != null) 'sleep_quality': sleepQuality,
        if (notes != null) 'notes': notes,
        if (tags != null) 'tags': tags,
      },
    );
    _journalCache = null;
    return JournalEntry.fromJson(response.data as Map<String, dynamic>);
  }

  /// Deletes a journal entry by ID. Invalidates journal cache on success.
  @override
  Future<void> deleteJournalEntry(String entryId) async {
    await _api.delete('/api/v1/journal/$entryId');
    _journalCache = null;
  }

  // ── Cache Invalidation ────────────────────────────────────────────────────

  /// Invalidates all caches, forcing fresh fetches on next access.
  @override
  void invalidateAll() {
    _homeCache = null;
    _goalsCache = null;
    _achievementsCache = null;
    _weeklyReportCache = null;
    _journalCache = null;
  }
}

// ── _CacheEntry ───────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry({required this.value}) : _createdAt = DateTime.now();

  final T value;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > ProgressRepository._cacheTtl;
}
