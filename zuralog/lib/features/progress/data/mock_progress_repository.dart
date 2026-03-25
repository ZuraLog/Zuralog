/// Zuralog — Mock Progress Repository.
///
/// In-memory stub implementation of [ProgressRepositoryInterface] used in
/// debug builds (`kDebugMode`) to allow the Progress tab to render without a
/// running backend.
///
/// Simulates realistic network latency (400 ms) and returns fixed progress data
/// that exercises every Progress-tab widget path.
library;

import 'package:intl/intl.dart';
import 'package:zuralog/features/progress/data/progress_repository.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';

// ── MockProgressRepository ────────────────────────────────────────────────────

/// Debug-only stub implementation of [ProgressRepositoryInterface].
///
/// Returns hardcoded fixture data after a short artificial delay so that
/// loading skeletons and data states are both exercisable in development.
final class MockProgressRepository implements ProgressRepositoryInterface {
  /// Creates a const [MockProgressRepository].
  const MockProgressRepository();

  static const Duration _delay = Duration(milliseconds: 400);

  // ── Progress Home ─────────────────────────────────────────────────────────

  @override
  Future<ProgressHomeData> getProgressHome() async {
    await Future<void>.delayed(_delay);
    final today = DateTime.now();
    final weekday = today.weekday; // 1=Mon .. 7=Sun
    return ProgressHomeData(
      goals: _mockGoals(),
      streaks: _mockStreaks(),
      wow: _mockWow(),
      recentAchievements: _mockRecentAchievements(),
      milestoneStreakCount: 7,
      streakHistory: {
        'engagement': List.generate(14, (i) => i >= 7),
        'steps': List.generate(14, (i) => i >= 9),
        'workouts': List.generate(14, (i) => i == 9 || i == 11 || i == 13),
        'checkin': List.generate(14, (i) => i >= 10),
      },
      weekHits: {
        'engagement': List.generate(7, (i) => i < weekday),
        'steps': List.generate(7, (i) => i < weekday && i != 1),
        'workouts': List.generate(7, (i) => i == 0 || i == 2),
        'checkin': List.generate(7, (i) => i < weekday),
      },
      nextAchievement: const Achievement(
        id: 'ach_next_14',
        key: 'streak_14',
        title: 'Streak 14',
        description: 'Keep going to unlock this achievement',
        category: AchievementCategory.consistency,
        iconName: 'flame',
        unlockedAt: null,
        progressCurrent: 7,
        progressTotal: 14,
        progressLabel: '7 of 14 days',
      ),
    );
  }

  // ── Goals ─────────────────────────────────────────────────────────────────

  @override
  Future<GoalList> getGoals() async {
    await Future<void>.delayed(_delay);
    return GoalList(goals: _mockGoals());
  }

