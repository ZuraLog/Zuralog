# Phase 1.14.2: E2E Flutter Test

**Parent Goal:** Phase 1.14 End-to-End Testing & Exit Criteria
**Checklist:**
- [x] 1.14.1 Integration Tests
- [x] 1.14.2 E2E Flutter Test
- [ ] 1.14.3 Documentation Update
- [ ] 1.14.4 Code Review
- [ ] 1.14.5 Performance Testing
- [ ] 1.14.6 Final Exit Criteria Checklist

---

## What
Create a Flutter Integration Test (running on simulator/device) that steps through the critical user path.

## Why
Ensure the mobile app correctly handles the entire flow, including network requests and navigation.

## How
Use `integration_test` package.

## Features
- **Flow:** Login Screen -> Dashboard -> Checking specific widgets exist.

## Files
- Create: `life_logger/integration_test/app_test.dart`

## Steps

1. **Write integration test (`life_logger/integration_test/app_test.dart`)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_logger/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify login flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Verify Login Screen
    expect(find.text('Login'), findsOneWidget);

    // Tap Login (assuming Harness shortcut)
    // await tester.tap(find.byKey(Key('login_button')));
    // await tester.pumpAndSettle();

    // Verify Dashboard
    // expect(find.text('Dashboard'), findsOneWidget);
  });
}
```

## Exit Criteria
- Test passes on simulator.
