/// User Preferences Model — Dart mirror of the backend `user_preferences` table.
///
/// This immutable value class represents the full set of user-configurable
/// preferences stored in the cloud-brain API (`GET/PATCH /api/v1/preferences`).
/// It covers coaching, appearance, notifications, privacy, and units.
///
/// All fields map 1-to-1 with backend columns. New columns added in the
/// settings-mapping remediation (response_length, suggested_prompts_enabled,
/// voice_input_enabled, data_maturity_banner_dismissed,
/// analytics_opt_out) are included here.
library;

import 'package:flutter/material.dart' show TimeOfDay, immutable;

// ── Enums ──────────────────────────────────────────────────────────────────────

enum CoachPersona {
  toughLove('tough_love'),
  balanced('balanced'),
  gentle('gentle');

  const CoachPersona(this.value);
  final String value;

  static CoachPersona fromValue(String v) =>
      CoachPersona.values.firstWhere((e) => e.value == v,
          orElse: () => CoachPersona.balanced);
}

enum ProactivityLevel {
  low('low'),
  medium('medium'),
  high('high');

  const ProactivityLevel(this.value);
  final String value;

  static ProactivityLevel fromValue(String v) =>
      ProactivityLevel.values.firstWhere((e) => e.value == v,
          orElse: () => ProactivityLevel.medium);
}

enum ResponseLength {
  concise('concise'),
  detailed('detailed');

  const ResponseLength(this.value);
  final String value;

  static ResponseLength fromValue(String v) =>
      ResponseLength.values.firstWhere((e) => e.value == v,
          orElse: () => ResponseLength.concise);
}

enum AppTheme {
  dark('dark'),
  light('light'),
  system('system');

  const AppTheme(this.value);
  final String value;

  static AppTheme fromValue(String v) =>
      AppTheme.values.firstWhere((e) => e.value == v,
          orElse: () => AppTheme.system);
}

enum UnitsSystem {
  metric('metric'),
  imperial('imperial');

  const UnitsSystem(this.value);
  final String value;

  static UnitsSystem fromValue(String v) =>
      UnitsSystem.values.firstWhere((e) => e.value == v,
          orElse: () => UnitsSystem.metric);
}

/// Maps each [UnitsSystem] to its human-readable water-volume unit label.
extension UnitsSystemWaterLabel on UnitsSystem {
  String get waterUnitLabel => switch (this) {
    UnitsSystem.metric   => 'glasses (250 ml)',
    UnitsSystem.imperial => 'glasses (8 oz)',
  };
}

enum FitnessLevel {
  beginner('beginner'),
  active('active'),
  athletic('athletic');

  const FitnessLevel(this.value);
  final String value;

  static FitnessLevel fromValue(String v) =>
      FitnessLevel.values.firstWhere((e) => e.value == v,
          orElse: () => FitnessLevel.active);
}

// ── Notification Settings sub-model ───────────────────────────────────────────

