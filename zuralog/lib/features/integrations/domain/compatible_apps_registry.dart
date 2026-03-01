/// Zuralog — Compatible Apps Registry.
///
/// Provides a static, compile-time list of [CompatibleApp] entries
/// representing third-party health/fitness apps that sync data indirectly
/// into Zuralog through Apple HealthKit and/or Google Health Connect.
///
/// This registry is the single source of truth for the "Compatible Apps"
/// section in the Integrations Hub. No network call is required — the list
/// is embedded at compile time and sorted alphabetically by app name.
library;

import 'package:zuralog/features/integrations/domain/compatible_app.dart';

/// Static registry of compatible third-party health/fitness apps.
///
/// All apps are sorted alphabetically by [CompatibleApp.name].
///
/// Usage:
/// ```dart
/// final allApps = CompatibleAppsRegistry.apps;
/// final iosApps = CompatibleAppsRegistry.healthKitApps;
/// final results = CompatibleAppsRegistry.searchApps('nike');
/// ```
abstract final class CompatibleAppsRegistry {
  /// The full list of 45 compatible apps, sorted alphabetically by name.
  static const List<CompatibleApp> apps = <CompatibleApp>[
    CompatibleApp(
      id: 'adidas_running',
      name: 'Adidas Running',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF000000,
      simpleIconSlug: 'adidas',
      description: 'Track runs and training plans.',
      dataFlowExplanation:
          'Adidas Running syncs workout data to Apple Health and Google Health Connect. Zuralog reads this data automatically from your health store.',
    ),
    CompatibleApp(
      id: 'alltrails',
      name: 'AllTrails',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF428813,
      simpleIconSlug: 'alltrails',
      description: 'Hiking and trail running routes.',
      dataFlowExplanation:
          'AllTrails records hiking and trail activities which sync to Apple Health and Health Connect. Zuralog picks up these workouts automatically.',
    ),
    CompatibleApp(
      id: 'amazfit',
      name: 'Amazfit (Zepp)',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF212121,
      description: 'Smartwatch health and fitness data.',
      dataFlowExplanation:
          'Amazfit (Zepp) syncs steps, sleep, and heart rate data to Apple Health or Health Connect. Zuralog reads this data from your health store.',
    ),
    CompatibleApp(
      id: 'apple_watch_workouts',
      name: 'Apple Watch Workouts',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF000000,
      description: 'Native Apple Watch workout data.',
      dataFlowExplanation:
          'All Apple Watch workouts are automatically written to HealthKit. Zuralog reads them directly — no extra setup needed.',
    ),
    CompatibleApp(
      id: 'blood_pressure_companion',
      name: 'Blood Pressure Companion',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFFE53935,
      description: 'Blood pressure tracking and trends.',
      dataFlowExplanation:
          'Blood Pressure Companion writes readings to Apple HealthKit. Zuralog imports them automatically for a complete health picture.',
    ),
    CompatibleApp(
      id: 'cal_ai',
      name: 'Cal AI',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF4CAF50,
      description: 'AI-powered nutrition scanning.',
      dataFlowExplanation:
          'Cal AI writes nutrition data (calories, macros) to Apple Health or Health Connect. Zuralog reads these entries automatically — just scan your food in Cal AI and the data flows through.',
      deepLinkUrl: 'calai://camera',
    ),
    CompatibleApp(
      id: 'calm',
      name: 'Calm',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF5B92E5,
      description: 'Meditation and mindfulness sessions.',
      dataFlowExplanation:
          'Calm syncs mindful minutes to Apple HealthKit. Zuralog reads this data to track your meditation habit alongside other health metrics.',
    ),
    CompatibleApp(
      id: 'carb_manager',
      name: 'Carb Manager',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF4CAF50,
      description: 'Keto and low-carb diet tracker.',
      dataFlowExplanation:
          'Carb Manager syncs nutrition data to Apple Health and Health Connect. Zuralog reads calorie and macro data from your health store.',
    ),
    CompatibleApp(
      id: 'clue',
      name: 'Clue Period Tracker',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF44CCCC,
      description: 'Period and cycle tracking.',
      dataFlowExplanation:
          'Clue syncs menstrual cycle data to Apple Health and Health Connect. Zuralog can read this data for a holistic health view.',
    ),
    CompatibleApp(
      id: 'coros',
      name: 'COROS',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFE8490F,
      description: 'GPS sport watch data and training.',
      dataFlowExplanation:
          'COROS syncs workouts, heart rate, and training load to Apple Health and Health Connect. Zuralog automatically imports this data.',
    ),
    CompatibleApp(
      id: 'cronometer',
      name: 'Cronometer',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFFF6D00,
      description: 'Detailed nutrition and micronutrient tracking.',
      dataFlowExplanation:
          'Cronometer syncs nutrition data (calories, vitamins, minerals) to Apple Health and Health Connect. Zuralog reads this for comprehensive nutrition tracking.',
    ),
    CompatibleApp(
      id: 'eight_sleep',
      name: 'Eight Sleep',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF2D2D2D,
      simpleIconSlug: 'eightsleep',
      description: 'Smart mattress sleep tracking.',
      dataFlowExplanation:
          'Eight Sleep syncs sleep stages and temperature data to Apple HealthKit. Zuralog reads this for detailed sleep analysis.',
    ),
    CompatibleApp(
      id: 'fitbit',
      name: 'Fitbit',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF00B0B9,
      simpleIconSlug: 'fitbit',
      description: 'Activity, sleep, and heart rate from Fitbit.',
      dataFlowExplanation:
          'Fitbit syncs steps, heart rate, sleep, and workouts to Health Connect (Android). On iOS, third-party sync tools can bridge Fitbit data to HealthKit. Zuralog reads from both stores.',
    ),
    CompatibleApp(
      id: 'fitbod',
      name: 'Fitbod',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF00BFA5,
      description: 'AI-powered strength training plans.',
      dataFlowExplanation:
          'Fitbod writes workout data to Apple Health and Health Connect. Zuralog automatically imports your strength training sessions.',
    ),
    CompatibleApp(
      id: 'flo',
      name: 'Flo Period Tracker',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFFF4081,
      description: 'Period, fertility, and pregnancy tracking.',
      dataFlowExplanation:
          'Flo syncs menstrual cycle and symptom data to Apple Health and Health Connect. Zuralog can read this data for holistic health insights.',
    ),
    CompatibleApp(
      id: 'garmin_connect',
      name: 'Garmin Connect',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF1A73E8,
      simpleIconSlug: 'garmin',
      description: 'Garmin wearable data and analytics.',
      dataFlowExplanation:
          'Garmin Connect syncs workouts, steps, sleep, and body metrics to Apple Health and Health Connect. Zuralog reads all of this automatically.',
    ),
    CompatibleApp(
      id: 'glucose_buddy',
      name: 'Glucose Buddy',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF26A69A,
      description: 'Diabetes and blood glucose logging.',
      dataFlowExplanation:
          'Glucose Buddy syncs blood glucose readings to Apple HealthKit. Zuralog imports these automatically for metabolic health tracking.',
    ),
    CompatibleApp(
      id: 'headspace',
      name: 'Headspace',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFF47D31,
      simpleIconSlug: 'headspace',
      description: 'Meditation and sleep sounds.',
      dataFlowExplanation:
          'Headspace syncs mindful minutes to Apple Health and Health Connect. Zuralog tracks your meditation habit automatically.',
    ),
    CompatibleApp(
      id: 'health_mate',
      name: 'Withings Health Mate',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF00BCD4,
      description: 'Withings scale, BP, and sleep data.',
      dataFlowExplanation:
          'Withings Health Mate syncs weight, blood pressure, and sleep data to Apple Health and Health Connect. Zuralog reads this automatically.',
    ),
    CompatibleApp(
      id: 'huawei_health',
      name: 'Huawei Health',
      supportsHealthKit: false,
      supportsHealthConnect: true,
      brandColor: 0xFFCF0A2C,
      description: 'Huawei wearable health data.',
      dataFlowExplanation:
          'Huawei Health syncs steps, sleep, and heart rate to Google Health Connect on Android. Zuralog reads this data from Health Connect.',
    ),
    CompatibleApp(
      id: 'jefit',
      name: 'JEFIT',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFFF5722,
      description: 'Workout planner and gym tracker.',
      dataFlowExplanation:
          'JEFIT syncs workout data to Apple Health and Health Connect. Zuralog automatically imports your gym sessions.',
    ),
    CompatibleApp(
      id: 'komoot',
      name: 'Komoot',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF6AA127,
      simpleIconSlug: 'komoot',
      description: 'Outdoor route planning and navigation.',
      dataFlowExplanation:
          'Komoot syncs hiking, cycling, and running activities to Apple Health and Health Connect. Zuralog picks these up automatically.',
    ),
    CompatibleApp(
      id: 'life_fasting',
      name: 'Life Fasting',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF00C853,
      description: 'Intermittent fasting tracker.',
      dataFlowExplanation:
          'Life Fasting syncs fasting data and weight to Apple Health and Health Connect. Zuralog reads this for a complete metabolic picture.',
    ),
    CompatibleApp(
      id: 'lose_it',
      name: 'Lose It!',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFFF9800,
      description: 'Calorie counting and weight loss.',
      dataFlowExplanation:
          'Lose It! syncs nutrition and weight data to Apple Health and Health Connect. Zuralog imports calories and macros automatically.',
    ),
    CompatibleApp(
      id: 'map_my_run',
      name: 'MapMyRun',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFEA1D2C,
      description: 'Running route tracking by Under Armour.',
      dataFlowExplanation:
          'MapMyRun syncs run data to Apple Health and Health Connect. Zuralog automatically reads distance, pace, and calories.',
    ),
    CompatibleApp(
      id: 'myfitnesspal',
      name: 'MyFitnessPal',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF0070D1,
      description: 'Nutrition tracking and calorie counter.',
      dataFlowExplanation:
          'MyFitnessPal syncs nutrition data (calories, macros, water) to Apple Health and Health Connect. Zuralog reads this data automatically.',
    ),
    CompatibleApp(
      id: 'nike_run_club',
      name: 'Nike Run Club',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF111111,
      simpleIconSlug: 'nike',
      description: 'Guided runs and training plans.',
      dataFlowExplanation:
          'Nike Run Club syncs running workouts to Apple Health and Health Connect. Zuralog imports distance, pace, and heart rate data automatically.',
    ),
    CompatibleApp(
      id: 'noom',
      name: 'Noom',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFFF6F00,
      description: 'Psychology-based weight loss program.',
      dataFlowExplanation:
          'Noom reads steps and weight from Apple Health and Health Connect. Zuralog also reads this data for a unified dashboard.',
    ),
    // NOTE: Oura Ring is now available as a direct OAuth integration in
    // Zuralog's Direct Integrations section (richer data: readiness scores,
    // HRV, stress, resilience, SpO2, cardiovascular age, VO2 max, and more).
    // This entry remains for users who prefer the indirect HealthKit / Health
    // Connect path, or haven't connected their Oura account directly yet.
    CompatibleApp(
      id: 'oura',
      name: 'Oura Ring',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF514689,
      description: 'Sleep, readiness, and activity tracking.',
      dataFlowExplanation:
          'Oura Ring syncs sleep stages, heart rate, HRV, and activity to Apple Health and Health Connect. Zuralog reads all of this data automatically. For richer data (readiness scores, stress, resilience, VO2 max), connect directly via the Direct Integrations section.',
    ),
    CompatibleApp(
      id: 'peloton',
      name: 'Peloton',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFE6192A,
      description: 'Connected fitness classes and workouts.',
      dataFlowExplanation:
          'Peloton syncs workout data (cycling, running, strength) to Apple Health and Health Connect. Zuralog imports calories, duration, and heart rate automatically.',
    ),
    CompatibleApp(
      id: 'polar',
      name: 'Polar',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFD61F26,
      description: 'Polar watch training and recovery data.',
      dataFlowExplanation:
          'Polar Flow syncs workouts, sleep, and heart rate to Apple Health and Health Connect. Zuralog reads this data from your health store.',
    ),
    CompatibleApp(
      id: 'runkeeper',
      name: 'Runkeeper (ASICS)',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF2DC1E3,
      description: 'GPS running and fitness tracker.',
      dataFlowExplanation:
          'Runkeeper syncs running data to Apple Health and Health Connect. Zuralog automatically imports distance, pace, and calories.',
    ),
    CompatibleApp(
      id: 'samsung_health',
      name: 'Samsung Health',
      supportsHealthKit: false,
      supportsHealthConnect: true,
      brandColor: 0xFF1428A0,
      simpleIconSlug: 'samsung',
      description: 'Samsung wearable and phone health data.',
      dataFlowExplanation:
          'Samsung Health syncs steps, sleep, heart rate, and workouts to Google Health Connect. Zuralog reads this data on Android automatically.',
    ),
    CompatibleApp(
      id: 'sleep_cycle',
      name: 'Sleep Cycle',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF1E88E5,
      description: 'Smart alarm and sleep analysis.',
      dataFlowExplanation:
          'Sleep Cycle syncs sleep data to Apple Health and Health Connect. Zuralog reads sleep duration and quality automatically.',
    ),
    CompatibleApp(
      id: 'strava',
      name: 'Strava',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFFC4C02,
      simpleIconSlug: 'strava',
      description: 'Running and cycling social network.',
      dataFlowExplanation:
          'Strava syncs workouts to Apple Health and Health Connect. Zuralog also has a direct Strava integration for richer data — check the Direct Integrations section above.',
    ),
    CompatibleApp(
      id: 'strong',
      name: 'Strong Workout',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF2196F3,
      description: 'Strength training and gym logging.',
      dataFlowExplanation:
          'Strong syncs workout data to Apple Health and Health Connect. Zuralog automatically imports your strength sessions.',
    ),
    CompatibleApp(
      id: 'suunto',
      name: 'Suunto',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFFE8490F,
      description: 'Suunto watch outdoor sports data.',
      dataFlowExplanation:
          'Suunto syncs outdoor workouts and heart rate to Apple Health and Health Connect. Zuralog reads this data automatically.',
    ),
    CompatibleApp(
      id: 'training_peaks',
      name: 'TrainingPeaks',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF000000,
      description: 'Endurance training plans and analytics.',
      dataFlowExplanation:
          'TrainingPeaks syncs workout data to Apple HealthKit. Zuralog reads training sessions, TSS, and heart rate automatically.',
    ),
    CompatibleApp(
      id: 'wahoo',
      name: 'Wahoo Fitness',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF004B87,
      description: 'Cycling and running sensor data.',
      dataFlowExplanation:
          'Wahoo Fitness syncs workout data to Apple HealthKit. Zuralog imports cycling power, heart rate, and cadence data automatically.',
    ),
    CompatibleApp(
      id: 'water_minder',
      name: 'WaterMinder',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFF29B6F6,
      description: 'Daily water intake tracking.',
      dataFlowExplanation:
          'WaterMinder syncs hydration data to Apple HealthKit. Zuralog reads water intake automatically for your daily health summary.',
    ),
    CompatibleApp(
      id: 'whoop',
      name: 'WHOOP',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF1ED760,
      description: 'Strain, recovery, and sleep metrics.',
      dataFlowExplanation:
          'WHOOP syncs strain, recovery, sleep, and heart rate to Apple Health and Health Connect. Zuralog reads this data automatically from your health store.',
    ),
    CompatibleApp(
      id: 'withings',
      name: 'Withings',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF00BCD4,
      description: 'Smart scales, BP monitors, and sleep trackers.',
      dataFlowExplanation:
          'Withings syncs weight, blood pressure, and sleep data to Apple Health and Health Connect. Zuralog reads this for a complete picture.',
    ),
    CompatibleApp(
      id: 'xiaomi_health',
      name: 'Mi Fitness (Xiaomi)',
      supportsHealthKit: false,
      supportsHealthConnect: true,
      brandColor: 0xFFFF6700,
      description: 'Xiaomi/Redmi wearable health data.',
      dataFlowExplanation:
          'Mi Fitness syncs steps, sleep, and heart rate to Google Health Connect. Zuralog reads this data on Android automatically.',
    ),
    CompatibleApp(
      id: 'zero_fasting',
      name: 'Zero Fasting',
      supportsHealthKit: true,
      supportsHealthConnect: true,
      brandColor: 0xFF1A1A2E,
      description: 'Intermittent fasting and wellness.',
      dataFlowExplanation:
          'Zero syncs fasting data and weight to Apple Health and Health Connect. Zuralog reads this for metabolic health tracking.',
    ),
    CompatibleApp(
      id: 'zwift',
      name: 'Zwift',
      supportsHealthKit: true,
      supportsHealthConnect: false,
      brandColor: 0xFFFC6719,
      description: 'Indoor cycling and running virtual worlds.',
      dataFlowExplanation:
          'Zwift syncs workout data to Apple HealthKit. Zuralog reads cycling power, heart rate, and distance data automatically.',
    ),
  ];

