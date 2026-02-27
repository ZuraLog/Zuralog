import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zuralog/features/integrations/presentation/widgets/platform_badges.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('PlatformBadges', () {
    testWidgets('shows both Apple and Android icons when both true', (tester) async {
      await tester.pumpWidget(wrap(
        const PlatformBadges(supportsHealthKit: true, supportsHealthConnect: true),
      ));
      expect(find.byIcon(FontAwesomeIcons.apple), findsOneWidget);
      expect(find.byIcon(Icons.android_rounded), findsOneWidget);
    });

    testWidgets('shows only Apple icon when HC is false', (tester) async {
      await tester.pumpWidget(wrap(
        const PlatformBadges(supportsHealthKit: true, supportsHealthConnect: false),
      ));
      expect(find.byIcon(FontAwesomeIcons.apple), findsOneWidget);
      expect(find.byIcon(Icons.android_rounded), findsNothing);
    });

    testWidgets('shows only Android icon when HK is false', (tester) async {
      await tester.pumpWidget(wrap(
        const PlatformBadges(supportsHealthKit: false, supportsHealthConnect: true),
      ));
      expect(find.byIcon(FontAwesomeIcons.apple), findsNothing);
      expect(find.byIcon(Icons.android_rounded), findsOneWidget);
    });

    testWidgets('shows nothing when both false', (tester) async {
      await tester.pumpWidget(wrap(
        const PlatformBadges(supportsHealthKit: false, supportsHealthConnect: false),
      ));
      expect(find.byIcon(FontAwesomeIcons.apple), findsNothing);
      expect(find.byIcon(Icons.android_rounded), findsNothing);
    });
  });
}
