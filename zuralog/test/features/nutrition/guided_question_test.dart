import 'package:flutter_test/flutter_test.dart';
// `nutrition_models.dart` re-exports `guided_question.dart`, so a single import
// gives us both `OnAnswerOp` / `GuidedQuestion` and `ParsedFoodItem`.
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  group('OnAnswerOp.fromJson', () {
    test('parses add_food correctly', () {
      final json = {
        'op': 'add_food',
        'food': {
          'food_name': 'cooking oil',
          'portion_amount': 1.0,
          'portion_unit': 'tsp',
          'calories': 45.0,
          'protein_g': 0.0,
          'carbs_g': 0.0,
          'fat_g': 5.0,
        },
      };
      final op = OnAnswerOp.fromJson(json);
      expect(op, isA<AddFoodOp>());
      expect((op as AddFoodOp).food.calories, 45.0);
      expect(op.food.foodName, 'cooking oil');
      expect(op.food.fatG, 5.0);
    });

    test('parses replace_food correctly', () {
      final json = {
        'op': 'replace_food',
        'food': {
          'food_name': 'brown rice',
          'portion_amount': 100.0,
          'portion_unit': 'g',
          'calories': 110.0,
          'protein_g': 2.5,
          'carbs_g': 23.0,
          'fat_g': 0.9,
        },
      };
      final op = OnAnswerOp.fromJson(json);
      expect(op, isA<ReplaceFoodOp>());
      expect((op as ReplaceFoodOp).food.foodName, 'brown rice');
    });

    test('clamps scale_food factor above 10.0', () {
      final op = OnAnswerOp.fromJson({'op': 'scale_food', 'factor': 99.0});
      expect(op, isA<ScaleFoodOp>());
      expect((op as ScaleFoodOp).factor, 10.0);
    });

    test('clamps scale_food factor below 0.1', () {
      final op = OnAnswerOp.fromJson({'op': 'scale_food', 'factor': 0.01});
      expect(op, isA<ScaleFoodOp>());
      expect((op as ScaleFoodOp).factor, 0.1);
    });

    test('defaults scale_food factor to 1.0 when missing', () {
      final op = OnAnswerOp.fromJson({'op': 'scale_food'});
      expect(op, isA<ScaleFoodOp>());
      expect((op as ScaleFoodOp).factor, 1.0);
    });

    test('returns NoOpOp singleton for no_op', () {
      final op = OnAnswerOp.fromJson({'op': 'no_op'});
      expect(op, isA<NoOpOp>());
      expect(op, same(NoOpOp.instance));
    });

    test('falls through to NoOpOp on unknown op', () {
      final op = OnAnswerOp.fromJson({'op': 'bogus'});
      expect(op, isA<NoOpOp>());
    });

    test('never throws on malformed add_food missing food field', () {
      final op = OnAnswerOp.fromJson({'op': 'add_food'});
      expect(op, isA<NoOpOp>());
    });

    test('never throws on malformed replace_food with wrong food type', () {
      final op = OnAnswerOp.fromJson({'op': 'replace_food', 'food': 'not a map'});
      expect(op, isA<NoOpOp>());
    });

    test('never throws on empty op map', () {
      final op = OnAnswerOp.fromJson(<String, dynamic>{});
      expect(op, isA<NoOpOp>());
    });

    test('parses needs_followup with reason', () {
      final op = OnAnswerOp.fromJson({
        'op': 'needs_followup',
        'reason': 'oil or butter?',
      });
      expect(op, isA<NeedsFollowupOp>());
      expect((op as NeedsFollowupOp).reason, 'oil or butter?');
    });

    test('parses needs_followup without reason', () {
      final op = OnAnswerOp.fromJson({'op': 'needs_followup'});
      expect(op, isA<NeedsFollowupOp>());
      expect((op as NeedsFollowupOp).reason, isNull);
    });

    test('parses needs_followup with empty-string reason as null', () {
      final op =
          OnAnswerOp.fromJson({'op': 'needs_followup', 'reason': '   '});
      expect(op, isA<NeedsFollowupOp>());
      expect((op as NeedsFollowupOp).reason, isNull);
    });

    test('truncates needs_followup reason at 200 chars', () {
      final longReason = 'x' * 500;
      final op = OnAnswerOp.fromJson({
        'op': 'needs_followup',
        'reason': longReason,
      });
      expect(op, isA<NeedsFollowupOp>());
      expect((op as NeedsFollowupOp).reason, isNotNull);
      expect(op.reason!.length, 200);
    });
  });

  group('OnAnswerFood.toParsedFoodItem', () {
    test('stamps attribution fields on resulting ParsedFoodItem', () {
      const food = OnAnswerFood(
        foodName: 'butter',
        portionAmount: 1.0,
        portionUnit: 'tbsp',
        calories: 100.0,
        proteinG: 0.1,
        carbsG: 0.0,
        fatG: 11.5,
      );
      final pfi = food.toParsedFoodItem(
        sourceQuestionId: 'q-oil',
        sourceAnswerValue: 'yes',
      );
      expect(pfi.origin, 'from_answer');
      expect(pfi.sourceQuestionId, 'q-oil');
      expect(pfi.sourceAnswerValue, 'yes');
      expect(pfi.foodName, 'butter');
      expect(pfi.calories, 100.0);
    });
  });

  group('GuidedQuestion.fromJson', () {
    test('parses onAnswer map with mixed op types', () {
      final json = {
        'id': 'q1',
        'food_index': 0,
        'question': 'Did you use oil or butter?',
        'component_type': 'yes_no',
        'on_answer': {
          'yes': {
            'op': 'add_food',
            'food': {
              'food_name': 'cooking oil',
              'portion_amount': 1.0,
              'portion_unit': 'tsp',
              'calories': 45.0,
              'protein_g': 0.0,
              'carbs_g': 0.0,
              'fat_g': 5.0,
            },
          },
          'no': {'op': 'no_op'},
        },
      };
      final q = GuidedQuestion.fromJson(json);
      expect(q.onAnswer, isNotNull);
      expect(q.onAnswer!['yes'], isA<AddFoodOp>());
      expect(q.onAnswer!['no'], isA<NoOpOp>());
      final addOp = q.onAnswer!['yes']! as AddFoodOp;
      expect(addOp.food.calories, 45.0);
    });

    test('leaves onAnswer null when backend does not send it', () {
      final json = {
        'id': 'q1',
        'food_index': 0,
        'question': 'test',
        'component_type': 'yes_no',
      };
      final q = GuidedQuestion.fromJson(json);
      expect(q.onAnswer, isNull);
    });

    test('skips on_answer entries whose value is not a map', () {
      final json = {
        'id': 'q1',
        'food_index': 0,
        'question': 'test',
        'component_type': 'yes_no',
        'on_answer': {
          'yes': 'not a map',
          'no': {'op': 'no_op'},
        },
      };
      final q = GuidedQuestion.fromJson(json);
      expect(q.onAnswer, isNotNull);
      expect(q.onAnswer!.containsKey('yes'), isFalse);
      expect(q.onAnswer!['no'], isA<NoOpOp>());
    });
  });

  group('ParsedFoodItem attribution fields', () {
    test('fromJson defaults origin to "user" when missing', () {
      final json = {
        'food_name': 'apple',
        'portion_amount': 100.0,
        'portion_unit': 'g',
        'calories': 52.0,
        'protein_g': 0.3,
        'carbs_g': 14.0,
        'fat_g': 0.2,
      };
      final pfi = ParsedFoodItem.fromJson(json);
      expect(pfi.origin, 'user');
      expect(pfi.sourceQuestionId, isNull);
      expect(pfi.sourceAnswerValue, isNull);
    });

    test('fromJson reads origin and source fields when present', () {
      final json = {
        'food_name': 'cooking oil',
        'portion_amount': 1.0,
        'portion_unit': 'tsp',
        'calories': 45.0,
        'protein_g': 0.0,
        'carbs_g': 0.0,
        'fat_g': 5.0,
        'origin': 'from_answer',
        'source_question_id': 'q-oil',
        'source_answer_value': 'yes',
      };
      final pfi = ParsedFoodItem.fromJson(json);
      expect(pfi.origin, 'from_answer');
      expect(pfi.sourceQuestionId, 'q-oil');
      expect(pfi.sourceAnswerValue, 'yes');
    });

    test('toJson round-trips attribution fields', () {
      const pfi = ParsedFoodItem(
        foodName: 'butter',
        portionAmount: 1.0,
        portionUnit: 'tbsp',
        calories: 100.0,
        proteinG: 0.1,
        carbsG: 0.0,
        fatG: 11.5,
        origin: 'from_answer',
        sourceQuestionId: 'q-oil',
        sourceAnswerValue: 'yes',
      );
      final json = pfi.toJson();
      expect(json['origin'], 'from_answer');
      expect(json['source_question_id'], 'q-oil');
      expect(json['source_answer_value'], 'yes');
    });

    test('copyWith replaces only the given fields', () {
      const pfi = ParsedFoodItem(
        foodName: 'rice',
        portionAmount: 100.0,
        portionUnit: 'g',
        calories: 130.0,
        proteinG: 2.7,
        carbsG: 28.0,
        fatG: 0.3,
      );
      final scaled = pfi.copyWith(
        calories: pfi.calories * 2,
        portionAmount: pfi.portionAmount * 2,
      );
      expect(scaled.foodName, 'rice');
      expect(scaled.calories, 260.0);
      expect(scaled.portionAmount, 200.0);
      expect(scaled.proteinG, 2.7);
      expect(scaled.origin, 'user');
    });

    test('copyWith preserves origin when not overridden', () {
      const pfi = ParsedFoodItem(
        foodName: 'oil',
        portionAmount: 1.0,
        portionUnit: 'tsp',
        calories: 45.0,
        proteinG: 0.0,
        carbsG: 0.0,
        fatG: 5.0,
        origin: 'from_answer',
        sourceQuestionId: 'q-oil',
        sourceAnswerValue: 'yes',
      );
      final copy = pfi.copyWith(calories: 90.0);
      expect(copy.origin, 'from_answer');
      expect(copy.sourceQuestionId, 'q-oil');
      expect(copy.sourceAnswerValue, 'yes');
    });
  });
}
