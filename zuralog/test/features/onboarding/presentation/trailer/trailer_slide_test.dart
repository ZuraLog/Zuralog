/// Tests for [TrailerSlideView] — one photo, one headline, optional zoom + contour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/onboarding/presentation/trailer/trailer_data.dart';
import 'package:zuralog/features/onboarding/presentation/trailer/trailer_slide.dart';

void main() {
  group('TrailerSlideView', () {
    testWidgets('renders the headline text', (tester) async {
      const slide = TrailerSlide(
        imageAsset: 'assets/welcome/trailer_01.jpg',
        headline: "Know why you're tired.",
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TrailerSlideView(slide: slide, animate: false),
        ),
      ));

      expect(find.text("Know why you're tired."), findsOneWidget);
    });

    testWidgets('does not throw with animate: true on first pump',
        (tester) async {
      const slide = TrailerSlide(
        imageAsset: 'assets/welcome/trailer_01.jpg',
        headline: "Know why you're tired.",
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TrailerSlideView(slide: slide, animate: true),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TrailerSlideView), findsOneWidget);
    });
  });
}
