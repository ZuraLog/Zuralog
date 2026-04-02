/// Centralized PostHog event name constants.
///
/// All event names used across the app are defined here to prevent typos,
/// enable grep-based auditing, and document the full event schema.
///
/// Privacy rules (mvp-features.md Section 9):
///  - No PII (names, emails, phone numbers) in any event property.
///  - No raw health values (HR, weight, calories) in event properties.
///  - Track counts, booleans, types — not content.
///  - File attachment content and AI memory content are never sent.
library;

/// All PostHog event name constants for Zuralog.
abstract final class AnalyticsEvents {
  // ── App Lifecycle ────────────────────────────────────────────────────────────
  static const String appOpened = 'app_opened';
  static const String appBackgrounded = 'app_backgrounded';
  /// Include `screen_count` (int), `duration_seconds` (int).
  static const String sessionEnded = 'session_ended';

  // ── Auth ─────────────────────────────────────────────────────────────────────
  /// Include `method` ('email' | 'google' | 'apple').
  static const String signUpCompleted = 'sign_up_completed';
  /// Include `method` ('email' | 'google' | 'apple').
  static const String loginCompleted = 'login_completed';
  /// Include `method` ('email' | 'google' | 'apple'), `error_type` (string).
  static const String loginFailed = 'login_failed';
  /// Include `method` ('email' | 'google' | 'apple'), `error_type` (string).
  static const String signUpFailed = 'sign_up_failed';
  static const String loggedOut = 'logged_out';

  // ── Onboarding ───────────────────────────────────────────────────────────────
  static const String onboardingStarted = 'onboarding_started';
  /// Emitted when a step is completed. Include `step` (int 1-6), `step_name` (string).
  static const String onboardingStepCompleted = 'onboarding_step_completed';
  /// Emitted when user goes back. Include `from_step` (int).
  static const String onboardingStepBack = 'onboarding_step_back';
  /// Include `goals` (`List<String>` — goal keys, no PII).
  static const String onboardingGoalsSelected = 'onboarding_goals_selected';
  /// Include `persona` ('tough_love' | 'balanced' | 'gentle').
  static const String onboardingPersonaSelected = 'onboarding_persona_selected';
  /// Include `level` ('low' | 'medium' | 'high').
  static const String onboardingProactivitySelected = 'onboarding_proactivity_selected';
  /// Include `type` ('morning_briefing' | 'smart_reminders' | 'wellness_checkin'),
  /// `enabled` (bool).
  static const String onboardingNotificationToggled = 'onboarding_notification_toggled';
  /// Include `goals_count` (int), `persona` (string), `proactivity` (string),
  /// `integrations_connected` (int), `notifications_enabled_count` (int).
  static const String onboardingCompleted = 'onboarding_completed';
  /// Step 6 — where did you hear about us? Include `source` (string).
  static const String onboardingDiscoverySource = 'onboarding_discovery_source';

  // ── Today Tab ────────────────────────────────────────────────────────────────
  static const String healthScoreTapped = 'health_score_tapped';
  /// Include `insight_type` (string), `is_unread` (bool), `insight_id` (string),
  /// `category` (string).
  static const String insightCardTapped = 'insight_card_tapped';
  /// Include `insight_type` (string), `category` (string).
  static const String insightDetailViewed = 'insight_detail_viewed';
  static const String insightDetailCoachTapped = 'insight_detail_coach_tapped';
  /// Include `title` (string — action label, no PII).
  static const String quickActionTapped = 'quick_action_tapped';
  /// Include `source` ('fab' | 'wellness_card' | 'quick_action').
  static const String quickLogOpened = 'quick_log_opened';
  /// Include `has_mood`, `has_energy`, `has_stress`, `water_glasses`,
  /// `has_notes`, `symptoms_count` — no raw values.
  static const String quickLogSubmitted = 'quick_log_submitted';
  /// Include `source` ('fab' | 'wellness_card' | 'quick_action').
  static const String quickLogDismissed = 'quick_log_dismissed';
  /// First time the user submits a quick log. No properties (server-side dedup).
  static const String firstQuickLog = 'first_quick_log';
  /// Include `fields_completed` (int 1-5).
  static const String wellnessCheckinCompleted = 'wellness_checkin_completed';
  static const String notificationHistoryViewed = 'notification_history_viewed';
  /// Include `notification_type` (string).
  static const String notificationTapped = 'notification_tapped';
  static const String todayFeedRefreshed = 'today_feed_refreshed';
  static const String dataMaturityBannerDismissed = 'data_maturity_banner_dismissed';

