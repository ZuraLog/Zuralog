/// Zuralog Edge Agent — Speech Recognition Service.
///
/// Wraps the [SpeechToText] plugin to provide a clean, testable API
/// for on-device speech-to-text. Manages initialization, permissions,
/// listening sessions, and sound level monitoring.
///
/// This is a plain Dart class — not a Riverpod provider. The provider
/// layer ([SpeechNotifier]) consumes this service and exposes reactive state.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:zuralog/core/speech/speech_state.dart';

/// Service that manages on-device speech recognition.
///
/// Wraps [SpeechToText] with a clean state-machine API:
/// - `uninitialized` → (initialize) → `ready` or `unavailable`
/// - `ready` → (startListening) → `listening`
/// - `listening` → (onResult/stop/cancel/timeout) → `ready`
/// - Any state → (error) → `error`
///
/// Usage:
/// ```dart
/// final service = SpeechService();
/// await service.initialize();          // requests permissions
/// service.stateStream.listen(print);   // subscribe to state changes
/// await service.startListening();      // begin a session
/// // ... user speaks ...
/// await service.stopListening();       // end session; keep text
/// final text = service.currentState.recognizedText;
/// ```
class SpeechService {
  /// The underlying speech-to-text plugin instance.
  ///
  /// Exposed as a named parameter for test injection.
  final SpeechToText _speech;

  /// Broadcast stream controller — multiple widgets can listen simultaneously.
  final StreamController<SpeechState> _stateController =
      StreamController<SpeechState>.broadcast();

  /// The current speech recognition state.
  SpeechState _state = const SpeechState();

  /// Creates a [SpeechService].
  ///
  /// [speech] may be injected for testing; production code uses the default.
  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  /// A broadcast stream of [SpeechState] changes.
  ///
  /// New listeners receive future events only (not the last state).
  /// Use [currentState] for the current snapshot.
  Stream<SpeechState> get stateStream => _stateController.stream;

  /// The most recent state snapshot.
  SpeechState get currentState => _state;

  // ── Public API ────────────────────────────────────────────────────────

  /// Initializes the speech recognition engine and requests permissions.
  ///
  /// Must be called once per app session before [startListening].
  /// Subsequent calls to `SpeechToText.initialize` are ignored by the plugin
  /// (safe but idempotent). We track availability via [_state].
  ///
  /// Returns `true` if initialization succeeded and speech is available.
  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
      );

      if (available) {
        _updateState(_state.copyWith(status: SpeechStatus.ready));
      } else {
        _updateState(_state.copyWith(status: SpeechStatus.unavailable));
      }

      return available;
    } catch (e) {
      _updateState(_state.copyWith(
        status: SpeechStatus.error,
        errorMessage: 'Failed to initialize speech recognition: $e',
      ));
      return false;
    }
  }

  /// Starts a speech recognition session.
  ///
  /// No-ops when the service is not initialized or unavailable.
  /// Resets [recognizedText] and [soundLevel] for a fresh session.
  ///
  /// [listenFor] caps the maximum session duration (default 30 s — within
  /// Apple's recommended 1-minute guideline).
  /// [pauseFor] ends the session after this silence duration (default 3 s).
  /// [localeId] selects the recognition language; defaults to device locale.
  Future<void> startListening({
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    String? localeId,
  }) async {
    if (_state.status == SpeechStatus.uninitialized ||
        _state.status == SpeechStatus.unavailable) {
      return;
    }

    // Reset to a clean slate before each session.
    _updateState(_state.copyWith(
      status: SpeechStatus.listening,
      recognizedText: '',
      isFinal: false,
      errorMessage: null,
      soundLevel: 0.0,
    ));

    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _onSoundLevelChange,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: SpeechListenOptions(
        partialResults: true,  // stream partial text while speaking
        cancelOnError: false,  // don't discard text on transient errors
      ),
      localeId: localeId,
    );
  }

  /// Stops the current session and retains the recognized text.
  ///
  /// The final text is available via [currentState.recognizedText].
  Future<void> stopListening() async {
    await _speech.stop();
    _updateState(_state.copyWith(
      status: SpeechStatus.ready,
      isFinal: true,
      soundLevel: 0.0,
    ));
  }

  /// Cancels the current session and discards any recognized text.
  Future<void> cancelListening() async {
    await _speech.cancel();
    _updateState(_state.copyWith(
      status: SpeechStatus.ready,
      recognizedText: '',
      isFinal: false,
      soundLevel: 0.0,
    ));
  }

  /// Releases all resources. Call when the service is no longer needed.
  void dispose() {
    _speech.cancel();
    _stateController.close();
  }

  // ── Private Callbacks ────────────────────────────────────────────────

  /// Called by [SpeechToText] with each recognition result.
  void _onResult(SpeechRecognitionResult result) {
    _updateState(_state.copyWith(
      recognizedText: result.recognizedWords,
      isFinal: result.finalResult,
      // On a final result, move back to ready so the UI can read the text.
      status: result.finalResult ? SpeechStatus.ready : SpeechStatus.listening,
    ));
  }

  /// Called by [SpeechToText] with the current microphone sound level.
  ///
  /// The plugin reports dBFS values, roughly in the range −2 to +10.
  /// We normalize to 0.0–1.0 for the UI (e.g., pulsing mic button).
  void _onSoundLevelChange(double level) {
    // Map [−2, +10] → [0, 1]; clamp to avoid out-of-range values.
    final normalized = (level + 2) / 12;
    final clamped = math.max(0.0, math.min(1.0, normalized));
    _updateState(_state.copyWith(soundLevel: clamped));
  }

  /// Called by [SpeechToText] when the recognition status changes.
  ///
  /// We use this as a safety net for the `done` status only. The primary
  /// state transitions happen via [_onResult] and explicit stop/cancel calls.
  void _onStatus(String status) {
    if (status == 'done' && _state.status == SpeechStatus.listening) {
      _updateState(_state.copyWith(
        status: SpeechStatus.ready,
        isFinal: true,
        soundLevel: 0.0,
      ));
    }
  }

  /// Called by [SpeechToText] when a recognition error occurs.
  void _onError(SpeechRecognitionError error) {
    _updateState(_state.copyWith(
      status: SpeechStatus.error,
      errorMessage: error.errorMsg,
      soundLevel: 0.0,
    ));
  }

  /// Updates the internal state and broadcasts to all listeners.
  void _updateState(SpeechState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