  @override
  Future<Goal> createGoal({
    required GoalType type,
    required GoalPeriod period,
    required String title,
    required double targetValue,
    required String unit,
    String? deadline,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return Goal(
      id: 'mock_new_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'mock_user',
      type: type,
      period: period,
      title: title,
      targetValue: targetValue,
      currentValue: 0.0,
      unit: unit,
      startDate: DateTime.now().toIso8601String().split('T').first,
      deadline: deadline,
      progressHistory: const [],
    );
  }

  @override
  Future<Goal> updateGoal({
    required String goalId,
    String? title,
    double? targetValue,
    String? unit,
    String? deadline,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final existing = _mockGoals().firstWhere(
      (g) => g.id == goalId,
      orElse: () => _mockGoals().first,
    );
    return Goal(
      id: existing.id,
      userId: existing.userId,
      type: existing.type,
      period: existing.period,
      title: title ?? existing.title,
      targetValue: targetValue ?? existing.targetValue,
      currentValue: existing.currentValue,
      unit: unit ?? existing.unit,
      startDate: existing.startDate,
      deadline: deadline ?? existing.deadline,
      isCompleted: existing.isCompleted,
      aiCommentary: existing.aiCommentary,
      progressHistory: existing.progressHistory,
    );
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // No-op in mock.
  }

  // ── Achievements ──────────────────────────────────────────────────────────

  @override
  Future<AchievementList> getAchievements() async {
    await Future<void>.delayed(_delay);
    return AchievementList(achievements: _mockAllAchievements());
  }

  // ── Weekly Report ─────────────────────────────────────────────────────────

  @override
  Future<WeeklyReport> getWeeklyReport() async {
    await Future<void>.delayed(_delay);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return WeeklyReport(
      id: 'mock_report_1',
      periodStart: weekStart.toIso8601String().split('T').first,
      periodEnd: weekEnd.toIso8601String().split('T').first,
      cards: _mockReportCards(),
    );
  }

  // ── Journal ───────────────────────────────────────────────────────────────

  @override
  Future<JournalPage> getJournal({int page = 1}) async {
    await Future<void>.delayed(_delay);
    if (page > 1) return const JournalPage(entries: [], hasMore: false);
    return JournalPage(entries: _mockJournalEntries(), hasMore: false);
  }

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
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return JournalEntry(
      id: 'mock_entry_${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      mood: mood,
      energy: energy,
      stress: stress,
      sleepQuality: sleepQuality,
      notes: notes,
      tags: tags,
      createdAt: DateTime.now(),
    );
  }

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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final existing = _mockJournalEntries().firstWhere(
      (e) => e.id == entryId,
      orElse: () => _mockJournalEntries().first,
    );
    return JournalEntry(
      id: existing.id,
      date: existing.date,
      mood: mood ?? existing.mood,
      energy: energy ?? existing.energy,
      stress: stress ?? existing.stress,
      sleepQuality: sleepQuality ?? existing.sleepQuality,
      notes: notes ?? existing.notes,
      tags: tags ?? existing.tags,
      createdAt: existing.createdAt,
    );
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // No-op in mock.
  }

