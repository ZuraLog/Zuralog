import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/buttons/z_pattern_pill_button.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.dark}) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('renders label and icon', (tester) async {
    await tester.pumpWidget(wrap(
      ZPatternPillButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Discuss with Coach',
        onPressed: () {},
      ),
    ));
    expect(find.text('Discuss with Coach'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
  });

  testWidgets('fires onPressed on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(
      ZPatternPillButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Tap me',
        onPressed: () => taps++,
      ),
    ));
    await tester.tap(find.byType(ZPatternPillButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('hosts an animated sage pattern overlay', (tester) async {
    await tester.pumpWidget(wrap(
      ZPatternPillButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Hi',
        onPressed: () {},
      ),
    ));
    final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
    expect(overlay.animate, isTrue);
    expect(overlay.variant, ZPatternVariant.sage);
    expect(overlay.blendMode, BlendMode.multiply);
  });

  testWidgets('exposes a semantic button with the label', (tester) async {
    await tester.pumpWidget(wrap(
      ZPatternPillButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Discuss with Coach',
        onPressed: () {},
      ),
    ));
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(ZPatternPillButton)),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Discuss with Coach',
      ),
    );
    handle.dispose();
  });
}