  /// Returns all apps that support Apple HealthKit.
  ///
  /// Returns:
  ///   An unmodifiable list of [CompatibleApp] entries where
  ///   [CompatibleApp.supportsHealthKit] is `true`.
  static List<CompatibleApp> get healthKitApps =>
      List.unmodifiable(apps.where((app) => app.supportsHealthKit));

  /// Returns all apps that support Google Health Connect.
  ///
  /// Returns:
  ///   An unmodifiable list of [CompatibleApp] entries where
  ///   [CompatibleApp.supportsHealthConnect] is `true`.
  static List<CompatibleApp> get healthConnectApps =>
      List.unmodifiable(apps.where((app) => app.supportsHealthConnect));

  /// Filters the app list by name using a case-insensitive substring match.
  ///
  /// Returns all apps when [query] is empty or blank.
  ///
  /// Parameters:
  ///   [query] — The search string to match against [CompatibleApp.name].
  ///
  /// Returns:
  ///   A list of [CompatibleApp] entries whose names contain [query]
  ///   (case-insensitive). Returns the full [apps] list when [query] is empty.
  static List<CompatibleApp> searchApps(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return List.unmodifiable(apps);
    final lower = trimmed.toLowerCase();
    return List.unmodifiable(
      apps.where((app) => app.name.toLowerCase().contains(lower)),
    );
  }
}
