import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/speech/speech_providers.dart';
import 'package:zuralog/core/speech/speech_service.dart';
import 'package:zuralog/core/speech/speech_state.dart';

// Hand-rolled fake that avoids platform channels.
class _FakeSpeechService extends SpeechService {
  final StreamController<SpeechState> _controller =
      StreamController<SpeechState>.broadcast();

  bool initializeCalled = false;
  bool startListeningCalled = false;
  bool stopListeningCalled = false;
  bool cancelListeningCalled = false;
  bool initializeResult = true;

  @override
  Stream<SpeechState> get stateStream => _controller.stream;

  @override
  SpeechState get currentState => const SpeechState();

  @override
  Future<bool> initialize() async {
    initializeCalled = true;
    return initializeResult;
  }

  @override
  Future<void> startListening({
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    String? localeId,
  }) async {
    startListeningCalled = true;
  }

  @override
  Future<void> stopListening() async {
    stopListeningCalled = true;
  }

  @override
  Future<void> cancelListening() async {
    cancelListeningCalled = true;
  }

  @override
  void dispose() {
    _controller.close();
    // Do NOT call super.dispose() — it would try to cancel the real SpeechToText.
  }

  /// Test helper: push a state into the stream.
  void emit(SpeechState state) => _controller.add(state);
}

void main() {
  late _FakeSpeechService fakeService;

  setUp(() {
    fakeService = _FakeSpeechService();
  });

  tearDown(() {
    fakeService.dispose();
  });

  test('SpeechNotifier initializes service on initialize()', () async {
    final notifier = SpeechNotifier(fakeService);
    final result = await notifier.initialize();

    expect(result, isTrue);
    expect(fakeService.initializeCalled, isTrue);

    notifier.dispose();
  });

  test('SpeechNotifier reflects stream state changes', () async {
    final notifier = SpeechNotifier(fakeService);

    fakeService.emit(const SpeechState(status: SpeechStatus.listening));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.status, SpeechStatus.listening);

    notifier.dispose();
  });

  test('SpeechNotifier delegates startListening to service', () async {
    final notifier = SpeechNotifier(fakeService);
    await notifier.startListening();

    expect(fakeService.startListeningCalled, isTrue);

    notifier.dispose();
  });

  test('SpeechNotifier delegates stopListening to service', () async {
    final notifier = SpeechNotifier(fakeService);
    await notifier.stopListening();

    expect(fakeService.stopListeningCalled, isTrue);

    notifier.dispose();
  });

  test('SpeechNotifier delegates cancelListening to service', () async {
    final notifier = SpeechNotifier(fakeService);
    await notifier.cancelListening();

    expect(fakeService.cancelListeningCalled, isTrue);

    notifier.dispose();
  });

  test('provider creates SpeechNotifier with overridden SpeechService', () {
    final container = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWithValue(fakeService),
      ],
    );

    final state = container.read(speechNotifierProvider);
    expect(state.status, SpeechStatus.uninitialized);

    container.dispose();
  });
}
