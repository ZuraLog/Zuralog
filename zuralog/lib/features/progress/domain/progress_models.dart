/// Zuralog — Progress Tab Domain Models.
///
/// Strongly-typed DTOs for all Progress-tab API responses.
/// All models are immutable and serialize from/to JSON.
///
/// Model overview:
/// - [GoalType]             — enum of 6 goal types
/// - [GoalPeriod]           — enum of 3 goal periods (daily / weekly / long-term)
/// - [Goal]                 — single goal with target, progress & AI commentary
/// - [GoalList]             — list wrapper for goals
/// - [StreakType]           — enum of 4 streak types
/// - [UserStreak]           — streak counter with freeze tracking
/// - [StreakList]           — list wrapper for streaks
/// - [AchievementCategory]  — enum of 6 achievement categories
/// - [Achievement]          — single badge/achievement with unlock timestamp
/// - [AchievementList]      — list wrapper for achievements
/// - [WoWMetric]            — week-over-week metric with computed delta %
/// - [WoWSummary]           — full week-over-week summary for one week
/// - [ProgressHomeData]     — aggregated Progress Home screen payload
/// - [ReportMetric]         — single metric row inside a weekly report card
/// - [WeeklyReportCard]     — one of 6 carousel cards in the weekly report
/// - [WeeklyReport]         — full weekly report with period + cards
/// - [JournalEntry]         — daily mood / energy / stress journal entry
/// - [JournalPage]          — paginated journal history
library;

import 'package:flutter/foundation.dart';

// ── GoalType ──────────────────────────────────────────────────────────────────

/// Supported goal types.
enum GoalType {
  weightTarget,
  weeklyRunCount,
  dailyCalorieLimit,
  sleepDuration,
  stepCount,
  waterIntake,
  custom;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case GoalType.weightTarget:
        return 'Weight Target';
      case GoalType.weeklyRunCount:
        return 'Weekly Run Count';
      case GoalType.dailyCalorieLimit:
        return 'Daily Calorie Limit';
      case GoalType.sleepDuration:
        return 'Sleep Duration';
      case GoalType.stepCount:
        return 'Step Count';
      case GoalType.waterIntake:
        return 'Daily Water Intake';
      case GoalType.custom:
        return 'Custom';
    }
  }

  /// Deserializes from a raw API string slug.
  static GoalType fromString(String? raw) {
    switch (raw) {
      case 'weight_target':
        return GoalType.weightTarget;
      case 'weekly_run_count':
        return GoalType.weeklyRunCount;
      case 'daily_calorie_limit':
        return GoalType.dailyCalorieLimit;
      case 'sleep_duration':
        return GoalType.sleepDuration;
      case 'step_count':
        return GoalType.stepCount;
      case 'water_intake':
        return GoalType.waterIntake;
      case 'custom':
        return GoalType.custom;
      default:
        debugPrint('[GoalType] Unknown goal type slug: "$raw". Falling back to custom.');
        return GoalType.custom;
    }
  }

  /// Serializes to the API string slug.
  String get apiSlug {
    switch (this) {
      case GoalType.weightTarget:
        return 'weight_target';
      case GoalType.weeklyRunCount:
        return 'weekly_run_count';
      case GoalType.dailyCalorieLimit:
        return 'daily_calorie_limit';
      case GoalType.sleepDuration:
        return 'sleep_duration';
      case GoalType.stepCount:
        return 'step_count';
      case GoalType.waterIntake:
        return 'water_intake';
      case GoalType.custom:
        return 'custom';
    }
  }
}

// ── GoalPeriod ────────────────────────────────────────────────────────────────

/// Time horizon for a goal.
enum GoalPeriod {
  daily,
  weekly,
  longTerm;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case GoalPeriod.daily:
        return 'Daily';
      case GoalPeriod.weekly:
        return 'Weekly';
      case GoalPeriod.longTerm:
        return 'Long-Term';
    }
  }

  /// Deserializes from a raw API string slug.
  static GoalPeriod fromString(String? raw) {
    switch (raw) {
      case 'daily':
        return GoalPeriod.daily;
      case 'weekly':
        return GoalPeriod.weekly;
      case 'long_term':
        return GoalPeriod.longTerm;
      default:
        debugPrint('[GoalPeriod] Unknown goal period slug: "$raw". Falling back to weekly.');
        return GoalPeriod.weekly;
    }
  }

  /// Serializes to the API string slug.
  String get apiSlug {
    switch (this) {
      case GoalPeriod.daily:
        return 'daily';
      case GoalPeriod.weekly:
        return 'weekly';
      case GoalPeriod.longTerm:
        return 'long_term';
    }
  }
}

