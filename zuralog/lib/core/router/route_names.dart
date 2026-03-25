/// Zuralog Edge Agent — Route Name & Path Constants.
///
/// Centralizes all route names and path strings used by [GoRouter].
/// Using constants prevents typos and makes refactoring safe — every
/// navigation call references these symbols rather than raw strings.
///
/// **Naming convention:**
/// - `*Name` — the named route identifier (used with `GoRouter.go`).
/// - `*Path` — the URL path string (registered in the router config).
///
/// **Route tree (5-tab shell):**
/// ```
/// /today                          → TodayFeedScreen (tab 0)
///   /today/insight/:id            → InsightDetailScreen
///   /today/notifications          → NotificationHistoryScreen
///   /today/log/metric-picker      → MetricPickerScreen
 /// /data                           → HealthDashboardScreen (tab 1)
 ///   /data/category/:id            → CategoryDetailScreen
 ///   /data/metric/:id              → MetricDetailScreen
 ///   /data/score-breakdown         → ScoreBreakdownScreen
/// /coach                          → NewChatScreen (tab 2)
///   /coach/thread/:id             → ChatThreadScreen
/// /progress                       → ProgressHomeScreen (tab 3)
///   /progress/goals               → GoalsScreen
///   /progress/goals/:id           → GoalDetailScreen
///   /progress/achievements        → AchievementsScreen
///   /progress/report              → WeeklyReportScreen
///   /progress/journal             → JournalScreen
/// /trends                         → TrendsHomeScreen (tab 4)
///   /trends/correlations          → CorrelationsScreen
///   /trends/reports               → ReportsScreen
///   /trends/sources               → DataSourcesScreen
/// /settings                       → SettingsHubScreen (pushed over shell)
///   /settings/account             → AccountSettingsScreen
///   /settings/notifications       → NotificationSettingsScreen
///   /settings/appearance          → AppearanceSettingsScreen
///   /settings/coach               → CoachSettingsScreen
///   /settings/integrations        → IntegrationsScreen
///   /settings/privacy             → PrivacyDataScreen
///   /settings/subscription        → SubscriptionScreen
///   /settings/about               → AboutScreen
/// /profile                        → ProfileScreen (pushed over shell)
///   /profile/emergency-card       → EmergencyCardScreen
///   /profile/emergency-card/edit  → EmergencyCardEditScreen
/// ```
library;

/// Route name and path constants for the Zuralog application.
///
/// All navigation within the app must reference these constants instead
/// of inline string literals to avoid typo-driven routing failures.
abstract final class RouteNames {
  // ── Onboarding & Auth ────────────────────────────────────────────────────

  /// Name for the welcome/onboarding entry screen.
  static const String welcome = 'welcome';

  /// Path for the welcome screen.
  static const String welcomePath = '/welcome';

  /// Name for the multi-page onboarding value-prop slideshow.
  static const String onboarding = 'onboarding';

  /// Path for the onboarding page view.
  static const String onboardingPath = '/onboarding';

  /// Name for the login screen.
  static const String login = 'login';

  /// Path for the login screen.
  static const String loginPath = '/auth/login';

  /// Name for the registration screen.
  static const String register = 'register';

  /// Path for the registration screen.
  static const String registerPath = '/auth/register';

  /// Name for the post-registration profile questionnaire screen.
  static const String profileQuestionnaire = 'profileQuestionnaire';

  /// Path for the profile questionnaire screen.
  static const String profileQuestionnairePath = '/auth/profile-questionnaire';

  // ── Tab 0: Today ─────────────────────────────────────────────────────────

  /// Name for the Today Feed tab root.
  static const String today = 'today';

  /// Path for the Today Feed screen.
  static const String todayPath = '/today';

  /// Name for the Insight Detail screen.
  static const String insightDetail = 'insightDetail';

  /// Path for the Insight Detail screen. Parameter: `:id`
  static const String insightDetailPath = '/today/insight/:id';

  /// Name for the Notification History screen.
  static const String notificationHistory = 'notificationHistory';

  /// Path for the Notification History screen.
  static const String notificationHistoryPath = '/today/notifications';

  /// Name for the Sleep Log full-screen form.
  static const String sleepLog = 'sleepLog';

