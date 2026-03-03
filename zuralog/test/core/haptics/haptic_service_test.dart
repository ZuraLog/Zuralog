import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/haptics/haptic_service.dart';

void main() {
  // Initialize Flutter binding before accessing platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Track calls to the SystemChannels.platform mock.
  final List<String> hapticCalls = [];

  setUp(() {
    hapticCalls.clear();
    // Intercept haptic platform channel messages.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          final type = call.arguments as String?;
          hapticCalls.add(type ?? 'vibrate');
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HapticService — enabled', () {
    late HapticService sut;

    setUp(() => sut = const HapticService(enabled: true));

    test('isEnabled returns true', () {
      expect(sut.isEnabled, isTrue);
    });

    test('light() sends HapticFeedback.lightImpact', () async {
      await sut.light();
      expect(hapticCalls, contains('HapticFeedbackType.lightImpact'));
    });

    test('medium() sends HapticFeedback.mediumImpact', () async {
      await sut.medium();
      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
    });

    test('success() sends HapticFeedback.heavyImpact', () async {
      await sut.success();
      expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
    });

    test('warning() sends HapticFeedback.vibrate', () async {
      await sut.warning();
      expect(hapticCalls, isNotEmpty);
    });

    test('selectionTick() sends HapticFeedback.selectionClick', () async {
      await sut.selectionTick();
      expect(hapticCalls, contains('HapticFeedbackType.selectionClick'));
    });

    test('trigger() dispatches all HapticType values', () async {
      for (final type in HapticType.values) {
        hapticCalls.clear();
        await sut.trigger(type);
        expect(hapticCalls, isNotEmpty,
            reason: 'HapticType.$type should produce a call');
      }
    });
  });

  group('HapticService — disabled', () {
    late HapticService sut;

    setUp(() => sut = const HapticService(enabled: false));

    test('isEnabled returns false', () {
      expect(sut.isEnabled, isFalse);
    });

    test('light() is a no-op', () async {
      await sut.light();
      expect(hapticCalls, isEmpty);
    });

    test('medium() is a no-op', () async {
      await sut.medium();
      expect(hapticCalls, isEmpty);
    });

    test('success() is a no-op', () async {
      await sut.success();
      expect(hapticCalls, isEmpty);
    });

    test('warning() is a no-op', () async {
      await sut.warning();
      expect(hapticCalls, isEmpty);
    });

    test('selectionTick() is a no-op', () async {
      await sut.selectionTick();
      expect(hapticCalls, isEmpty);
    });

    test('trigger() is a no-op for all types', () async {
      for (final type in HapticType.values) {
        await sut.trigger(type);
      }
      expect(hapticCalls, isEmpty);
    });
  });
}