// ── Goal ──────────────────────────────────────────────────────────────────────

/// A single user goal with target value, current progress, and AI commentary.
class Goal {
  /// Creates a [Goal].
  const Goal({
    required this.id,
    required this.userId,
    required this.type,
    required this.period,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.startDate,
    required this.progressHistory,
    this.deadline,
    this.isCompleted = false,
    this.aiCommentary,
    this.trendDirection = 'on_track',
  });

  /// Unique goal identifier.
  final String id;

  /// The user who owns this goal.
  final String userId;

  /// The goal type (e.g. [GoalType.stepCount]).
  final GoalType type;

  /// Time horizon for this goal.
  final GoalPeriod period;

  /// Short user-facing title for the goal.
  final String title;

  /// The numeric target to reach.
  final double targetValue;

  /// The latest recorded value toward the goal.
  final double currentValue;

  /// Unit label (e.g. "kg", "runs", "hrs", "steps").
  final String unit;

  /// ISO-8601 date when the goal was started.
  final String startDate;

  /// Optional ISO-8601 deadline date. Null for open-ended goals.
  final String? deadline;

  /// Whether the goal has been completed.
  final bool isCompleted;

  /// Optional AI-generated commentary or motivational text.
  final String? aiCommentary;

  /// Historical progress values, oldest first.
  /// Used to render sparklines and trend charts.
  final List<double> progressHistory;

  /// Trend direction relative to expected pace.
  /// One of: 'on_track', 'behind', 'completed'.
  final String trendDirection;

  /// Progress as a fraction in [0, 1]. Capped at 1.0 when overachieved.
  double get progressFraction =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  /// Deserializes from a JSON map.
  factory Goal.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['progress_history'] as List<dynamic>? ?? [];
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: GoalType.fromString(json['type'] as String?),
      period: GoalPeriod.fromString(json['period'] as String?),
      title: json['title'] as String? ?? '',
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      deadline: json['deadline'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      aiCommentary: json['ai_commentary'] as String?,
      progressHistory: rawHistory.map((e) => (e as num).toDouble()).toList(),
      trendDirection: json['trend_direction'] as String? ?? 'on_track',
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.apiSlug,
        'period': period.apiSlug,
        'title': title,
        'target_value': targetValue,
        'current_value': currentValue,
        'unit': unit,
        'start_date': startDate,
        'deadline': deadline,
        'is_completed': isCompleted,
        'ai_commentary': aiCommentary,
        'progress_history': progressHistory,
        'trend_direction': trendDirection,
      };
}

// ── GoalList ──────────────────────────────────────────────────────────────────

/// List wrapper for a collection of [Goal]s.
class GoalList {
  /// Creates a [GoalList].
  const GoalList({required this.goals});

  /// All goals.
  final List<Goal> goals;

  /// Deserializes from a JSON map.
  factory GoalList.fromJson(Map<String, dynamic> json) {
    final rawGoals = json['goals'] as List<dynamic>? ?? [];
    return GoalList(
      goals: rawGoals
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'goals': goals.map((g) => g.toJson()).toList(),
      };
}

// ── StreakType ────────────────────────────────────────────────────────────────

/// The dimension tracked by a [UserStreak].
enum StreakType {
  engagement,
  steps,
  workouts,
  checkin;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case StreakType.engagement:
        return 'Engagement';
      case StreakType.steps:
        return 'Steps';
      case StreakType.workouts:
        return 'Workouts';
      case StreakType.checkin:
        return 'Check-in';
    }
  }

  /// Deserializes from a raw API string slug.
  static StreakType fromString(String? raw) {
    switch (raw) {
      case 'engagement':
        return StreakType.engagement;
      case 'steps':
        return StreakType.steps;
      case 'workouts':
        return StreakType.workouts;
      case 'checkin':
        return StreakType.checkin;
      default:
        debugPrint('[StreakType] Unknown streak type: "$raw". Falling back to engagement.');
        return StreakType.engagement;
    }
  }

  /// Serializes to the API string slug.
  String get apiSlug {
    switch (this) {
      case StreakType.engagement:
        return 'engagement';
      case StreakType.steps:
        return 'steps';
      case StreakType.workouts:
        return 'workouts';
      case StreakType.checkin:
        return 'checkin';
    }
  }
}