  /// Path for the Sleep Log screen.
  static const String sleepLogPath = '/today/log/sleep';

  /// Name for the Run Log full-screen form.
  static const String runLog = 'runLog';

  /// Path for the Run Log screen.
  static const String runLogPath = '/today/log/run';

  /// Name for the Meal Log full-screen form.
  static const String mealLog = 'mealLog';

  /// Path for the Meal Log screen.
  static const String mealLogPath = '/today/log/meal';

  /// Name for the Supplements Log full-screen form.
  static const String supplementsLog = 'supplementsLog';

  /// Path for the Supplements Log screen.
  static const String supplementsLogPath = '/today/log/supplements';

  /// Name for the Symptom Log full-screen form.
  static const String symptomLog = 'symptomLog';

  /// Path for the Symptom Log screen.
  static const String symptomLogPath = '/today/log/symptom';

  /// Name for the Metric Picker full-screen sheet (add metrics to Today grid).
  static const String metricPicker = 'metricPicker';

  /// Path for the Metric Picker screen.
  static const String metricPickerPath = '/today/log/metric-picker';

  // ── Tab 1: Data ───────────────────────────────────────────────────────────

  /// Name for the Health Dashboard tab root.
  static const String data = 'data';

  /// Path for the Health Dashboard screen.
  static const String dataPath = '/data';

  /// Name for the Category Detail screen.
  static const String categoryDetail = 'categoryDetail';

  /// Path for the Category Detail screen. Parameter: `:id`
  static const String categoryDetailPath = '/data/category/:id';

  /// Name for the Metric Detail screen.
  static const String metricDetail = 'metricDetail';

  /// Path for the Metric Detail screen. Parameter: `:id`
  static const String metricDetailPath = '/data/metric/:id';

  /// Name for the Score Breakdown screen.
  static const String dataScoreBreakdown = 'data-score-breakdown';

  /// Path for the Score Breakdown screen.
  static const String dataScoreBreakdownPath = '/data/score-breakdown';

  // ── Tab 2: Coach ──────────────────────────────────────────────────────────

  /// Name for the Coach (New Chat) tab root.
  static const String coach = 'coach';

  /// Path for the New Chat screen.
  static const String coachPath = '/coach';

  /// Name for the Chat Thread screen.
  static const String coachThread = 'coachThread';

  /// Path for the Chat Thread screen. Parameter: `:id`
  static const String coachThreadPath = '/coach/thread/:id';

  // ── Tab 3: Progress ───────────────────────────────────────────────────────

  /// Name for the Progress Home tab root.
  static const String progress = 'progress';

  /// Path for the Progress Home screen.
  static const String progressPath = '/progress';

  /// Name for the Goals screen.
  static const String goals = 'goals';

  /// Path for the Goals screen.
  static const String goalsPath = '/progress/goals';

  /// Name for the Goal Detail screen.
  static const String goalDetail = 'goalDetail';

  /// Path for the Goal Detail screen. Parameter: `:id`
  static const String goalDetailPath = '/progress/goals/:id';

  /// Name for the Achievements screen.
  static const String achievements = 'achievements';

  /// Path for the Achievements screen.
  static const String achievementsPath = '/progress/achievements';

  /// Name for the Weekly Report screen.
  static const String weeklyReport = 'weeklyReport';

  /// Path for the Weekly Report screen.
  static const String weeklyReportPath = '/progress/report';

  /// Name for the Journal screen.
  static const String journal = 'journal';

  /// Path for the Journal screen.
  static const String journalPath = '/progress/journal';

  // ── Tab 4: Trends ─────────────────────────────────────────────────────────

  /// Name for the Trends Home tab root.
  static const String trends = 'trends';

  /// Path for the Trends Home screen.
  static const String trendsPath = '/trends';

  /// Name for the Correlations Explorer screen.
  static const String correlations = 'correlations';

  /// Path for the Correlations screen.
  static const String correlationsPath = '/trends/correlations';

  /// Name for the Reports screen.
  static const String reports = 'reports';

  /// Path for the Reports screen.
  static const String reportsPath = '/trends/reports';

  /// Name for the Data Sources screen.
  static const String dataSources = 'dataSources';

