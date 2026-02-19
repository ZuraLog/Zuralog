# Phase 2.4.1: E2E Flow Tests

**Parent Goal:** Phase 2.4 End-to-End Verification
**Checklist:**
- [x] 2.4.1 E2E Flow Tests
- [ ] 2.4.2 Final Exit Criteria

---

## What
Automated "Black Box" tests that run on a Simulator/Device and interact with the app like a real user.

## Why
Manual testing is slow and prone to error. We need to guarantee the "Critical Paths" (Login, Chat, Sync) work before every release.

## How
Use `integration_test` package (part of Flutter SDK).

## Features
- **Login Flow:** Enter creds -> Tap Login -> Verify Dashboard appears.
- **Chat Flow:** Enter message -> Tap Send -> Verify message appears in list.
- **Settings Flow:** Tap Settings -> Tap Logout -> Verify Welcome screen appears.

## Files
- Create: `life_logger/integration_test/app_test.dart`

## Steps

1. **Create Test File (`life_logger/integration_test/app_test.dart`)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_logger/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('login and chat flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Login
      await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(Key('password_field')), 'password');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // 2. Verify Dashboard
      expect(find.text('Dashboard'), findsOneWidget);

      // 3. Go to Chat
      await tester.tap(find.byIcon(Icons.chat));
      await tester.pumpAndSettle();
      
      // 4. Send Message
      await tester.enterText(find.byType(TextField), 'Hello AI');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Hello AI'), findsOneWidget);
    });
  });
}
```

## Exit Criteria
- Tests pass on iOS Simulator.
- Tests pass on Android Emulator.
