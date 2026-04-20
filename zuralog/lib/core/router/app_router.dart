/// Zuralog Edge Agent — GoRouter Configuration.
///
/// Declares [routerProvider] — a Riverpod [Provider<GoRouter>] that creates the
/// [GoRouter] instance ONCE and uses [refreshListenable] to re-trigger the
/// [redirect] callback whenever auth state or first-launch flag changes.
///
/// **3-tab route tree:**
/// ```
/// /today                            → TodayFeedScreen (tab 0)
///   /today/insight/:id              → InsightDetailScreen
///   /today/notifications            → NotificationHistoryScreen
/// /data                             → HealthDashboardScreen (tab 1)
///   /data/category/:id              → CategoryDetailScreen
///   /data/metric/:id                → MetricDetailScreen
///   /data/score-breakdown           → ScoreBreakdownScreen
/// /coach                            → CoachScreen (tab 2)
/// /progress                         → ProgressHomeScreen (pushed over shell)
///   /progress/goals                 → GoalsScreen
///   /progress/goals/:id             → GoalDetailScreen
///   /progress/achievements          → AchievementsScreen
///   /progress/report                → WeeklyReportScreen
///   /progress/journal               → JournalScreen
///   /progress/journal/diary         → JournalDiaryScreen
/// /trends                           → TrendsHomeScreen (pushed over shell)
/// /nutrition                        → NutritionHomeScreen (pushed over shell)
///   /nutrition/meal/:id             → MealDetailScreen
/// /sleep                            → SleepDetailScreen (pushed over shell)
///   /sleep/all-data                 → SleepAllDataScreen
/// /heart                            → HeartDetailScreen (pushed over shell)
///   /heart/all-data                 → HeartAllDataScreen
/// /settings                         → SettingsHubScreen (pushed over shell)
///   /settings/journal               → JournalSettingsScreen
///   /settings/account ... /settings/about  → sub-screens
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
import 'package:zuralog/core/monitoring/sentry_error_boundary.dart';
import 'package:zuralog/core/monitoring/sentry_router_observer.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/auth/presentation/auth/login_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/register_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/forgot_password_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/check_inbox_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/reset_password_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/onboarding_page_view.dart';
import 'package:zuralog/features/onboarding/presentation/onboarding_flow_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/welcome_screen.dart';
import 'package:zuralog/features/dev/component_showcase_screen.dart';
import 'package:zuralog/core/router/auth_guard.dart';
import 'package:zuralog/core/router/route_names.dart';

// ── Tab 0: Today ──────────────────────────────────────────────────────────────
import 'package:zuralog/features/today/presentation/today_feed_screen.dart';
import 'package:zuralog/features/today/presentation/insight_detail_screen.dart';
import 'package:zuralog/features/today/presentation/notification_history_screen.dart';
import 'package:zuralog/features/today/presentation/log_screens/sleep_log_screen.dart';
import 'package:zuralog/features/today/presentation/log_screens/run_log_screen.dart';
import 'package:zuralog/features/today/presentation/log_screens/meal_log_screen.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplements_log_screen.dart';
import 'package:zuralog/features/today/presentation/log_screens/symptom_log_screen.dart';
import 'package:zuralog/features/today/presentation/log_screens/metric_picker_screen.dart';

// ── Sleep Detail (pushed over shell) ─────────────────────────────────────────
import 'package:zuralog/features/sleep/presentation/sleep_detail_screen.dart';
import 'package:zuralog/features/sleep/presentation/all_data/sleep_all_data_screen.dart';

// ── Heart Detail (pushed over shell) ─────────────────────────────────────────
import 'package:zuralog/features/heart/presentation/heart_detail_screen.dart';
import 'package:zuralog/features/heart/presentation/all_data/heart_all_data_screen.dart';

// ── Tab 1: Data ───────────────────────────────────────────────────────────────
import 'package:zuralog/features/data/presentation/health_dashboard_screen.dart';
import 'package:zuralog/features/data/presentation/category_detail_screen.dart' as data_screens;
import 'package:zuralog/features/data/presentation/metric_detail_screen.dart' as data_metric;
import 'package:zuralog/features/data/presentation/score_breakdown_screen.dart' as data_score;

// ── Tab 2: Coach ──────────────────────────────────────────────────────────────
import 'package:zuralog/features/coach/presentation/coach_screen.dart';

// ── Progress (pushed over shell) ──────────────────────────────────────────────
import 'package:zuralog/features/progress/presentation/progress_home_screen.dart';
import 'package:zuralog/features/progress/presentation/goals_screen.dart';
import 'package:zuralog/features/progress/presentation/goal_detail_screen.dart';
import 'package:zuralog/features/progress/presentation/achievements_screen.dart';
import 'package:zuralog/features/progress/presentation/weekly_report_screen.dart';
import 'package:zuralog/features/progress/presentation/journal_screen.dart';
import 'package:zuralog/features/progress/presentation/journal_diary_screen.dart';

