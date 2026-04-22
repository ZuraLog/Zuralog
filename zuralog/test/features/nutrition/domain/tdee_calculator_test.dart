import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/tdee_calculator.dart';

void main() {
  test('TdeeCalculator male 30yo 80kg 175cm sedentary gives ~2099 kcal', () {
    // BMR = 10*80 + 6.25*175 - 5*30 + 5 = 800 + 1093.75 - 150 + 5 = 1748.75
    // TDEE = 1748.75 * 1.2 = 2098.5 → rounds to 2099
    final tdee = TdeeCalculator.calculate(
      weightKg: 80,
      heightCm: 175,
      ageYears: 30,
      isMale: true,
      activityLevel: ActivityLevel.sedentary,
      weightGoal: WeightGoal.maintain,
    );
    expect(tdee, closeTo(2099, 5));
  });

  test('WeightGoal.loseHalf subtracts 250 from TDEE', () {
    final tdee = TdeeCalculator.calculate(
      weightKg: 80,
      heightCm: 175,
      ageYears: 30,
      isMale: true,
      activityLevel: ActivityLevel.sedentary,
      weightGoal: WeightGoal.loseHalf,
    );
    expect(tdee, closeTo(1849, 5));
  });

  test('Female BMR uses -161 offset instead of +5', () {
    // BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
    // TDEE sedentary = 1345.25 * 1.2 = 1614.3
    final tdee = TdeeCalculator.calculate(
      weightKg: 60,
      heightCm: 165,
      ageYears: 25,
      isMale: false,
      activityLevel: ActivityLevel.sedentary,
      weightGoal: WeightGoal.maintain,
    );
    expect(tdee, closeTo(1614, 5));
  });
}