  @override
  Future<void> applyStreakFreeze(StreakType type) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // No-op in mock: freeze is simulated but no state is mutated.
  }

  @override
  void invalidateAll() {
    // No-op: mock has no cache to invalidate.
  }

  // ── Fixture Builders ──────────────────────────────────────────────────────

  List<Goal> _mockGoals() {
    final today = DateTime.now().toIso8601String().split('T').first;
    return [
      Goal(
        id: 'goal_steps',
        userId: 'mock_user',
        type: GoalType.stepCount,
        period: GoalPeriod.daily,
        title: '10,000 steps/day',
        targetValue: 10000.0,
        currentValue: 8432.0,
        unit: 'steps',
        startDate: today,
        isCompleted: false,
        aiCommentary:
            "You're 84% of the way there. A quick 20-minute walk will close the gap today.",
        progressHistory: const [
          7200.0, 7800.0, 8100.0, 6900.0, 8500.0, 7600.0, 8432.0
        ],
        trendDirection: 'on_track',
      ),
      Goal(
        id: 'goal_sleep',
        userId: 'mock_user',
        type: GoalType.sleepDuration,
        period: GoalPeriod.daily,
        title: '8 hours of sleep',
        targetValue: 8.0,
        currentValue: 7.4,
        unit: 'hours',
        startDate: today,
        isCompleted: false,
        aiCommentary:
            "You're averaging 7h 22m. Try going to bed 40 minutes earlier.",
        progressHistory: const [6.5, 7.0, 7.2, 6.8, 7.5, 7.1, 7.4],
        trendDirection: 'behind',
      ),
      Goal(
        id: 'goal_workouts',
        userId: 'mock_user',
        type: GoalType.weeklyRunCount,
        period: GoalPeriod.weekly,
        title: '3 workouts/week',
        targetValue: 3.0,
        currentValue: 2.0,
        unit: 'workouts',
        startDate: today,
        isCompleted: false,
        aiCommentary:
            "2 of 3 workouts done this week. One more session to hit your goal!",
        progressHistory: const [3.0, 2.0, 3.0, 3.0, 2.0, 3.0, 2.0],
        trendDirection: 'on_track',
      ),
    ];
  }

  List<UserStreak> _mockStreaks() {
    final today = DateTime.now().toIso8601String().split('T').first;
    return [
      UserStreak(
        type: StreakType.engagement,
        currentCount: 7,
        longestCount: 14,
        lastActivityDate: today,
        isFrozen: false,
        freezeCount: 0,
      ),
      UserStreak(
        type: StreakType.steps,
        currentCount: 5,
        longestCount: 21,
        lastActivityDate: today,
        isFrozen: false,
        freezeCount: 1,
      ),
      UserStreak(
        type: StreakType.workouts,
        currentCount: 3,
        longestCount: 8,
        lastActivityDate: today,
        isFrozen: false,
        freezeCount: 0,
      ),
      UserStreak(
        type: StreakType.checkin,
        currentCount: 4,
        longestCount: 10,
        lastActivityDate: today,
        isFrozen: false,
        freezeCount: 0,
      ),
    ];
  }

  WoWSummary _mockWow() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final prevWeekEnd = weekStart.subtract(const Duration(days: 1));
    final fmt = DateFormat('MMM');
    final label =
        '${fmt.format(prevWeekStart)} ${prevWeekStart.day} – ${fmt.format(prevWeekEnd)} ${prevWeekEnd.day}';
    return WoWSummary(
      weekLabel: label,
      metrics: const [
        WoWMetric(
          label: 'Avg Steps',
          currentValue: 8432.0,
          previousValue: 8090.0,
          unit: 'steps/day',
        ),
        WoWMetric(
          label: 'Sleep Duration',
          currentValue: 7.4,
          previousValue: 7.1,
          unit: 'hrs',
        ),
        WoWMetric(
          label: 'Resting HR',
          currentValue: 62.0,
          previousValue: 64.0,
          unit: 'bpm',
        ),
      ],
    );
  }

  List<Achievement> _mockRecentAchievements() {
    final now = DateTime.now();
    return [
      Achievement(
        id: 'ach_1',
        key: 'streak_7',
        title: '7-Day Streak',
        description: 'Logged data 7 days in a row.',
        category: AchievementCategory.consistency,
        iconName: 'flame',
        unlockedAt: now.subtract(const Duration(hours: 2)),
      ),
      Achievement(
        id: 'ach_2',
        key: 'first_goal',
        title: 'Goal Setter',
        description: 'Created your first health goal.',
        category: AchievementCategory.goals,
        iconName: 'flag',
        unlockedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<Achievement> _mockAllAchievements() {
    final unlocked = _mockRecentAchievements();
    return [
      ...unlocked,
      const Achievement(
        id: 'ach_3',
        key: 'first_sync',
        title: 'First Sync',
        description: 'Connected your first health integration.',
        category: AchievementCategory.gettingStarted,
        iconName: 'sync',
        unlockedAt: null,
        progressCurrent: 0,
        progressTotal: 1,
        progressLabel: 'Connect your first app',
      ),
      const Achievement(
        id: 'ach_4',
        key: 'step_10k',
        title: '10K Steps',
        description: 'Hit 10,000 steps in a single day.',
        category: AchievementCategory.health,
        iconName: 'run',
        unlockedAt: null,
        progressCurrent: 3,
        progressTotal: 7,
        progressLabel: '3 of 7 days complete',
      ),
      const Achievement(
        id: 'ach_5',
        key: 'ai_chat',
        title: 'AI Explorer',
        description: 'Asked your first question to the health coach.',
        category: AchievementCategory.coach,
        iconName: 'chat',
        unlockedAt: null,
        progressCurrent: 0,
        progressTotal: 1,
        progressLabel: 'Send your first message to Coach',
      ),
    ];
  }

  List<WeeklyReportCard> _mockReportCards() {
    // Fixed 5-card narrative sequence — canonical story order per PRD.
    return const [
      // Card 0 — Week Summary
      WeeklyReportCard(
        cardIndex: 0,
        title: 'Week Summary',
        gradientCategory: 'activity',
        aiText:
            'Strong week — you hit your step goal 5 out of 7 days and completed all 3 planned workouts.',
        metrics: [
          ReportMetric(label: 'Avg Steps', value: '8,432', unit: 'avg/day', delta: '+4.2%'),
          ReportMetric(
            label: 'Active Calories',
            value: '2,940',
            unit: 'kcal total',
            delta: '+2.8%',
          ),
          ReportMetric(label: 'Workouts Completed', value: '3', unit: 'this week'),
        ],
      ),
      // Card 1 — Top Insight
      WeeklyReportCard(
        cardIndex: 1,
        title: 'Top Insight',
        gradientCategory: 'wellness',
        aiText:
            'Your HRV is trending up — a clear sign your recovery is improving. Keep it up.',
        metrics: [
          ReportMetric(label: 'HRV', value: '54', unit: 'ms avg', delta: '+5.9%'),
          ReportMetric(label: 'Resting HR', value: '62', unit: 'bpm', delta: '-3.1%'),
          ReportMetric(label: 'Sleep Consistency', value: '87', unit: '%', delta: '+6.0%'),
        ],
      ),
      // Card 2 — Goal Adherence
      WeeklyReportCard(
        cardIndex: 2,
        title: 'Goal Adherence',
        gradientCategory: 'body',
        aiText:
            'You hit 3 of 4 goals this week. Your step goal is your most consistent — 6 days in a row.',
        metrics: [
          ReportMetric(label: 'Goals Hit', value: '3', unit: 'of 4'),
          ReportMetric(label: 'Goals Missed', value: '1', unit: 'this week'),
          ReportMetric(label: 'Best Streak', value: '6', unit: 'days'),
        ],
      ),
      // Card 3 — vs. Last Week
      WeeklyReportCard(
        cardIndex: 3,
        title: 'vs. Last Week',
        gradientCategory: 'heart',
        aiText:
            "You're up across the board vs. last week. Sleep improved the most (+14%).",
        metrics: [
          ReportMetric(label: 'Steps', value: '8,432', unit: 'avg/day', delta: '+4.2%'),
          ReportMetric(label: 'Sleep', value: '7h 22m', unit: 'avg/night', delta: '+14%'),
          ReportMetric(label: 'Active Calories', value: '2,940', unit: 'kcal total', delta: '+2.1%'),
        ],
      ),
      // Card 4 — Your Streak
      WeeklyReportCard(
        cardIndex: 4,
        title: 'Your Streak',
        gradientCategory: 'sleep',
        aiText:
            "7-day streak — you're building a real habit. Keep the momentum going into next week.",
        metrics: [
          ReportMetric(label: 'Current Streak', value: '7', unit: 'days'),
          ReportMetric(label: 'Longest Streak', value: '14', unit: 'days'),
          ReportMetric(label: 'Freezes Available', value: '2', unit: 'remaining'),
        ],
      ),
    ];
  }

  List<JournalEntry> _mockJournalEntries() {
    final now = DateTime.now();
    return [
      JournalEntry(
        id: 'journal_1',
        date: now.toIso8601String().split('T').first,
        mood: 8,
        energy: 7,
        stress: 3,
        sleepQuality: 8,
        notes: 'Good workout today. Feeling energized and focused.',
        tags: const ['gym', 'productive', 'good-mood'],
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      JournalEntry(
        id: 'journal_2',
        date: now.subtract(const Duration(days: 1)).toIso8601String().split('T').first,
        mood: 6,
        energy: 5,
        stress: 5,
        sleepQuality: 6,
        notes: 'Busy day at work. Skipped the afternoon walk.',
        tags: const ['busy', 'work'],
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      JournalEntry(
        id: 'journal_3',
        date: now.subtract(const Duration(days: 2)).toIso8601String().split('T').first,
        mood: 9,
        energy: 9,
        stress: 2,
        sleepQuality: 9,
        notes: 'Best sleep in weeks. Morning run felt effortless.',
        tags: const ['run', 'great-sleep', 'relaxed'],
        createdAt: now.subtract(const Duration(days: 2, hours: 1)),
      ),
    ];
  }
}
