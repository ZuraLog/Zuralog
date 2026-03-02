/// Zuralog Edge Agent — Speech Recognition State.
///
/// Immutable state model for the speech recognition service.
/// Tracks initialization, listening status, and recognized text.
library;

/// The current status of the speech recognition engine.
enum SpeechStatus {
  /// Speech recognition has not been initialized yet.
  uninitialized,

  /// Initialized and ready to listen.
  ready,

  /// Actively listening for speech input.
  listening,

  /// Speech recognition is not available on this device.
  unavailable,

  /// A recoverable error occurred (e.g. permission denied, timeout).
  error,
}

/// Immutable snapshot of the speech recognition state.
class SpeechState {
  /// The current status of the speech recognizer.
  final SpeechStatus status;

  /// The most recent recognized words (partial or final).
  final String recognizedText;

  /// Whether the current result is final (vs. partial/in-progress).
  final bool isFinal;

  /// Error message when [status] is [SpeechStatus.error].
  final String? errorMessage;

  /// The sound level from the microphone (0.0 to 1.0, normalized).
  final double soundLevel;

  const SpeechState({
    this.status = SpeechStatus.uninitialized,
    this.recognizedText = '',
    this.isFinal = false,
    this.errorMessage,
    this.soundLevel = 0.0,
  });

  /// Returns a copy of this state with the specified fields replaced.
  ///
  /// Passing `null` explicitly to [errorMessage] clears the current error.
  SpeechState copyWith({
    SpeechStatus? status,
    String? recognizedText,
    bool? isFinal,
    String? errorMessage,
    double? soundLevel,
  }) {
    return SpeechState(
      status: status ?? this.status,
      recognizedText: recognizedText ?? this.recognizedText,
      isFinal: isFinal ?? this.isFinal,
      // Explicit null clears the error; omitted keeps existing value.
      errorMessage: errorMessage,
      soundLevel: soundLevel ?? this.soundLevel,
    );
  }

  /// Whether the recognizer is actively listening.
  bool get isListening => status == SpeechStatus.listening;

  /// Whether the recognizer is initialized and ready to start a session.
  bool get isReady => status == SpeechStatus.ready;

  /// Whether speech recognition is available (initialized and not unavailable).
  bool get isAvailable =>
      status != SpeechStatus.uninitialized &&
      status != SpeechStatus.unavailable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          recognizedText == other.recognizedText &&
          isFinal == other.isFinal &&
          errorMessage == other.errorMessage &&
          soundLevel == other.soundLevel;

  @override
  int get hashCode => Object.hash(
        status,
        recognizedText,
        isFinal,
        errorMessage,
        soundLevel,
      );

  @override
  String toString() =>
      'SpeechState(status: $status, recognizedText: "$recognizedText", '
      'isFinal: $isFinal, soundLevel: ${soundLevel.toStringAsFixed(2)}, '
      'errorMessage: $errorMessage)';
}
