/// Plain-English one-line descriptions of every metric id we currently expect
/// from the backend. Unknown ids fall back to a generic caption.
///
/// Used by:
/// - the microscope bottom sheet ("What this means" panel)
/// - the AI summary generator (when it elaborates on a referenced metric)
/// - any future per-metric tooltip
class MetricDescriptions {
  const MetricDescriptions._();

  /// Returns a single-sentence plain-English description of [metricId].
  /// Always returns a string — never null. Unknown ids return a neutral fallback.
  static String lookup(String metricId) {
    switch (metricId) {
      // Sleep
      case 'sleep_duration':
        return 'How long you were actually asleep last night.';
      case 'deep_sleep':
        return 'Time your body spent in deep, restorative sleep.';
      case 'rem_sleep':
        return 'Dream sleep — when your brain consolidates memory.';
      case 'light_sleep':
        return 'Light sleep — the bulk of the night.';
      case 'awake_time':
        return 'Minutes you were awake during the night.';
      case 'sleep_efficiency':
        return 'Percent of time in bed you were actually asleep.';
      case 'bedtime':
        return 'When you fell asleep last night.';
      case 'wake_time':
        return 'When you woke up this morning.';
      case 'sleep_stages':
        return 'Breakdown of deep, REM, light and awake time.';
      // Activity
      case 'steps':
        return 'Total steps you took today.';
      case 'active_calories':
        return 'Calories burned from movement beyond resting metabolism.';
      case 'active_minutes':
      case 'exercise_minutes':
        return 'Minutes you spent in moderate-to-vigorous movement.';
      case 'distance':
        return 'How far you moved today.';
      case 'floors_climbed':
        return 'Floors climbed via stairs or elevation gain.';
      case 'workouts':
        return 'Workouts you logged today.';
      case 'walking_speed':
        return 'Your average walking pace.';
      case 'running_pace':
        return 'Your average running pace.';
      // Heart
      case 'resting_heart_rate':
        return 'Your heart rate at full rest — lower usually means better recovery.';
      case 'hrv':
        return 'Heart rate variability — a key signal for recovery and stress.';
      case 'max_heart_rate':
      case 'avg_heart_rate':
        return 'Your heart rate while you moved today.';
      case 'walking_heart_rate':
        return 'Your average heart rate during steady walking.';
      case 'respiratory_rate':
        return 'Your breathing rate at rest.';
      case 'spo2':
        return 'Blood oxygen saturation — normal is 95–100%.';
      // Nutrition
      case 'calories':
        return 'Total energy you consumed today.';
      case 'protein':
        return 'Grams of protein you ate today.';
      case 'carbs':
        return 'Grams of carbohydrates you ate today.';
      case 'fat':
        return 'Grams of fat you ate today.';
      case 'water':
        return 'Water you drank today.';
      case 'mindful_minutes':
      case 'mindfulness':
      case 'meditation_minutes':
        return 'Time you spent in meditation or focused breathing.';
      // Body
      case 'weight':
        return 'Your latest weight reading.';
      case 'body_fat':
      case 'body_fat_percent':
        return 'Estimated percentage of your weight that is body fat.';
      case 'bmi':
        return 'Body mass index — weight-to-height ratio.';
      case 'body_temperature':
      case 'wrist_temperature':
        return 'Your skin temperature deviation from your baseline.';
      case 'blood_glucose':
        return 'Blood sugar reading — normal fasting is 70–99 mg/dL.';
      case 'blood_pressure':
        return 'Systolic over diastolic blood pressure.';
      case 'vo2_max':
        return 'A fitness measure of how much oxygen your body uses at peak effort.';
      // Wellness
      case 'mood':
        return 'How you rated your mood today.';
      case 'energy':
        return 'How energetic you felt today.';
      case 'stress':
        return 'How stressful today felt — lower is better.';
      default:
        return 'Tracked measurement from your connected sources.';
    }
  }
}
