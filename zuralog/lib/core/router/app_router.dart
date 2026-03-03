/// Zuralog Edge Agent — GoRouter Configuration.
///
/// Declares [routerProvider] — a Riverpod [Provider<GoRouter>] that creates the
/// [GoRouter] instance ONCE and uses [refreshListenable] to re-trigger the
/// [redirect] callback whenever auth state or first-launch flag changes.
///
/// **5-tab route tree:**
/// ```
/// /today                            → TodayFeedScreen (tab 0)
///   /today/insight/:id              → InsightDetailScreen
///   /today/notifications            → NotificationHistoryScreen
/// /data                             → HealthDashboardScreen (tab 1)
///   /data/category/:id              → CategoryDetailScreen
///   /data/metric/:id                → MetricDetailScreen
/// /coach                            → NewChatScreen (tab 2)
///   /coach/thread/:id               → ChatThreadScreen
/// /progress                         → ProgressHomeScreen (tab 3)
///   /progress/goals                 → GoalsScreen
///   /progress/goals/:id             → GoalDetailScreen
///   /progress/achievements          → AchievementsScreen
///   /progress/report                → WeeklyReportScreen
///   /progress/journal               → JournalScreen
/// /trends                           → TrendsHomeScreen (tab 4)
///   /trends/correlations            → CorrelationsScreen
///   /trends/reports                 → ReportsScreen
///   /trends/sources                 → DataSourcesScreen
/// /settings                         → SettingsHubScreen (pushed over shell)
///   /settings/account … /settings/about  → sub-screens
/// /profile                          → ProfileScreen (pushed over shell)
///   /profile/emergency-card         → EmergencyCardScreen
///   /profile/emergency-card/edit    → EmergencyCardEditScreen
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/analytics/posthog_navigator_observer.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/auth/presentation/auth/login_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/register_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/onboarding_page_view.dart';
import 'package:zuralog/features/auth/presentation/onboarding/profile_questionnaire_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/welcome_screen.dart';
import 'package:zuralog/features/catalog/catalog_screen.dart';
import 'package:zuralog/core/router/auth_guard.dart';
import 'package:zuralog/core/router/route_names.dart';

// ── Tab 0: Today ──────────────────────────────────────────────────────────────
import 'package:zuralog/features/today/presentation/today_feed_screen.dart';
import 'package:zuralog/features/today/presentation/insight_detail_screen.dart';
import 'package:zuralog/features/today/presentation/notification_history_screen.dart';

// ── Tab 1: Data ───────────────────────────────────────────────────────────────
import 'package:zuralog/features/data/presentation/health_dashboard_screen.dart';
import 'package:zuralog/features/data/presentation/category_detail_screen.dart' as data_screens;
import 'package:zuralog/features/data/presentation/metric_detail_screen.dart' as data_metric;

// ── Tab 2: Coach ──────────────────────────────────────────────────────────────
import 'package:zuralog/features/coach/presentation/new_chat_screen.dart';
import 'package:zuralog/features/coach/presentation/chat_thread_screen.dart';

// ── Tab 3: Progress ───────────────────────────────────────────────────────────
import 'package:zuralog/features/progress/presentation/progress_home_screen.dart';
import 'package:zuralog/features/progress/presentation/goals_screen.dart';
import 'package:zuralog/features/progress/presentation/goal_detail_screen.dart';
import 'package:zuralog/features/progress/presentation/achievements_screen.dart';
import 'package:zuralog/features/progress/presentation/weekly_report_screen.dart';
import 'package:zuralog/features/progress/presentation/journal_screen.dart';

// ── Tab 4: Trends ─────────────────────────────────────────────────────────────
import 'package:zuralog/features/trends/presentation/trends_home_screen.dart';
import 'package:zuralog/features/trends/presentation/correlations_screen.dart';
import 'package:zuralog/features/trends/presentation/reports_screen.dart';
import 'package:zuralog/features/trends/presentation/data_sources_screen.dart';