/// Maps the `notification_settings` JSON column.
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.smartRemindersEnabled = true,
    this.patternReminders = true,
    this.gapReminders = true,
    this.goalReminders = true,
    this.celebrationReminders = true,
    this.reminderFrequency = 2,
    this.streakReminders = true,
    this.achievementNotifications = true,
    this.anomalyAlerts = true,
    this.integrationAlerts = true,
  });

  final bool smartRemindersEnabled;
  final bool patternReminders;
  final bool gapReminders;
  final bool goalReminders;
  final bool celebrationReminders;
  final int reminderFrequency; // 1, 2, or 3 per day
  final bool streakReminders;
  final bool achievementNotifications;
  final bool anomalyAlerts;
  final bool integrationAlerts;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        smartRemindersEnabled:
            json['smart_reminders_enabled'] as bool? ?? true,
        patternReminders: json['pattern_reminders'] as bool? ?? true,
        gapReminders: json['gap_reminders'] as bool? ?? true,
        goalReminders: json['goal_reminders'] as bool? ?? true,
        celebrationReminders:
            json['celebration_reminders'] as bool? ?? true,
        reminderFrequency: json['reminder_frequency'] as int? ?? 2,
        streakReminders: json['streak_reminders'] as bool? ?? true,
        achievementNotifications:
            json['achievement_notifications'] as bool? ?? true,
        anomalyAlerts: json['anomaly_alerts'] as bool? ?? true,
        integrationAlerts: json['integration_alerts'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'smart_reminders_enabled': smartRemindersEnabled,
        'pattern_reminders': patternReminders,
        'gap_reminders': gapReminders,
        'goal_reminders': goalReminders,
        'celebration_reminders': celebrationReminders,
        'reminder_frequency': reminderFrequency,
        'streak_reminders': streakReminders,
        'achievement_notifications': achievementNotifications,
        'anomaly_alerts': anomalyAlerts,
        'integration_alerts': integrationAlerts,
      };

  NotificationSettings copyWith({
    bool? smartRemindersEnabled,
    bool? patternReminders,
    bool? gapReminders,
    bool? goalReminders,
    bool? celebrationReminders,
    int? reminderFrequency,
    bool? streakReminders,
    bool? achievementNotifications,
    bool? anomalyAlerts,
    bool? integrationAlerts,
  }) =>
      NotificationSettings(
        smartRemindersEnabled:
            smartRemindersEnabled ?? this.smartRemindersEnabled,
        patternReminders: patternReminders ?? this.patternReminders,
        gapReminders: gapReminders ?? this.gapReminders,
        goalReminders: goalReminders ?? this.goalReminders,
        celebrationReminders:
            celebrationReminders ?? this.celebrationReminders,
        reminderFrequency: reminderFrequency ?? this.reminderFrequency,
        streakReminders: streakReminders ?? this.streakReminders,
        achievementNotifications:
            achievementNotifications ?? this.achievementNotifications,
        anomalyAlerts: anomalyAlerts ?? this.anomalyAlerts,
        integrationAlerts: integrationAlerts ?? this.integrationAlerts,
      );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Converts a nullable "HH:MM" string from the backend to [TimeOfDay].
///
/// Returns null for any malformed input. Hour is clamped to [0, 23] and
/// minute to [0, 59] so a corrupted API value can never produce an invalid
/// [TimeOfDay] that throws a [RangeError] during rendering.
TimeOfDay? _timeFromString(String? s) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split(':');
  if (parts.length < 2) return null;
  final hour = (int.tryParse(parts[0]) ?? 0).clamp(0, 23);
  final minute = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);
  return TimeOfDay(hour: hour, minute: minute);
}