  // ── Coach Tab ────────────────────────────────────────────────────────────────
  /// Include `source` ('new_chat' | 'thread'), `char_count` (int).
  static const String coachMessageSent = 'coach_message_sent';
  /// Include `suggestion_text` (string label — no PII, just the template text).
  static const String coachSuggestionTapped = 'coach_suggestion_tapped';
  /// Include `title` (string label, no raw content).
  static const String coachQuickActionTapped = 'coach_quick_action_tapped';
  /// Include `file_type` ('image' | 'pdf' | 'text' | 'csv').
  static const String attachmentSent = 'attachment_sent';
  /// First file attachment sent. Include `file_type`.
  static const String firstFileAttachment = 'first_file_attachment';
  static const String memoryExtractionConfirmed = 'memory_extraction_confirmed';
  static const String nlLogConfirmed = 'nl_log_confirmed';
  /// Include `source` ('voice_button').
  static const String voiceInputStarted = 'voice_input_started';
  /// Include `char_count` (int), `duration_seconds` (int).
  static const String voiceInputCompleted = 'voice_input_completed';
  static const String voiceInputCancelled = 'voice_input_cancelled';
  /// Include `conversation_id` (string — no PII).
  static const String conversationOpened = 'conversation_opened';
  /// Include `conversation_count` (int).
  static const String conversationDrawerOpened = 'conversation_drawer_opened';

  // ── Data Tab ─────────────────────────────────────────────────────────────────
  /// Include `category` (string).
  static const String categoryCardTapped = 'category_card_tapped';
  /// Include `category` (string), `time_range` ('7d' | '30d' | '90d' | 'custom').
  static const String categoryDetailViewed = 'category_detail_viewed';
  /// Include `metric_name` (string), `source` (string).
  static const String metricDetailViewed = 'metric_detail_viewed';
  static const String metricDetailCoachTapped = 'metric_detail_coach_tapped';
  static const String dashboardReorderStarted = 'dashboard_reorder_started';
  /// Include `visible_count` (int), `hidden_count` (int).
  static const String dashboardLayoutSaved = 'dashboard_layout_saved';

  // ── Progress Tab ─────────────────────────────────────────────────────────────
  static const String progressHomeViewed = 'progress_home_viewed';
  /// Include `section` (string — 'goals' | 'achievements' | 'report' | 'journal').
  static const String progressNavTapped = 'progress_nav_tapped';
  /// First time user creates a goal.
  static const String firstGoalCreated = 'first_goal_created';
  /// Include `goal_type` (string), `period` ('daily' | 'weekly' | 'long_term'),
  /// `has_deadline` (bool).
  static const String goalCreated = 'goal_created';
  /// Include `goal_type` (string), `goal_id` (string).
  static const String goalUpdated = 'goal_updated';
  static const String goalDeleted = 'goal_deleted';
  /// Include `goal_type`, `progress_percent` (int), `is_completed` (bool).
  static const String goalTapped = 'goal_tapped';
  /// Include `goal_type` (string), `final_progress_percent` (int).
  static const String goalCompleted = 'goal_completed';
  /// Include `streak_type` (string), `current_count` (int).
  static const String streakMilestoneViewed = 'streak_milestone_viewed';
  /// Include `streak_type` (string), `streak_count` (int).
  static const String streakStarted = 'streak_started';
  /// Include `streak_type` (string), `streak_count` (int).
  static const String streakBroken = 'streak_broken';
  static const String streakFreezeUsed = 'streak_freeze_used';
  /// Include `achievement_key` (string), `is_unlocked` (bool).
  static const String achievementViewed = 'achievement_viewed';
  static const String achievementsScreenViewed = 'achievements_screen_viewed';
  /// Include `achievement_key` (string).
  static const String achievementUnlocked = 'achievement_unlocked';
  /// Include `type` ('weekly' | 'monthly').
  static const String reportViewed = 'report_viewed';
  /// Include `type` ('weekly' | 'monthly'), `format` ('image' | 'pdf').
  static const String reportShared = 'report_shared';
  static const String journalEntryCreated = 'journal_entry_created';
  static const String journalEntryUpdated = 'journal_entry_updated';