// ── UserStreak ────────────────────────────────────────────────────────────────

/// A named streak counter with freeze and longest-count tracking.
class UserStreak {
  /// Creates a [UserStreak].
  const UserStreak({
    required this.type,
    required this.currentCount,
    required this.longestCount,
    required this.lastActivityDate,
    required this.isFrozen,
    required this.freezeCount,
  });

  /// The dimension this streak tracks.
  final StreakType type;

  /// Current consecutive-period streak.
  final int currentCount;

  /// All-time longest streak.
  final int longestCount;

  /// ISO-8601 date of the most recent qualifying activity.
  final String lastActivityDate;

  /// Whether a streak freeze is currently active (breaks streak loss).
  final bool isFrozen;

  /// Number of freezes the user has applied on this streak.
  final int freezeCount;

  /// Deserializes from a JSON map.
  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      type: StreakType.fromString(json['type'] as String?),
      currentCount: (json['current_count'] as num?)?.toInt() ?? 0,
      longestCount: (json['longest_count'] as num?)?.toInt() ?? 0,
      lastActivityDate: json['last_activity_date'] as String? ?? '',
      isFrozen: json['is_frozen'] as bool? ?? false,
      freezeCount: (json['freeze_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'type': type.apiSlug,
        'current_count': currentCount,
        'longest_count': longestCount,
        'last_activity_date': lastActivityDate,
        'is_frozen': isFrozen,
        'freeze_count': freezeCount,
      };
}

// ── StreakList ────────────────────────────────────────────────────────────────

/// List wrapper for a collection of [UserStreak]s.
class StreakList {
  /// Creates a [StreakList].
  const StreakList({required this.streaks});

  /// All streaks.
  final List<UserStreak> streaks;

  /// Deserializes from a JSON map.
  factory StreakList.fromJson(Map<String, dynamic> json) {
    final rawStreaks = json['streaks'] as List<dynamic>? ?? [];
    return StreakList(
      streaks: rawStreaks
          .map((e) => UserStreak.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'streaks': streaks.map((s) => s.toJson()).toList(),
      };
}

// ── AchievementCategory ───────────────────────────────────────────────────────

/// Grouping category for achievements / badges.
enum AchievementCategory {
  gettingStarted,
  consistency,
  goals,
  data,
  coach,
  health;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case AchievementCategory.gettingStarted:
        return 'Getting Started';
      case AchievementCategory.consistency:
        return 'Consistency';
      case AchievementCategory.goals:
        return 'Goals';
      case AchievementCategory.data:
        return 'Data';
      case AchievementCategory.coach:
        return 'Coach';
      case AchievementCategory.health:
        return 'Health';
    }
  }

  /// Deserializes from a raw API string slug.
  static AchievementCategory fromString(String? raw) {
    switch (raw) {
      case 'getting_started':
        return AchievementCategory.gettingStarted;
      case 'consistency':
        return AchievementCategory.consistency;
      case 'goals':
        return AchievementCategory.goals;
      case 'data':
        return AchievementCategory.data;
      case 'coach':
        return AchievementCategory.coach;
      case 'health':
        return AchievementCategory.health;
      default:
        debugPrint('[AchievementCategory] Unknown category: "$raw". Falling back to gettingStarted.');
        return AchievementCategory.gettingStarted;
    }
  }

  /// Serializes to the API string slug.
  String get apiSlug {
    switch (this) {
      case AchievementCategory.gettingStarted:
        return 'getting_started';
      case AchievementCategory.consistency:
        return 'consistency';
      case AchievementCategory.goals:
        return 'goals';
      case AchievementCategory.data:
        return 'data';
      case AchievementCategory.coach:
        return 'coach';
      case AchievementCategory.health:
        return 'health';
    }
  }
}

// ── Achievement ───────────────────────────────────────────────────────────────

/// A single badge or achievement. [isUnlocked] is true when [unlockedAt] is set.
class Achievement {
  /// Creates an [Achievement].
  const Achievement({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    required this.iconName,
    this.unlockedAt,
    this.progressCurrent,
    this.progressTotal,
    this.progressLabel,
  });

  /// Unique numeric / UUID identifier.
  final String id;

  /// Machine-readable slug key (e.g. `first_sync`, `streak_7`).
  final String key;

  /// Short user-facing title.
  final String title;

  /// Longer description of what earned this achievement.
  final String description;