// ── Settings (pushed over shell) ──────────────────────────────────────────────
import 'package:zuralog/features/settings/presentation/settings_hub_screen.dart';
import 'package:zuralog/features/settings/presentation/account_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/notification_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/appearance_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/coach_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/integrations_screen.dart';
import 'package:zuralog/features/settings/presentation/privacy_data_screen.dart';
import 'package:zuralog/features/settings/presentation/subscription_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/about_screen.dart';

// ── Profile (pushed over shell) ───────────────────────────────────────────────
import 'package:zuralog/features/profile/presentation/profile_screen.dart';
import 'package:zuralog/features/profile/presentation/emergency_card_screen.dart';
import 'package:zuralog/features/profile/presentation/emergency_card_edit_screen.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────
import 'package:zuralog/shared/layout/app_shell.dart';

// ── Auth State → ChangeNotifier Bridge ───────────────────────────────────────

class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (prev, next) => notifyListeners());
    ref.listen<AsyncValue<bool>>(
      hasSeenOnboardingProvider,
      (prev, next) => notifyListeners(),
    );
    ref.listen<UserProfile?>(userProfileProvider, (prev, next) => notifyListeners());
    ref.listen<bool>(isLoadingProfileProvider, (prev, next) => notifyListeners());
  }
}

// ── Router Provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _RouterRefreshListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: RouteNames.welcomePath,
    refreshListenable: listenable,
    debugLogDiagnostics: kDebugMode,
    observers: [
      SentryNavigatorObserver(),
      PostHogNavigatorObserver(ref.read(analyticsServiceProvider)),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);
      final location = state.matchedLocation;

      final authRedirect = authGuardRedirect(
        authState: authState,
        location: location,
      );
      if (authRedirect != null) return authRedirect;

      final onboardingAsync = ref.read(hasSeenOnboardingProvider);
      if (location == RouteNames.welcomePath) {
        if (onboardingAsync.isLoading) return null;
        final hasSeen = onboardingAsync.valueOrNull ?? true;
        if (!hasSeen) return RouteNames.onboardingPath;
      }

      if (authState == AuthState.authenticated &&
          location != RouteNames.profileQuestionnairePath) {
        final isLoadingProfile = ref.read(isLoadingProfileProvider);
        if (isLoadingProfile) return null;
        final profile = ref.read(userProfileProvider);
        if (profile == null || !profile.onboardingComplete) {
          return RouteNames.profileQuestionnairePath;
        }
      }

      return null;
    },
    routes: _buildRoutes(),
  );
});

// ── Route Builder ─────────────────────────────────────────────────────────────

