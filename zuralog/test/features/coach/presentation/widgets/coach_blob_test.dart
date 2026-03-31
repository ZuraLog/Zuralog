// zuralog/test/features/coach/presentation/widgets/coach_blob_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';

void main() {
  testWidgets('CoachBlob renders at given size without overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CoachBlob(state: BlobState.idle, size: 80)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final box = tester.renderObject<RenderBox>(find.byType(CoachBlob));
    expect(box.size, const Size(80, 80));
  });

  testWidgets('CoachBlob renders at 28px for conversation size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CoachBlob(state: BlobState.talking, size: 28)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final box = tester.renderObject<RenderBox>(find.byType(CoachBlob));
    expect(box.size, const Size(28, 28));
  });
}