/// Converts a [TimeOfDay] to the "HH:MM" format expected by the backend.
String? _timeToString(TimeOfDay? t) {
  if (t == null) return null;
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ── Main model ─────────────────────────────────────────────────────────────────

/// Immutable Dart mirror of the backend `user_preferences` table.
///
/// Deserialise with [UserPreferencesModel.fromJson] from the API response.
/// Serialise with [toJson] / [toPatchJson] when calling PATCH.
/// Clone with incremental changes via [copyWith].
@immutable
class UserPreferencesModel {
  const UserPreferencesModel({
    required this.id,
    required this.userId,
    // Coach
    this.coachPersona = CoachPersona.balanced,
    this.proactivityLevel = ProactivityLevel.medium,
    this.responseLength = ResponseLength.concise,
    this.suggestedPromptsEnabled = true,
    this.voiceInputEnabled = true,
    // Dashboard layout (opaque JSON — owned by the Data tab)
    this.dashboardLayout,
    // Notification settings (JSON sub-object)
    this.notificationSettings = const NotificationSettings(),
    // Appearance
    this.appTheme = AppTheme.system,
    this.hapticEnabled = true,
    this.tooltipsEnabled = true,
    this.onboardingComplete = false,
    // Scheduling
    this.morningBriefingEnabled = true,
    this.morningBriefingTime,
    this.checkinReminderEnabled = false,
    this.checkinReminderTime,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    // Privacy & visibility
    this.dataMaturityBannerDismissed = false,
    this.analyticsOptOut = false,
    // AI memory
    this.memoryEnabled = true,
    // Account
    this.goals,
    this.unitsSystem = UnitsSystem.metric,
    this.fitnessLevel,
    // Timestamps (read-only from API)
    this.createdAt,
    this.updatedAt,
  });

  // Identity
  final String id;
  final String userId;

  // Coach
  final CoachPersona coachPersona;
  final ProactivityLevel proactivityLevel;
  final ResponseLength responseLength;
  final bool suggestedPromptsEnabled;
  final bool voiceInputEnabled;

  // Dashboard layout (opaque — managed by DashboardLayout, not this model)
  final Map<String, dynamic>? dashboardLayout;

  // Notification settings JSON sub-object
  final NotificationSettings notificationSettings;

  // Appearance
  final AppTheme appTheme;
  final bool hapticEnabled;
  final bool tooltipsEnabled;
  final bool onboardingComplete;

  // Scheduling
  final bool morningBriefingEnabled;
  final TimeOfDay? morningBriefingTime;
  final bool checkinReminderEnabled;
  final TimeOfDay? checkinReminderTime;
  final bool quietHoursEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;

  // Privacy & visibility
  final bool dataMaturityBannerDismissed;
  final bool analyticsOptOut;

  // AI memory
  final bool memoryEnabled;

  // Account
  final List<String>? goals;
  final UnitsSystem unitsSystem;
  final FitnessLevel? fitnessLevel;

  // Timestamps (read-only)
  final String? createdAt;
  final String? updatedAt;

  // ── Deserialization ──────────────────────────────────────────────────────────

  factory UserPreferencesModel.fromJson(Map<String, dynamic> json) {
    final notifJson = json['notification_settings'];
    final notifSettings = notifJson is Map<String, dynamic>
        ? NotificationSettings.fromJson(notifJson)
        : const NotificationSettings();

    final rawGoals = json['goals'];
    final goalsList = rawGoals is List
        ? rawGoals.map((e) => e.toString()).toList()
        : null;

    final rawFitnessLevel = json['fitness_level'] as String?;

    return UserPreferencesModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      // Coach
      coachPersona: CoachPersona.fromValue(
          json['coach_persona'] as String? ?? 'balanced'),
      proactivityLevel: ProactivityLevel.fromValue(
          json['proactivity_level'] as String? ?? 'medium'),
      responseLength: ResponseLength.fromValue(
          json['response_length'] as String? ?? 'concise'),
      suggestedPromptsEnabled:
          json['suggested_prompts_enabled'] as bool? ?? true,
      voiceInputEnabled: json['voice_input_enabled'] as bool? ?? true,
      // Dashboard layout
      dashboardLayout: json['dashboard_layout'] is Map<String, dynamic>
          ? json['dashboard_layout'] as Map<String, dynamic>
          : null,
      // Notification settings
      notificationSettings: notifSettings,
      // Appearance
      appTheme: AppTheme.fromValue(json['theme'] as String? ?? 'system'),
      hapticEnabled: json['haptic_enabled'] as bool? ?? true,
      tooltipsEnabled: json['tooltips_enabled'] as bool? ?? true,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      // Scheduling
      morningBriefingEnabled:
          json['morning_briefing_enabled'] as bool? ?? true,
      morningBriefingTime:
          _timeFromString(json['morning_briefing_time'] as String?),
      checkinReminderEnabled:
          json['checkin_reminder_enabled'] as bool? ?? false,
      checkinReminderTime:
          _timeFromString(json['checkin_reminder_time'] as String?),
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart:
          _timeFromString(json['quiet_hours_start'] as String?),
      quietHoursEnd: _timeFromString(json['quiet_hours_end'] as String?),
      // Privacy & visibility
      dataMaturityBannerDismissed:
          json['data_maturity_banner_dismissed'] as bool? ?? false,
      analyticsOptOut: json['analytics_opt_out'] as bool? ?? false,
      memoryEnabled: json['memory_enabled'] as bool? ?? true,
      // Account
      goals: goalsList,
      unitsSystem: UnitsSystem.fromValue(
          json['units_system'] as String? ?? 'metric'),
      fitnessLevel: rawFitnessLevel != null
          ? FitnessLevel.fromValue(rawFitnessLevel)
          : null,
      // Timestamps
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  // ── Serialization ────────────────────────────────────────────────────────────

  /// Full JSON representation (for caching / local storage).
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'coach_persona': coachPersona.value,
        'proactivity_level': proactivityLevel.value,
        'response_length': responseLength.value,
        'suggested_prompts_enabled': suggestedPromptsEnabled,
        'voice_input_enabled': voiceInputEnabled,
        'dashboard_layout': dashboardLayout,
        'notification_settings': notificationSettings.toJson(),
        'theme': appTheme.value,
        'haptic_enabled': hapticEnabled,
        'tooltips_enabled': tooltipsEnabled,
        'onboarding_complete': onboardingComplete,
        'morning_briefing_enabled': morningBriefingEnabled,
        'morning_briefing_time': _timeToString(morningBriefingTime),
        'checkin_reminder_enabled': checkinReminderEnabled,
        'checkin_reminder_time': _timeToString(checkinReminderTime),
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_hours_start': _timeToString(quietHoursStart),
        'quiet_hours_end': _timeToString(quietHoursEnd),
        'data_maturity_banner_dismissed': dataMaturityBannerDismissed,
        'analytics_opt_out': analyticsOptOut,
        'memory_enabled': memoryEnabled,
        'goals': goals,
        'units_system': unitsSystem.value,
        'fitness_level': fitnessLevel?.value,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Partial JSON for PATCH requests — omits identity and timestamp fields.
  Map<String, dynamic> toPatchJson() => {
        'coach_persona': coachPersona.value,
        'proactivity_level': proactivityLevel.value,
        'response_length': responseLength.value,
        'suggested_prompts_enabled': suggestedPromptsEnabled,
        'voice_input_enabled': voiceInputEnabled,
        'notification_settings': notificationSettings.toJson(),
        'theme': appTheme.value,
        'haptic_enabled': hapticEnabled,
        'tooltips_enabled': tooltipsEnabled,
        'onboarding_complete': onboardingComplete,
        'morning_briefing_enabled': morningBriefingEnabled,
        'morning_briefing_time': _timeToString(morningBriefingTime),
        'checkin_reminder_enabled': checkinReminderEnabled,
        'checkin_reminder_time': _timeToString(checkinReminderTime),
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_hours_start': _timeToString(quietHoursStart),
        'quiet_hours_end': _timeToString(quietHoursEnd),
        'data_maturity_banner_dismissed': dataMaturityBannerDismissed,
        'analytics_opt_out': analyticsOptOut,
        'memory_enabled': memoryEnabled,
        'goals': goals,
        'units_system': unitsSystem.value,
        'fitness_level': fitnessLevel?.value,
      };

  // ── copyWith ─────────────────────────────────────────────────────────────────

  UserPreferencesModel copyWith({
    String? id,
    String? userId,
    CoachPersona? coachPersona,
    ProactivityLevel? proactivityLevel,
    ResponseLength? responseLength,
    bool? suggestedPromptsEnabled,
    bool? voiceInputEnabled,
    Map<String, dynamic>? dashboardLayout,
    NotificationSettings? notificationSettings,
    AppTheme? appTheme,
    bool? hapticEnabled,
    bool? tooltipsEnabled,
    bool? onboardingComplete,
    bool? morningBriefingEnabled,
    TimeOfDay? morningBriefingTime,
    bool? checkinReminderEnabled,
    TimeOfDay? checkinReminderTime,
    bool? quietHoursEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? dataMaturityBannerDismissed,
    bool? analyticsOptOut,
    bool? memoryEnabled,
    List<String>? goals,
    UnitsSystem? unitsSystem,
    FitnessLevel? fitnessLevel,
    String? createdAt,
    String? updatedAt,
  }) =>
      UserPreferencesModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        coachPersona: coachPersona ?? this.coachPersona,
        proactivityLevel: proactivityLevel ?? this.proactivityLevel,
        responseLength: responseLength ?? this.responseLength,
        suggestedPromptsEnabled:
            suggestedPromptsEnabled ?? this.suggestedPromptsEnabled,
        voiceInputEnabled: voiceInputEnabled ?? this.voiceInputEnabled,
        dashboardLayout: dashboardLayout ?? this.dashboardLayout,
        notificationSettings: notificationSettings ?? this.notificationSettings,
        appTheme: appTheme ?? this.appTheme,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        tooltipsEnabled: tooltipsEnabled ?? this.tooltipsEnabled,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        morningBriefingEnabled:
            morningBriefingEnabled ?? this.morningBriefingEnabled,
        morningBriefingTime: morningBriefingTime ?? this.morningBriefingTime,
        checkinReminderEnabled:
            checkinReminderEnabled ?? this.checkinReminderEnabled,
        checkinReminderTime: checkinReminderTime ?? this.checkinReminderTime,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietHoursStart: quietHoursStart ?? this.quietHoursStart,
        quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
        dataMaturityBannerDismissed:
            dataMaturityBannerDismissed ?? this.dataMaturityBannerDismissed,
        analyticsOptOut: analyticsOptOut ?? this.analyticsOptOut,
        memoryEnabled: memoryEnabled ?? this.memoryEnabled,
        goals: goals ?? this.goals,
        unitsSystem: unitsSystem ?? this.unitsSystem,
        fitnessLevel: fitnessLevel ?? this.fitnessLevel,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