List<RouteBase> _buildRoutes() {
  return [
    // ── Auth & Onboarding ─────────────────────────────────────────────────
    GoRoute(
      path: RouteNames.welcomePath,
      name: RouteNames.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: RouteNames.onboardingPath,
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingPageView(),
    ),
    GoRoute(
      path: RouteNames.loginPath,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.registerPath,
      name: RouteNames.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: RouteNames.profileQuestionnairePath,
      name: RouteNames.profileQuestionnaire,
      builder: (context, state) => const ProfileQuestionnaireScreen(),
    ),

    // ── Settings (pushed over shell — nested sub-routes) ──────────────────
    GoRoute(
      path: RouteNames.settingsPath,
      name: RouteNames.settings,
      builder: (context, state) => const SettingsHubScreen(),
      routes: [
        GoRoute(
          path: 'account',
          name: RouteNames.settingsAccount,
          builder: (context, state) => const AccountSettingsScreen(),
        ),
        GoRoute(
          path: 'notifications',
          name: RouteNames.settingsNotifications,
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
        GoRoute(
          path: 'appearance',
          name: RouteNames.settingsAppearance,
          builder: (context, state) => const AppearanceSettingsScreen(),
        ),
        GoRoute(
          path: 'coach',
          name: RouteNames.settingsCoach,
          builder: (context, state) => const CoachSettingsScreen(),
        ),
        GoRoute(
          path: 'integrations',
          name: RouteNames.settingsIntegrations,
          builder: (context, state) => const IntegrationsScreen(),
        ),
        GoRoute(
          path: 'privacy',
          name: RouteNames.settingsPrivacy,
          builder: (context, state) => const PrivacyDataScreen(),
        ),
        GoRoute(
          path: 'subscription',
          name: RouteNames.settingsSubscription,
          builder: (context, state) => const SubscriptionSettingsScreen(),
        ),
        GoRoute(
          path: 'about',
          name: RouteNames.settingsAbout,
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),

    // ── Profile (pushed over shell) ───────────────────────────────────────
    GoRoute(
      path: RouteNames.profilePath,
      name: RouteNames.profile,
      builder: (context, state) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'emergency-card',
          name: RouteNames.emergencyCard,
          builder: (context, state) => const EmergencyCardScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              name: RouteNames.emergencyCardEdit,
              builder: (context, state) => const EmergencyCardEditScreen(),
            ),
          ],
        ),
      ],
    ),

    // ── Developer Tools ───────────────────────────────────────────────────
    GoRoute(
      path: RouteNames.debugCatalogPath,
      name: RouteNames.debugCatalog,
      builder: (context, state) => const CatalogScreen(),
    ),

    // ── Main App Shell — 5-tab StatefulShellRoute ─────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // ── Tab 0: Today ─────────────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.todayPath,
              name: RouteNames.today,
              builder: (context, state) => const TodayFeedScreen(),
              routes: [
                GoRoute(
                  path: 'insight/:id',
                  name: RouteNames.insightDetail,
                  builder: (context, state) => InsightDetailScreen(
                    insightId: state.pathParameters['id']!,
                  ),
                ),
                GoRoute(
                  path: 'notifications',
                  name: RouteNames.notificationHistory,
                  builder: (context, state) =>
                      const NotificationHistoryScreen(),
                ),
              ],
            ),
          ],
        ),

        // ── Tab 1: Data ───────────────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.dataPath,
              name: RouteNames.data,
              builder: (context, state) => const HealthDashboardScreen(),
              routes: [
                GoRoute(
                  path: 'category/:id',
                  name: RouteNames.categoryDetail,
                  builder: (context, state) =>
                      data_screens.CategoryDetailScreen(
                        categoryId: state.pathParameters['id']!,
                      ),
                ),
                GoRoute(
                  path: 'metric/:id',
                  name: RouteNames.metricDetail,
                  builder: (context, state) => data_metric.MetricDetailScreen(
                    metricId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Tab 2: Coach ──────────────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.coachPath,
              name: RouteNames.coach,
              builder: (context, state) => const NewChatScreen(),
              routes: [
                GoRoute(
                  path: 'thread/:id',
                  name: RouteNames.coachThread,
                  builder: (context, state) => ChatThreadScreen(
                    conversationId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Tab 3: Progress ───────────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.progressPath,
              name: RouteNames.progress,
              builder: (context, state) => const ProgressHomeScreen(),
              routes: [
                GoRoute(
                  path: 'goals',
                  name: RouteNames.goals,
                  builder: (context, state) => const GoalsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      name: RouteNames.goalDetail,
                      builder: (context, state) => GoalDetailScreen(
                        goalId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'achievements',
                  name: RouteNames.achievements,
                  builder: (context, state) => const AchievementsScreen(),
                ),
                GoRoute(
                  path: 'report',
                  name: RouteNames.weeklyReport,
                  builder: (context, state) => const WeeklyReportScreen(),
                ),
                GoRoute(
                  path: 'journal',
                  name: RouteNames.journal,
                  builder: (context, state) => const JournalScreen(),
                ),
              ],
            ),
          ],
        ),

        // ── Tab 4: Trends ─────────────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.trendsPath,
              name: RouteNames.trends,
              builder: (context, state) => const TrendsHomeScreen(),
              routes: [
                GoRoute(
                  path: 'correlations',
                  name: RouteNames.correlations,
                  builder: (context, state) => const CorrelationsScreen(),
                ),
                GoRoute(
                  path: 'reports',
                  name: RouteNames.reports,
                  builder: (context, state) => const ReportsScreen(),
                ),
                GoRoute(
                  path: 'sources',
                  name: RouteNames.dataSources,
                  builder: (context, state) => const DataSourcesScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
