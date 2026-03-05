/// Zuralog Edge Agent — Speech Recognition Riverpod Providers.
///
/// Exposes [SpeechService] as a reactive Riverpod provider with
/// a [StateNotifier] that bridges the service's stream to the widget tree.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/speech/speech_service.dart';
import 'package:zuralog/core/speech/speech_state.dart';

/// Provides the singleton [SpeechService] instance.
///
/// The service is created once per [ProviderScope] and shared across the app.
/// Disposing the scope (app shutdown) disposes the underlying service.
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  ref.onDispose(service.dispose);
  return service;
});

/// Manages [SpeechState] reactively for the widget tree.
///
/// Listens to [SpeechService.stateStream] and exposes the current
/// speech recognition state. The UI watches this provider to react
/// to listening/recognized text changes.
class SpeechNotifier extends StateNotifier<SpeechState> {
  final SpeechService _service;
  StreamSubscription<SpeechState>? _subscription;

  /// Creates a [SpeechNotifier] bridged to [service].
  ///
  /// Initial state is seeded from [SpeechService.currentState] so that
  /// re-navigation to the chat screen (after the autoDispose notifier was
  /// dropped) picks up the correct initialized/ready state instead of
  /// reverting to [SpeechStatus.uninitialized].
  SpeechNotifier(this._service) : super(_service.currentState) {
    _subscription = _service.stateStream.listen((newState) {
      if (mounted) state = newState;
    });
  }

  /// Initializes the speech engine. Call once (e.g. on first mic tap).
  ///
  /// Returns `true` if speech recognition is available.
  Future<bool> initialize() => _service.initialize();

  /// Starts a listening session.
  Future<void> startListening() => _service.startListening();

  /// Stops listening and keeps the recognized text.
  Future<void> stopListening() => _service.stopListening();

  /// Cancels listening and discards text.
  Future<void> cancelListening() => _service.cancelListening();

  @override
  void dispose() {
    // Stop any active listening session before cancelling the subscription
    // to prevent the underlying mic session from lingering up to 30 seconds.
    if (state.status == SpeechStatus.listening) {
      _service.cancelListening();
    }
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provides reactive [SpeechState] for the chat screen.
///
/// Auto-disposes when the chat screen is removed.
final speechNotifierProvider =
    StateNotifierProvider.autoDispose<SpeechNotifier, SpeechState>((ref) {
  final service = ref.watch(speechServiceProvider);
  return SpeechNotifier(service);
});