  /// Category group for display purposes.
  final AchievementCategory category;

  /// Icon identifier used for display (e.g. `trophy_gold`, `flame`).
  final String iconName;

  /// When the achievement was unlocked. Null if still locked.
  final DateTime? unlockedAt;

  /// Current progress toward unlocking (e.g. 3 out of 7 days).
  final int? progressCurrent;

  /// Total required to unlock (e.g. 7).
  final int? progressTotal;

  /// Human-readable progress label (e.g. "3 of 7 days complete").
  /// If null, falls back to "$progressCurrent of $progressTotal".
  final String? progressLabel;

  /// True when the achievement has been earned.
  bool get isUnlocked => unlockedAt != null;

  /// Deserializes from a JSON map.
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: AchievementCategory.fromString(json['category'] as String?),
      iconName: json['icon_name'] as String? ?? 'default',
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'] as String)
          : null,
      progressCurrent: (json['progress_current'] as num?)?.toInt(),
      progressTotal: (json['progress_total'] as num?)?.toInt(),
      progressLabel: json['progress_label'] as String?,
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'title': title,
        'description': description,
        'category': category.apiSlug,
        'icon_name': iconName,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'progress_current': progressCurrent,
        'progress_total': progressTotal,
        'progress_label': progressLabel,
      };
}

// ── AchievementList ───────────────────────────────────────────────────────────

/// List wrapper for a collection of [Achievement]s.
class AchievementList {
  /// Creates an [AchievementList].
  const AchievementList({required this.achievements});

  /// All achievements (both locked and unlocked).
  final List<Achievement> achievements;

  /// Deserializes from a JSON map.
  factory AchievementList.fromJson(Map<String, dynamic> json) {
    final rawAch = json['achievements'] as List<dynamic>? ?? [];
    return AchievementList(
      achievements: rawAch
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'achievements': achievements.map((a) => a.toJson()).toList(),
      };
}

// ── WoWMetric ─────────────────────────────────────────────────────────────────

/// A single week-over-week metric comparison.
///
/// [deltaPercent] is computed from [currentValue] and [previousValue]
/// and returns null when [previousValue] is zero to avoid division errors.
class WoWMetric {
  /// Creates a [WoWMetric].
  const WoWMetric({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.unit,
  });

  /// Human-readable metric label (e.g. "Avg Steps", "Sleep Duration").
  final String label;

  /// Value for the current week.
  final double currentValue;

  /// Value for the previous week.
  final double previousValue;

  /// Unit label (e.g. "steps/day", "hrs").
  final String unit;

  /// Percentage change from previous to current week.
  ///
  /// Returns null when [previousValue] is zero.
  double? get deltaPercent {
    if (previousValue == 0) return null;
    return ((currentValue - previousValue) / previousValue) * 100.0;
  }

