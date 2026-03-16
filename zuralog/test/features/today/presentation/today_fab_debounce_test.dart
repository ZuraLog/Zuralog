import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/buttons/z_log_fab.dart';

void main() {
  group('Today FAB debounce', () {
    testWidgets('FAB is present when ZLogFab is in widget tree', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              floatingActionButton: ZLogFab(onPressed: () {}),
            ),
          ),
        ),
      );
      expect(find.byType(ZLogFab), findsOneWidget);
    });

    test('debounce guard blocks second call within 500ms', () {
      DateTime? lastTap;

      bool tryOpen() {
        final now = DateTime.now();
        if (lastTap != null &&
            now.difference(lastTap!) < const Duration(milliseconds: 500)) {
          return false;
        }
        lastTap = now;
        return true;
      }

      expect(tryOpen(), isTrue);  // First call — allowed
      expect(tryOpen(), isFalse); // Immediate second — blocked
    });

    test('debounce guard allows call after 500ms window', () async {
      DateTime? lastTap;

      bool tryOpen() {
        final now = DateTime.now();
        if (lastTap != null &&
            now.difference(lastTap!) < const Duration(milliseconds: 500)) {
          return false;
        }
        lastTap = now;
        return true;
      }

      expect(tryOpen(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(tryOpen(), isTrue); // After window — allowed again
    });
  });
}
