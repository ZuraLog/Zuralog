enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

enum WeightGoal {
  loseFast,
  loseHalf,
  maintain,
  gainHalf,
  gainFast,
}

abstract final class TdeeCalculator {
  static const _multipliers = {
    ActivityLevel.sedentary: 1.2,
    ActivityLevel.lightlyActive: 1.375,
    ActivityLevel.moderatelyActive: 1.55,
    ActivityLevel.veryActive: 1.725,
    ActivityLevel.extraActive: 1.9,
  };

  static const _goalAdjustments = {
    WeightGoal.loseFast: -500,
    WeightGoal.loseHalf: -250,
    WeightGoal.maintain: 0,
    WeightGoal.gainHalf: 250,
    WeightGoal.gainFast: 500,
  };

  static int calculate({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required bool isMale,
    required ActivityLevel activityLevel,
    required WeightGoal weightGoal,
  }) {
    final bmr =
        10 * weightKg + 6.25 * heightCm - 5 * ageYears + (isMale ? 5 : -161);
    final tdee = bmr * _multipliers[activityLevel]!;
    return (tdee + _goalAdjustments[weightGoal]!).round();
  }
}