  // ── Trends Tab ───────────────────────────────────────────────────────────────
  static const String trendsHomeViewed = 'trends_home_viewed';
  /// Include `section` (string — 'explorer' | 'reports' | 'sources').
  static const String trendsNavTapped = 'trends_nav_tapped';
  /// Include `metric_a` (string), `metric_b` (string), `time_range` (string).
  static const String correlationTapped = 'correlation_tapped';
  static const String correlationSuggestionTapped = 'correlation_suggestion_tapped';
  /// Include `metric_a` (string), `metric_b` (string).
  static const String correlationsScreenViewed = 'correlations_screen_viewed';
  /// Include `metric_name` (string), `position` ('metric_a' | 'metric_b').
  static const String correlationMetricSelected = 'correlation_metric_selected';
  /// Include `time_range` (string), `context` ('correlations' | 'category_detail').
  static const String timeRangeChanged = 'time_range_changed';
  /// Include `lag_days` (int).
  static const String correlationLagChanged = 'correlation_lag_changed';
  static const String dataSourcesTapped = 'data_sources_tapped';
  /// Include `integration` (string).
  static const String dataSourceReconnectTapped = 'data_source_reconnect_tapped';
  // -- Trends Tab -----------------------------------------------------------
  /// Fired when any pattern card is tapped. Include: pattern_id, category,
  /// strength ('strong'|'moderate'|'weak'), is_new (bool).
  static const String trendsPatternTapped = 'trends_pattern_tapped';
  /// Fired when a pattern card finishes expanding. Include: pattern_id, time_range.
  static const String trendsPatternExpanded = 'trends_pattern_expanded';
  /// Fired when the category filter chip changes. Include: category.
  static const String trendsFilterChanged = 'trends_filter_changed';
  /// Fired when the time range chip is changed on an expanded card. Include: pattern_id, time_range.
  static const String trendsTimeRangeChanged = 'trends_time_range_changed';
  /// Fired when the "Ask Coach" CTA inside an expanded card is tapped. Include: pattern_id.
  static const String trendsCoachCtaTapped = 'trends_coach_cta_tapped';

  // ── Settings ─────────────────────────────────────────────────────────────────
  /// Include `section` (string).
  static const String settingsSectionOpened = 'settings_section_opened';
  /// Include `theme` ('dark' | 'light' | 'system').
  static const String themeChanged = 'theme_changed';
  /// Include `persona` ('tough_love' | 'balanced' | 'gentle').
  static const String personaChanged = 'persona_changed';
  /// Include `level` ('low' | 'medium' | 'high').
  static const String proactivityChanged = 'proactivity_changed';
  /// Include `setting` (string), `enabled` (bool).
  static const String notificationSettingChanged = 'notification_setting_changed';
  /// Include `frequency` ('low' | 'medium' | 'high').
  static const String notificationFrequencyChanged = 'notification_frequency_changed';
  /// Include `haptic_enabled` (bool).
  static const String hapticToggled = 'haptic_toggled';
  static const String tooltipsReset = 'tooltips_reset';
  static const String memoryDeleted = 'memory_deleted';
  static const String allMemoriesCleared = 'all_memories_cleared';
  static const String memoryToggled = 'memory_toggled';
  static const String dataExportRequested = 'data_export_requested';
  /// Include `confirmation` (bool — always true when fired, only fire on confirm).
  static const String accountDeleteRequested = 'account_delete_requested';