// ── Trends (pushed over shell) ────────────────────────────────────────────────
import 'package:zuralog/features/trends/presentation/trends_home_screen.dart';

// ── Nutrition (pushed over shell) ────────────────────────────────────────────
import 'package:zuralog/features/nutrition/presentation/nutrition_home_screen.dart';
import 'package:zuralog/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_rules_screen.dart';
import 'package:zuralog/features/nutrition/presentation/meal_detail_screen.dart';
import 'package:zuralog/features/nutrition/presentation/meal_edit_screen.dart';
import 'package:zuralog/features/nutrition/domain/guided_question.dart';
import 'package:zuralog/features/nutrition/presentation/meal_review_screen.dart';
import 'package:zuralog/features/nutrition/presentation/meal_walkthrough_screen.dart';

// ── Settings (pushed over shell) ──────────────────────────────────────────────
import 'package:zuralog/features/settings/presentation/settings_hub_screen.dart';
import 'package:zuralog/features/settings/presentation/account_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/notification_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/appearance_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/coach_memory_screen.dart';
import 'package:zuralog/features/settings/presentation/coach_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/journal_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/integrations_screen.dart';
import 'package:zuralog/features/settings/presentation/privacy_data_screen.dart';
import 'package:zuralog/features/settings/presentation/subscription_settings_screen.dart';
import 'package:zuralog/features/settings/presentation/about_screen.dart';
import 'package:zuralog/features/settings/presentation/edit_profile_screen.dart';

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
    ref.listen<bool>(profileLoadFailedProvider, (prev, next) => notifyListeners());
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
      SentryRouterObserver(),
      PostHogNavigatorObserver(ref.read(analyticsServiceProvider)),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);
      final location = state.matchedLocation;

      final authRedirect = authGuardRedirect(
        authState: authState,
        location: location,
      );
      if (authRedirect != null) {
        return authRedirect;
      }

      final onboardingAsync = ref.read(hasSeenOnboardingProvider);
      if (location == RouteNames.welcomePath) {
        if (onboardingAsync.isLoading) return null;
        final hasSeen = onboardingAsync.valueOrNull ?? true;
        if (!hasSeen) return RouteNames.onboardingPath;
      }

      if (authState == AuthState.authenticated) {
        final isLoadingProfile = ref.read(isLoadingProfileProvider);
        if (isLoadingProfile) {
          return null;
        }
        final profile = ref.read(userProfileProvider);
        // If onboarding is complete and we're on any pre-app screen
        // (welcome, onboarding pages, questionnaire), redirect to Today.
        final preAppPaths = {
          RouteNames.welcomePath,
          RouteNames.onboardingPath,
          RouteNames.profileQuestionnairePath,
        };
        if (preAppPaths.contains(location) &&
            profile != null &&
            profile.onboardingComplete) {
          return RouteNames.todayPath;
        }
        if (!preAppPaths.contains(location) &&
            (profile == null || !profile.onboardingComplete)) {
          // Don't redirect to the questionnaire if the profile fetch failed
          // (e.g. network error, expired token). Leave the user where they are.
          if (ref.read(profileLoadFailedProvider)) return null;
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
      builder: (context, state) => const SentryErrorBoundary(
        module: 'auth.welcome',
        child: WelcomeScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.onboardingPath,
      name: RouteNames.onboarding,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'auth.onboarding',
        child: OnboardingPageView(),
      ),
    ),
    GoRoute(
      path: RouteNames.loginPath,
      name: RouteNames.login,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'login',
        child: LoginScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.registerPath,
      name: RouteNames.register,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'register',
        child: RegisterScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.forgotPasswordPath,
      name: RouteNames.forgotPassword,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'forgotPassword',
        child: ForgotPasswordScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.checkInboxPath,
      name: RouteNames.checkInbox,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'checkInbox',
        child: CheckInboxScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.resetPasswordPath,
      name: RouteNames.resetPassword,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'resetPassword',
        child: ResetPasswordScreen(),
      ),
    ),
    GoRoute(
      path: RouteNames.profileQuestionnairePath,
      name: RouteNames.profileQuestionnaire,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'auth.profile_questionnaire',
        child: OnboardingFlowScreen(),
      ),
    ),

    // ── Profile (pushed over shell) ───────────────────────────────────────
    GoRoute(
      path: RouteNames.profilePath,
      name: RouteNames.profile,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'profile',
        child: ProfileScreen(),
      ),
      routes: [
        GoRoute(
          path: 'emergency-card',
          name: RouteNames.emergencyCard,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'profile.emergency_card',
            child: EmergencyCardScreen(),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              name: RouteNames.emergencyCardEdit,
              builder: (context, state) => const SentryErrorBoundary(
                module: 'profile.emergency_card_edit',
                child: EmergencyCardEditScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // ── Developer Tools ───────────────────────────────────────────────────
    if (kDebugMode) ...[
      GoRoute(
        path: RouteNames.componentShowcasePath,
        name: RouteNames.componentShowcase,
        builder: (context, state) => const SentryErrorBoundary(
          module: 'dev.components',
          child: ComponentShowcaseScreen(),
        ),
      ),
    ],

    // ── Log Screens (pushed over shell — no bottom nav visible) ──────────
    GoRoute(
      path: RouteNames.sleepLogPath,
      name: RouteNames.sleepLog,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(
          module: 'today.sleep_log',
          child: SleepLogScreen(),
        ),
      ),
    ),
    GoRoute(
      path: RouteNames.runLogPath,
      name: RouteNames.runLog,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(module: 'today.run_log', child: RunLogScreen()),
      ),
    ),
    GoRoute(
      path: RouteNames.mealLogPath,
      name: RouteNames.mealLog,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(module: 'today.meal_log', child: MealLogScreen()),
      ),
    ),
    GoRoute(
      path: RouteNames.supplementsLogPath,
      name: RouteNames.supplementsLog,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(module: 'today.supplements_log', child: SupplementsLogScreen()),
      ),
    ),
    GoRoute(
      path: RouteNames.symptomLogPath,
      name: RouteNames.symptomLog,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(module: 'today.symptom_log', child: SymptomLogScreen()),
      ),
    ),
    GoRoute(
      path: RouteNames.metricPickerPath,
      name: RouteNames.metricPicker,
      pageBuilder: (context, state) {
        final pinnedTypes =
            (state.extra as Set<String>?) ?? const <String>{};
        return MaterialPage(
          child: SentryErrorBoundary(
            module: 'today.metric_picker',
            child: MetricPickerScreen(pinnedTypes: pinnedTypes),
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.sleepPath,
      name: RouteNames.sleep,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(
          module: 'sleep.detail',
          child: SleepDetailScreen(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'all-data',
          name: RouteNames.sleepAllData,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'sleep.all_data',
            child: SleepAllDataScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.heartPath,
      name: RouteNames.heart,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(
          module: 'heart.detail',
          child: HeartDetailScreen(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'all-data',
          name: RouteNames.heartAllData,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'heart.all_data',
            child: HeartAllDataScreen(),
          ),
        ),
      ],
    ),

    // ── Main App Shell — 3-tab StatefulShellRoute ─────────────────────────
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
              builder: (context, state) => const SentryErrorBoundary(
                module: 'today',
                child: TodayFeedScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'insight/:id',
                  name: RouteNames.insightDetail,
                  builder: (context, state) => SentryErrorBoundary(
                    module: 'today.insight_detail',
                    child: InsightDetailScreen(
                      insightId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'notifications',
                  name: RouteNames.notificationHistory,
                  builder: (context, state) => const SentryErrorBoundary(
                    module: 'today.notifications',
                    child: NotificationHistoryScreen(),
                  ),
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
              builder: (context, state) => const SentryErrorBoundary(
                module: 'data',
                child: HealthDashboardScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'category/:id',
                  name: RouteNames.categoryDetail,
                  builder: (context, state) => SentryErrorBoundary(
                    module: 'data.category_detail',
                    child: data_screens.CategoryDetailScreen(
                      categoryId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'metric/:id',
                  name: RouteNames.metricDetail,
                  builder: (context, state) => SentryErrorBoundary(
                    module: 'data.metric_detail',
                    child: data_metric.MetricDetailScreen(
                      metricId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'score-breakdown',
                  name: RouteNames.dataScoreBreakdown,
                  builder: (context, state) => const SentryErrorBoundary(
                    module: 'data.score_breakdown',
                    child: data_score.ScoreBreakdownScreen(),
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
              builder: (context, state) => const SentryErrorBoundary(
                module: 'coach',
                child: CoachScreen(),
              ),
            ),
          ],
        ),

      ],
    ),

    // ── Progress (pushed over shell) ─────────────────────────────────────
    GoRoute(
      path: RouteNames.progressPath,
      name: RouteNames.progress,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'progress',
        child: ProgressHomeScreen(),
      ),
      routes: [
        GoRoute(
          path: 'goals',
          name: RouteNames.goals,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'progress.goals',
            child: GoalsScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              name: RouteNames.goalDetail,
              builder: (context, state) => SentryErrorBoundary(
                module: 'progress.goal_detail',
                child: GoalDetailScreen(
                  goalId: state.pathParameters['id']!,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'achievements',
          name: RouteNames.achievements,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'progress.achievements',
            child: AchievementsScreen(),
          ),
        ),
        GoRoute(
          path: 'report',
          name: RouteNames.weeklyReport,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'progress.weekly_report',
            child: WeeklyReportScreen(),
          ),
        ),
        GoRoute(
          path: 'journal',
          name: RouteNames.journal,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'progress.journal',
            child: JournalScreen(),
          ),
          routes: [
            GoRoute(
              path: 'diary',
              name: RouteNames.journalDiary,
              builder: (context, state) => const SentryErrorBoundary(
                module: 'progress.journal_diary',
                child: JournalDiaryScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // ── Trends (pushed over shell) ───────────────────────────────────────
    GoRoute(
      path: RouteNames.trendsPath,
      name: RouteNames.trends,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'trends',
        child: TrendsHomeScreen(),
      ),
    ),

    // ── Nutrition (pushed over shell) ────────────────────────────────────
    GoRoute(
      path: RouteNames.nutritionPath,
      name: RouteNames.nutrition,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'nutrition',
        child: NutritionHomeScreen(),
      ),
      routes: [
        GoRoute(
          path: 'meal/:id',
          name: RouteNames.nutritionMealDetail,
          builder: (context, state) => SentryErrorBoundary(
            module: 'nutrition.meal_detail',
            child: MealDetailScreen(
              mealId: state.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: 'rules',
          name: RouteNames.nutritionRules,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'nutrition.rules',
            child: NutritionRulesScreen(),
          ),
        ),
        GoRoute(
          path: 'meal-edit',
          name: RouteNames.nutritionMealEdit,
          builder: (context, state) {
            final args = state.extra as MealEditArgs;
            return SentryErrorBoundary(
              module: 'nutrition.meal_edit',
              child: MealEditScreen(args: args),
            );
          },
        ),
        GoRoute(
          path: 'meal-review',
          name: RouteNames.nutritionMealReview,
          builder: (context, state) {
            final args = state.extra as MealReviewArgs;
            return SentryErrorBoundary(
              module: 'nutrition.meal_review',
              child: MealReviewScreen(args: args),
            );
          },
        ),
        GoRoute(
          path: 'meal-walkthrough',
          name: RouteNames.nutritionMealWalkthrough,
          builder: (context, state) {
            final args = state.extra as MealWalkthroughArgs;
            return SentryErrorBoundary(
              module: 'nutrition.meal_walkthrough',
              child: MealWalkthroughScreen(args: args),
            );
          },
        ),
        GoRoute(
          path: 'all-data',
          name: RouteNames.nutritionAllData,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'nutrition.all_data',
            child: NutritionAllDataScreen(),
          ),
        ),
      ],
    ),

    // ── Settings (pushed over shell — full-screen) ────────────────────────
    GoRoute(
      path: RouteNames.settingsPath,
      name: RouteNames.settings,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'settings',
        child: SettingsHubScreen(),
      ),
      routes: [
        GoRoute(
          path: 'account',
          name: RouteNames.settingsAccount,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.account',
            child: AccountSettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'edit-profile',
              name: RouteNames.editProfile,
              builder: (context, state) => const SentryErrorBoundary(
                module: 'settings.account.editProfile',
                child: EditProfileScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'notifications',
          name: RouteNames.settingsNotifications,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.notifications',
            child: NotificationSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'appearance',
          name: RouteNames.settingsAppearance,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.appearance',
            child: AppearanceSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'coach',
          name: RouteNames.settingsCoach,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.coach',
            child: CoachSettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'memory',
              name: RouteNames.settingsCoachMemory,
              builder: (context, state) => const SentryErrorBoundary(
                module: 'settings.coach.memory',
                child: CoachMemoryScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'journal',
          name: RouteNames.settingsJournal,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.journal',
            child: JournalSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'integrations',
          name: RouteNames.settingsIntegrations,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.integrations',
            child: IntegrationsScreen(),
          ),
        ),
        GoRoute(
          path: 'privacy',
          name: RouteNames.settingsPrivacy,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.privacy',
            child: PrivacyDataScreen(),
          ),
        ),
        GoRoute(
          path: 'subscription',
          name: RouteNames.settingsSubscription,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.subscription',
            child: SubscriptionSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'about',
          name: RouteNames.settingsAbout,
          builder: (context, state) => const SentryErrorBoundary(
            module: 'settings.about',
            child: AboutScreen(),
          ),
        ),
      ],
    ),
  ];
}