  /// Deserializes from a JSON map.
  factory WoWMetric.fromJson(Map<String, dynamic> json) {
    return WoWMetric(
      label: json['label'] as String? ?? '',
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      previousValue: (json['previous_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'label': label,
        'current_value': currentValue,
        'previous_value': previousValue,
        'unit': unit,
      };
}

// ── WoWSummary ────────────────────────────────────────────────────────────────

/// Week-over-week summary for a single week, containing multiple [WoWMetric]s.
class WoWSummary {
  /// Creates a [WoWSummary].
  const WoWSummary({
    required this.weekLabel,
    required this.metrics,
  });

  /// Human-readable label for the current week (e.g. "Feb 24 – Mar 2").
  final String weekLabel;

  /// Individual metric comparisons within this summary.
  final List<WoWMetric> metrics;

  /// Deserializes from a JSON map.
  factory WoWSummary.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'] as List<dynamic>? ?? [];
    return WoWSummary(
      weekLabel: json['week_label'] as String? ?? '',
      metrics: rawMetrics
          .map((e) => WoWMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'week_label': weekLabel,
        'metrics': metrics.map((m) => m.toJson()).toList(),
      };
}

// ── ProgressHomeData ──────────────────────────────────────────────────────────

/// Aggregated payload for the Progress Home screen.
///
/// Combines goals, streaks, week-over-week summary, and recently
/// unlocked achievements into a single request.
class ProgressHomeData {
  /// Creates a [ProgressHomeData].
  const ProgressHomeData({
    required this.goals,
    required this.streaks,
    required this.wow,
    required this.recentAchievements,
    this.milestoneStreakCount,
    this.streakHistory = const {},
    this.weekHits = const {},
    this.nextAchievement,
  });

  /// Active user goals.
  final List<Goal> goals;

  /// All tracked streaks.
  final List<UserStreak> streaks;

  /// Week-over-week comparison summary.
  final WoWSummary wow;

  /// Achievements unlocked in the last 30 days, newest first.
  final List<Achievement> recentAchievements;

  /// Non-null when the user just hit a major streak milestone (7, 14, 30, 60,
  /// 90, 180, or 365 days). The value is the milestone day count.
  final int? milestoneStreakCount;

  /// 14-day activity history per streak type (key = streak type API slug).
  /// Each list has 14 booleans: index 0 = 14 days ago, index 13 = today.
  final Map<String, List<bool>> streakHistory;

  /// 7-day activity hits for the current Mon–Sun week per streak type.
  /// Each list has 7 booleans: index 0 = Monday, index 6 = Sunday.
  final Map<String, List<bool>> weekHits;

  /// The closest locked achievement to completion, or null if none.
  final Achievement? nextAchievement;

  /// Deserializes from a JSON map.
  factory ProgressHomeData.fromJson(Map<String, dynamic> json) {
    final rawGoals = json['goals'] as List<dynamic>? ?? [];
    final rawStreaks = json['streaks'] as List<dynamic>? ?? [];
    final rawAch = json['recent_achievements'] as List<dynamic>? ?? [];

    Map<String, List<bool>> parseHistoryMap(dynamic raw) {
      if (raw == null) return {};
      final map = raw as Map<String, dynamic>;
      return map.map((k, v) {
        final list = (v as List<dynamic>).map((e) => e as bool? ?? false).toList();
        return MapEntry(k, list);
      });
    }

    Achievement? nextAchievement;
    if (json['next_achievement'] != null) {
      nextAchievement = Achievement.fromJson(
        json['next_achievement'] as Map<String, dynamic>,
      );
    }

    return ProgressHomeData(
      goals: rawGoals
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList(),
      streaks: rawStreaks
          .map((e) => UserStreak.fromJson(e as Map<String, dynamic>))
          .toList(),
      wow: json['wow'] != null
          ? WoWSummary.fromJson(json['wow'] as Map<String, dynamic>)
          : const WoWSummary(weekLabel: '', metrics: []),
      recentAchievements: rawAch
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
      milestoneStreakCount: (json['milestone_streak_count'] as num?)?.toInt(),
      streakHistory: parseHistoryMap(json['streak_history']),
      weekHits: parseHistoryMap(json['week_hits']),
      nextAchievement: nextAchievement,
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'goals': goals.map((g) => g.toJson()).toList(),
        'streaks': streaks.map((s) => s.toJson()).toList(),
        'wow': wow.toJson(),
        'recent_achievements': recentAchievements.map((a) => a.toJson()).toList(),
        'milestone_streak_count': milestoneStreakCount,
        'streak_history': streakHistory,
        'week_hits': weekHits,
        'next_achievement': nextAchievement?.toJson(),
      };
}

// ── ReportMetric ──────────────────────────────────────────────────────────────

/// A single metric row displayed inside a [WeeklyReportCard].
class ReportMetric {
  /// Creates a [ReportMetric].
  const ReportMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.delta,
  });

  /// Human-readable metric label.
  final String label;

  /// Formatted value string (e.g. "8,432", "7h 14m").
  final String value;

  /// Unit label (e.g. "avg/day", "bpm").
  final String unit;

  /// Optional week-over-week delta string (e.g. "+5%", "-200 steps").
  final String? delta;

  /// Deserializes from a JSON map.
  factory ReportMetric.fromJson(Map<String, dynamic> json) {
    return ReportMetric(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '—',
      unit: json['unit'] as String? ?? '',
      delta: json['delta'] as String?,
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'unit': unit,
        'delta': delta,
      };
}

// ── WeeklyReportCard ──────────────────────────────────────────────────────────

/// One of up to 6 carousel cards in the weekly report.
///
/// [cardIndex] is 0-based (0–5). [gradientCategory] maps to the
/// corresponding `AppColors.category*` token for the card's gradient.
class WeeklyReportCard {
  /// Creates a [WeeklyReportCard].
  const WeeklyReportCard({
    required this.cardIndex,
    required this.title,
    required this.metrics,
    required this.aiText,
    required this.gradientCategory,
  });

  /// 0-based index of this card within the carousel (0–5).
  final int cardIndex;

  /// Card headline (e.g. "Activity", "Recovery").
  final String title;

  /// Metric rows shown on the card.
  final List<ReportMetric> metrics;

  /// AI-generated summary sentence shown at the bottom of the card.
  final String aiText;

  /// Category string used to resolve the card gradient color token
  /// (e.g. `"activity"`, `"sleep"`).
  final String gradientCategory;

  /// Deserializes from a JSON map.
  factory WeeklyReportCard.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'] as List<dynamic>? ?? [];
    return WeeklyReportCard(
      cardIndex: (json['card_index'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      metrics: rawMetrics
          .map((e) => ReportMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
      aiText: json['ai_text'] as String? ?? '',
      gradientCategory: json['gradient_category'] as String? ?? 'activity',
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'card_index': cardIndex,
        'title': title,
        'metrics': metrics.map((m) => m.toJson()).toList(),
        'ai_text': aiText,
        'gradient_category': gradientCategory,
      };
}

// ── WeeklyReport ──────────────────────────────────────────────────────────────

/// Full weekly report covering a specific ISO-8601 date range.
class WeeklyReport {
  /// Creates a [WeeklyReport].
  const WeeklyReport({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.cards,
  });

  /// Unique report identifier.
  final String id;

  /// ISO-8601 start date of the report period (inclusive).
  final String periodStart;

  /// ISO-8601 end date of the report period (inclusive).
  final String periodEnd;

  /// Carousel cards (up to 6), ordered for display.
  final List<WeeklyReportCard> cards;

  /// Deserializes from a JSON map.
  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>? ?? [];
    return WeeklyReport(
      id: json['id'] as String,
      periodStart: json['period_start'] as String? ?? '',
      periodEnd: json['period_end'] as String? ?? '',
      cards: rawCards
          .map((e) => WeeklyReportCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'period_start': periodStart,
        'period_end': periodEnd,
        'cards': cards.map((c) => c.toJson()).toList(),
      };
}

// ── JournalEntry ──────────────────────────────────────────────────────────────

/// A daily well-being journal entry logged by the user.
///
/// [mood], [energy], and [stress] are integer scores 1–10.
/// [sleepQuality] is nullable and also 1–10 when provided.
class JournalEntry {
  /// Creates a [JournalEntry].
  const JournalEntry({
    required this.id,
    required this.date,
    required this.mood,
    required this.energy,
    required this.stress,
    required this.notes,
    required this.tags,
    required this.createdAt,
    this.sleepQuality,
  });

  /// Unique entry identifier.
  final String id;

  /// ISO-8601 date this entry is associated with (e.g. "2026-03-04").
  final String date;

  /// Mood score 1–10 (1 = very low, 10 = excellent).
  final int mood;

  /// Energy score 1–10.
  final int energy;

  /// Stress score 1–10 (1 = very low, 10 = very high).
  final int stress;

  /// Optional sleep quality score 1–10. Null if not provided.
  final int? sleepQuality;

  /// Free-form notes text. Empty string when none provided.
  final String notes;

  /// User-defined tags (e.g. `["gym", "busy", "good-mood"]`).
  final List<String> tags;

  /// When this entry was created (server timestamp).
  final DateTime createdAt;

  /// Deserializes from a JSON map.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? [];
    return JournalEntry(
      id: json['id'] as String,
      date: json['date'] as String? ?? '',
      mood: (json['mood'] as num?)?.toInt() ?? 5,
      energy: (json['energy'] as num?)?.toInt() ?? 5,
      stress: (json['stress'] as num?)?.toInt() ?? 5,
      sleepQuality: (json['sleep_quality'] as num?)?.toInt(),
      notes: json['notes'] as String? ?? '',
      tags: rawTags.whereType<String>().toList(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'mood': mood,
        'energy': energy,
        'stress': stress,
        'sleep_quality': sleepQuality,
        'notes': notes,
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── JournalPage ───────────────────────────────────────────────────────────────

/// Paginated journal history response.
class JournalPage {
  /// Creates a [JournalPage].
  const JournalPage({
    required this.entries,
    required this.hasMore,
  });

  /// Journal entries on this page, newest first.
  final List<JournalEntry> entries;

  /// Whether additional pages are available.
  final bool hasMore;

  /// Deserializes from a JSON map.
  factory JournalPage.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return JournalPage(
      entries: rawEntries
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'has_more': hasMore,
      };
}