  /// Path for the Data Sources screen.
  static const String dataSourcesPath = '/trends/sources';

  // ── Settings (pushed over shell) ─────────────────────────────────────────

  /// Name for the Settings Hub screen (pushed over the shell, not a tab).
  static const String settings = 'settings';

  /// Path for the Settings Hub screen.
  static const String settingsPath = '/settings';

  /// Name for the Account Settings screen.
  static const String settingsAccount = 'settingsAccount';

  /// Path for the Account Settings screen.
  static const String settingsAccountPath = '/settings/account';

  /// Name for the Notification Settings screen.
  static const String settingsNotifications = 'settingsNotifications';

  /// Path for the Notification Settings screen.
  static const String settingsNotificationsPath = '/settings/notifications';

  /// Name for the Appearance Settings screen.
  static const String settingsAppearance = 'settingsAppearance';

  /// Path for the Appearance Settings screen.
  static const String settingsAppearancePath = '/settings/appearance';

  /// Name for the Coach Settings screen.
  static const String settingsCoach = 'settingsCoach';

  /// Path for the Coach Settings screen.
  static const String settingsCoachPath = '/settings/coach';

  /// Name for the Integrations screen.
  static const String settingsIntegrations = 'settingsIntegrations';

  /// Path for the Integrations screen (under Settings).
  static const String settingsIntegrationsPath = '/settings/integrations';

  /// Name for the Privacy & Data screen.
  static const String settingsPrivacy = 'settingsPrivacy';

  /// Path for the Privacy & Data screen.
  static const String settingsPrivacyPath = '/settings/privacy';

  /// Name for the Subscription screen.
  static const String settingsSubscription = 'settingsSubscription';

  /// Path for the Subscription screen.
  static const String settingsSubscriptionPath = '/settings/subscription';

  /// Name for the About screen.
  static const String settingsAbout = 'settingsAbout';

  /// Path for the About screen.
  static const String settingsAboutPath = '/settings/about';

  /// Name for the Privacy Policy screen.
  static const String settingsPrivacyPolicy = 'settingsPrivacyPolicy';

  /// Path for the Privacy Policy screen.
  static const String settingsPrivacyPolicyPath = '/settings/privacy-policy';

  /// Name for the Terms of Service screen.
  static const String settingsTerms = 'settingsTerms';

  /// Path for the Terms of Service screen.
  static const String settingsTermsPath = '/settings/terms';

  // ── Profile (pushed over shell) ───────────────────────────────────────────

  /// Name for the Profile screen (pushed over the shell, not a tab).
  static const String profile = 'profile';

  /// Path for the Profile screen.
  static const String profilePath = '/profile';

  /// Name for the Emergency Health Card screen.
  static const String emergencyCard = 'emergencyCard';

  /// Path for the Emergency Health Card screen.
  static const String emergencyCardPath = '/profile/emergency-card';

  /// Name for the Emergency Health Card edit screen.
  static const String emergencyCardEdit = 'emergencyCardEdit';

  /// Path for the Emergency Health Card edit screen.
  static const String emergencyCardEditPath = '/profile/emergency-card/edit';

  // ── Account (under Settings) ─────────────────────────────────────────────

  /// Name for the Edit Profile screen.
  static const String editProfile = 'editProfile';

  /// Path for the Edit Profile screen.
  static const String editProfilePath = '/settings/account/edit-profile';

  // ── Developer Tools ───────────────────────────────────────────────────────

  /// Name for the design system visual catalog (dev only).
  static const String debugCatalog = 'debugCatalog';

  /// Path for the design system catalog screen.
  static const String debugCatalogPath = '/debug/catalog';

  // ── Unauthenticated Route Set ─────────────────────────────────────────────

  /// Set of paths that are accessible without authentication.
  ///
  /// Used by the auth guard to determine whether to redirect to [welcomePath].
  ///
  /// Note: [settingsPath] and [debugCatalogPath] are intentionally excluded —
  /// both require the user to be authenticated before they can be accessed.
  static const Set<String> publicPaths = {
    welcomePath,
    onboardingPath,
    loginPath,
    registerPath,
    profileQuestionnairePath,
  };
}
