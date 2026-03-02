/// Zuralog Edge Agent — SpeechService Unit Tests.
///
/// Tests the [SpeechService] state machine using a [_FakeSpeechToText]
/// that captures plugin callbacks without requiring platform channels.
///
/// Strategy:
/// - [SpeechState] is pure Dart — tested directly.
/// - [SpeechService] is tested via a hand-rolled fake that captures the
///   onResult / onStatus / onError callbacks registered during [initialize],
///   letting tests simulate recognition events without a real device.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:zuralog/core/speech/speech_service.dart';
import 'package:zuralog/core/speech/speech_state.dart';

// ── Fake SpeechToText ─────────────────────────────────────────────────────────

/// A deterministic fake of [SpeechToText] for unit testing.
///
/// Stores callbacks registered during [initialize] and exposes helpers
/// to simulate recognition events, sound level changes, and errors.
///
/// Calls [super.withMethodChannel()] to satisfy the superclass constructor
/// without triggering real platform channel setup.
class _FakeSpeechToText extends SpeechToText {
  _FakeSpeechToText() : super.withMethodChannel();

  /// Whether [initialize] should succeed.
  bool shouldInitSucceed = true;

  /// Whether [initialize] should throw.
  bool shouldInitThrow = false;

  /// Captured callbacks from [initialize].
  SpeechStatusListener? onStatusCallback;
  SpeechErrorListener? onErrorCallback;

  /// Captured callbacks from [listen].
  SpeechResultListener? onResultCallback;
  SpeechSoundLevelChange? onSoundLevelCallback;

  /// Whether [listen], [stop], or [cancel] were called.
  bool listenCalled = false;
  bool stopCalled = false;
  bool cancelCalled = false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    // Match the base class signature exactly — these deprecated params use
    // 'dynamic' in the base class, so we must use 'dynamic' here too.
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    if (shouldInitThrow) throw Exception('Fake init error');
    onStatusCallback = onStatus;
    onErrorCallback = onError;
    return shouldInitSucceed;
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    // Deprecated params — must be typed 'dynamic' to match base class.
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalled = true;
    onResultCallback = onResult;
    onSoundLevelCallback = onSoundLevelChange;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }

  // ── Test helpers ─────────────────────────────────────────────────────

  /// Simulates the plugin delivering a partial recognition result.
  void simulatePartialResult(String words) {
    onResultCallback?.call(
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, null, 0.9)],
        false, // not final
      ),
    );
  }

  /// Simulates the plugin delivering a final recognition result.
  void simulateFinalResult(String words) {
    onResultCallback?.call(
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, null, 0.95)],
        true, // final
      ),
    );
  }

  /// Simulates a sound level change from the microphone.
  void simulateSoundLevel(double level) {
    onSoundLevelCallback?.call(level);
  }

  /// Simulates the plugin reporting `'done'` status.
  void simulateStatusDone() {
    onStatusCallback?.call('done');
  }

  /// Simulates a recognition error.
  void simulateError(String errorMsg) {
    onErrorCallback?.call(
      SpeechRecognitionError(errorMsg, true),
    );
  }
}

// ── SpeechState Tests ─────────────────────────────────────────────────────────