  // ── Integrations ─────────────────────────────────────────────────────────────
  /// Include `provider` (string).
  static const String integrationConnected = 'integration_connected';
  /// Include `provider` (string).
  static const String integrationDisconnected = 'integration_disconnected';
  /// Include `provider` (string).
  static const String integrationReconnected = 'integration_reconnected';
  /// Include `provider` (string), `record_count` (int).
  static const String integrationSyncCompleted = 'integration_sync_completed';
  /// Include `provider` (string), `error_type` (string).
  static const String integrationSyncFailed = 'integration_sync_failed';
  /// Include `provider` (string).
  static const String integrationSyncStarted = 'integration_sync_started';
  /// Include `platform` ('apple_health' | 'health_connect').
  static const String healthSyncStarted = 'health_sync_started';
  /// Include `platform` ('apple_health' | 'health_connect'), `record_count` (int).
  static const String healthSyncCompleted = 'health_sync_completed';
  /// Include `platform` ('apple_health' | 'health_connect'), `error_type` (string).
  static const String healthSyncFailed = 'health_sync_failed';
  /// Include `record_count` (int).
  static const String healthKitSyncCompleted = 'health_kit_sync_completed';
  /// Include `error_type` (string).
  static const String healthKitSyncFailed = 'health_kit_sync_failed';
  /// Include `provider` (string — 'coming_soon' label, not user data).
  static const String comingSoonIntegrationTapped = 'coming_soon_integration_tapped';

  // ── Subscription ─────────────────────────────────────────────────────────────
  /// Include `source` (string — where paywall was triggered from).
  static const String subscriptionUpgradeStarted = 'subscription_upgrade_started';
  /// Include `plan` (string), `price` (string — no actual price, just tier label).
  static const String subscriptionUpgradeCompleted = 'subscription_upgrade_completed';
  static const String subscriptionCancelled = 'subscription_cancelled';
  /// Include `source` (string — which feature triggered the paywall).
  static const String paywallViewed = 'paywall_viewed';
  static const String paywallDismissed = 'paywall_dismissed';

  // ── Feature Adoption (first-use gates) ───────────────────────────────────────
  // These fire exactly once per user lifetime via SharedPreferences guard.
  static const String firstAttachmentSent = 'first_file_attachment'; // alias
  static const String firstInsightViewed = 'first_insight_viewed';
  static const String firstCorrelationViewed = 'first_correlation_viewed';
  static const String firstStreakStarted = 'first_streak_started';
  static const String firstAchievementUnlocked = 'first_achievement_unlocked';
  static const String firstVoiceInput = 'first_voice_input';
  static const String firstWellnessCheckin = 'first_wellness_checkin';

  // ── Engagement / Session ─────────────────────────────────────────────────────
  /// Include `hour_of_day` (int 0-23), `day_of_week` (int 1-7).
  static const String sessionStarted = 'session_started';
  /// Include `screens_visited` (int), `duration_seconds` (int),
  /// `messages_sent` (int), `hour_of_day` (int 0-23).
  static const String sessionSummary = 'session_summary';
  /// Include `notification_type` (string).
  static const String notificationTapThrough = 'notification_tap_through';

  // ── Anomaly Detection ─────────────────────────────────────────────────────────
  /// Include `metric_category` (string — category label, no value), `severity` ('medium' | 'high').
  static const String anomalyAlertViewed = 'anomaly_alert_viewed';
  /// Include `metric_category` (string).
  static const String anomalyAlertCoachTapped = 'anomaly_alert_coach_tapped';
}
