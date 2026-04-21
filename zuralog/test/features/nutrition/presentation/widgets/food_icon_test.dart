import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:zuralog/features/nutrition/presentation/widgets/food_icon.dart';

void main() {
  testWidgets('renders known food glyph', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FoodIcon(foodName: 'egg')),
    ));
    expect(find.byIcon(FontAwesomeIcons.egg), findsOneWidget);
  });

  testWidgets('unknown food falls back to utensils', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FoodIcon(foodName: 'xyzzy')),
    ));
    expect(find.byIcon(FontAwesomeIcons.utensils), findsOneWidget);
  });

  testWidgets('renders without crashing when confidence provided',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FoodIcon(foodName: 'egg', confidence: 0.3)),
    ));
    expect(find.byIcon(FontAwesomeIcons.egg), findsOneWidget);
  });
}