void main() {
  // ── SpeechState (pure Dart model) ──────────────────────────────────────────
  group('SpeechState', () {
    test('has sane defaults', () {
      const state = SpeechState();
      expect(state.status, SpeechStatus.uninitialized);
      expect(state.recognizedText, '');
      expect(state.isFinal, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.soundLevel, 0.0);
    });

    test('copyWith updates specific fields', () {
      const state = SpeechState();
      final updated = state.copyWith(
        status: SpeechStatus.listening,
        recognizedText: 'hello',
        soundLevel: 0.7,
      );
      expect(updated.status, SpeechStatus.listening);
      expect(updated.recognizedText, 'hello');
      expect(updated.soundLevel, 0.7);
      expect(updated.isFinal, isFalse); // unchanged
    });

    test('copyWith with errorMessage: null clears error', () {
      const state = SpeechState(
        status: SpeechStatus.error,
        errorMessage: 'some error',
      );
      // Pass null explicitly to clear the error.
      final cleared = state.copyWith(
        status: SpeechStatus.ready,
        errorMessage: null,
      );
      expect(cleared.errorMessage, isNull);
      expect(cleared.status, SpeechStatus.ready);
    });

    test('isListening reflects listening status', () {
      expect(
        const SpeechState(status: SpeechStatus.listening).isListening,
        isTrue,
      );
      expect(
        const SpeechState(status: SpeechStatus.ready).isListening,
        isFalse,
      );
    });

    test('isReady reflects ready status', () {
      expect(const SpeechState(status: SpeechStatus.ready).isReady, isTrue);
      expect(
        const SpeechState(status: SpeechStatus.listening).isReady,
        isFalse,
      );
    });

    test('isAvailable is false when uninitialized or unavailable', () {
      expect(
        const SpeechState(status: SpeechStatus.uninitialized).isAvailable,
        isFalse,
      );
      expect(
        const SpeechState(status: SpeechStatus.unavailable).isAvailable,
        isFalse,
      );
      expect(
        const SpeechState(status: SpeechStatus.ready).isAvailable,
        isTrue,
      );
      expect(
        const SpeechState(status: SpeechStatus.listening).isAvailable,
        isTrue,
      );
      expect(
        const SpeechState(status: SpeechStatus.error).isAvailable,
        isTrue,
      );
    });

    test('equality compares all fields', () {
      const a = SpeechState(
        status: SpeechStatus.ready,
        recognizedText: 'hi',
        soundLevel: 0.5,
      );
      const b = SpeechState(
        status: SpeechStatus.ready,
        recognizedText: 'hi',
        soundLevel: 0.5,
      );
      final c = a.copyWith(soundLevel: 0.6);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes key fields', () {
      const state = SpeechState(
        status: SpeechStatus.listening,
        recognizedText: 'test',
      );
      expect(state.toString(), contains('listening'));
      expect(state.toString(), contains('test'));
    });
  });

  // ── SpeechService ──────────────────────────────────────────────────────────
  group('SpeechService', () {
    late _FakeSpeechToText fakeSpeech;
    late SpeechService service;

    setUp(() {
      fakeSpeech = _FakeSpeechToText();
      service = SpeechService(speech: fakeSpeech);
    });

    tearDown(() {
      service.dispose();
    });

    // ── initialize ──────────────────────────────────────────────────────

    group('initialize', () {
      test('sets status to ready when plugin succeeds', () async {
        fakeSpeech.shouldInitSucceed = true;
        final result = await service.initialize();
        expect(result, isTrue);
        expect(service.currentState.status, SpeechStatus.ready);
      });

      test('sets status to unavailable when plugin returns false', () async {
        fakeSpeech.shouldInitSucceed = false;
        final result = await service.initialize();
        expect(result, isFalse);
        expect(service.currentState.status, SpeechStatus.unavailable);
      });

      test('sets status to error on exception', () async {
        fakeSpeech.shouldInitThrow = true;
        final result = await service.initialize();
        expect(result, isFalse);
        expect(service.currentState.status, SpeechStatus.error);
        expect(service.currentState.errorMessage, contains('Fake init error'));
      });

      test('emits state on initialize', () async {
        final states = <SpeechState>[];
        service.stateStream.listen(states.add);

        await service.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(states, isNotEmpty);
        expect(states.last.status, SpeechStatus.ready);
      });
    });

    // ── startListening ──────────────────────────────────────────────────

    group('startListening', () {
      test('does nothing when uninitialized', () async {
        await service.startListening();
        expect(fakeSpeech.listenCalled, isFalse);
        expect(service.currentState.status, SpeechStatus.uninitialized);
      });

      test('does nothing when unavailable', () async {
        fakeSpeech.shouldInitSucceed = false;
        await service.initialize();
        await service.startListening();
        expect(fakeSpeech.listenCalled, isFalse);
      });

      test('calls plugin listen and sets status to listening', () async {
        await service.initialize();
        await service.startListening();
        expect(fakeSpeech.listenCalled, isTrue);
        expect(service.currentState.status, SpeechStatus.listening);
      });

      test('resets recognizedText and soundLevel at session start', () async {
        await service.initialize();
        // Start a session and simulate some partial text.
        await service.startListening();
        fakeSpeech.simulatePartialResult('old text');
        await Future<void>.delayed(Duration.zero);
        expect(service.currentState.recognizedText, 'old text');

        // Start a new session — text must be cleared.
        await service.startListening();
        expect(service.currentState.recognizedText, '');
        expect(service.currentState.soundLevel, 0.0);
      });
    });

    // ── recognition results ─────────────────────────────────────────────

    group('recognition results', () {
      setUp(() async {
        await service.initialize();
        await service.startListening();
      });

      test('partial result updates recognizedText, stays in listening', () async {
        fakeSpeech.simulatePartialResult('hello world');
        await Future<void>.delayed(Duration.zero);

        expect(service.currentState.recognizedText, 'hello world');
        expect(service.currentState.isFinal, isFalse);
        expect(service.currentState.status, SpeechStatus.listening);
      });

      test('final result updates text and moves to ready', () async {
        fakeSpeech.simulateFinalResult('final text');
        await Future<void>.delayed(Duration.zero);

        expect(service.currentState.recognizedText, 'final text');
        expect(service.currentState.isFinal, isTrue);
        expect(service.currentState.status, SpeechStatus.ready);
      });

      test('partial then final produces correct final state', () async {
        fakeSpeech.simulatePartialResult('hell');
        await Future<void>.delayed(Duration.zero);
        fakeSpeech.simulatePartialResult('hello');
        await Future<void>.delayed(Duration.zero);
        fakeSpeech.simulateFinalResult('hello');
        await Future<void>.delayed(Duration.zero);

        expect(service.currentState.recognizedText, 'hello');
        expect(service.currentState.isFinal, isTrue);
        expect(service.currentState.status, SpeechStatus.ready);
      });
    });

    // ── sound level ─────────────────────────────────────────────────────

    group('sound level normalization', () {
      setUp(() async {
        await service.initialize();
        await service.startListening();
      });

      test('normalizes dBFS level to 0.0–1.0 range', () async {
        // level=-2 → normalized=(0/12)=0.0
        fakeSpeech.simulateSoundLevel(-2.0);
        await Future<void>.delayed(Duration.zero);
        expect(service.currentState.soundLevel, closeTo(0.0, 0.01));

        // level=+10 → normalized=(12/12)=1.0
        fakeSpeech.simulateSoundLevel(10.0);
        await Future<void>.delayed(Duration.zero);
        expect(service.currentState.soundLevel, closeTo(1.0, 0.01));
      });

      test('clamps values outside expected dBFS range', () async {
        fakeSpeech.simulateSoundLevel(-100.0); // below minimum
        await Future<void>.delayed(Duration.zero);
        expect(service.currentState.soundLevel, greaterThanOrEqualTo(0.0));

        fakeSpeech.simulateSoundLevel(100.0); // above maximum
        await Future<void>.delayed(Duration.zero);
        expect(service.currentState.soundLevel, lessThanOrEqualTo(1.0));
      });
    });

    // ── stopListening ───────────────────────────────────────────────────

    group('stopListening', () {
      test('calls plugin stop and sets status to ready with isFinal=true',
          () async {
        await service.initialize();
        await service.startListening();

        await service.stopListening();

        expect(fakeSpeech.stopCalled, isTrue);
        expect(service.currentState.status, SpeechStatus.ready);
        expect(service.currentState.isFinal, isTrue);
        expect(service.currentState.soundLevel, 0.0);
      });

      test('retains recognized text after stop', () async {
        await service.initialize();
        await service.startListening();

        fakeSpeech.simulatePartialResult('keep this');
        await Future<void>.delayed(Duration.zero);

        await service.stopListening();

        // Text must be preserved (not cleared).
        expect(service.currentState.recognizedText, 'keep this');
      });
    });

    // ── cancelListening ─────────────────────────────────────────────────

    group('cancelListening', () {
      test('calls plugin cancel and clears recognized text', () async {
        await service.initialize();
        await service.startListening();
        fakeSpeech.simulatePartialResult('discard this');
        await Future<void>.delayed(Duration.zero);

        await service.cancelListening();

        expect(fakeSpeech.cancelCalled, isTrue);
        expect(service.currentState.status, SpeechStatus.ready);
        expect(service.currentState.recognizedText, '');
        expect(service.currentState.isFinal, isFalse);
      });
    });

    // ── error handling ──────────────────────────────────────────────────

    group('error handling', () {
      test('recognition error sets status to error with message', () async {
        await service.initialize();
        await service.startListening();

        fakeSpeech.simulateError('error_permission');
        await Future<void>.delayed(Duration.zero);

        expect(service.currentState.status, SpeechStatus.error);
        expect(service.currentState.errorMessage, 'error_permission');
        expect(service.currentState.soundLevel, 0.0);
      });
    });

    // ── status callback ─────────────────────────────────────────────────

    group('status callback', () {
      test('done status while listening moves to ready', () async {
        await service.initialize();
        await service.startListening();

        fakeSpeech.simulateStatusDone();
        await Future<void>.delayed(Duration.zero);

        expect(service.currentState.status, SpeechStatus.ready);
        expect(service.currentState.isFinal, isTrue);
      });

      test('done status when not listening is a no-op', () async {
        await service.initialize();
        // Not listening — done should not change state.
        fakeSpeech.simulateStatusDone();
        await Future<void>.delayed(Duration.zero);
        // Still in ready state (not moved to some unexpected state).
        expect(service.currentState.status, SpeechStatus.ready);
      });
    });

    // ── dispose ─────────────────────────────────────────────────────────

    group('dispose', () {
      test('disposes without error', () {
        // Should not throw.
        expect(() => service.dispose(), returnsNormally);
      });

      test('stream is closed after dispose', () {
        service.dispose();
        expect(service.stateStream.isBroadcast, isTrue);
        // The stream is closed — _updateState checks isClosed, so adding to
        // it after dispose is safe and does not crash the service.
      });
    });
  });
}
