// zuralog/test/features/coach/presentation/widgets/coach_artifact_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_artifact_card.dart';

void main() {
  testWidgets('ArtifactType.memory renders Memory saved label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachArtifactCard(
            type: ArtifactType.memory,
            description: 'You prefer morning workouts',
          ),
        ),
      ),
    );
    expect(find.text('Memory saved'), findsOneWidget);
    expect(find.text('You prefer morning workouts'), findsOneWidget);
  });

  testWidgets('ArtifactType.journal renders Journal entry logged label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachArtifactCard(
            type: ArtifactType.journal,
            description: 'Logged your sleep journal',
          ),
        ),
      ),
    );
    expect(find.text('Journal entry logged'), findsOneWidget);
  });

  testWidgets('ArtifactType.dataCheck renders Health data checked label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachArtifactCard(
            type: ArtifactType.dataCheck,
            description: 'Checked your step count',
          ),
        ),
      ),
    );
    expect(find.text('Health data checked'), findsOneWidget);
  });

  test('artifactTypeFromContent detects journal keyword', () {
    expect(artifactTypeFromContent('journal entry saved'), ArtifactType.journal);
  });

  test('artifactTypeFromContent detects data keyword', () {
    expect(artifactTypeFromContent('health data checked'), ArtifactType.dataCheck);
  });

  test('artifactTypeFromContent falls back to memory', () {
    expect(artifactTypeFromContent('something random'), ArtifactType.memory);
  });
}
