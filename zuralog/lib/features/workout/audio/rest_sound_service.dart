/// Zuralog — Rest Sound Service.
///
/// Plays a soft chime when rest completes. Currently a stub — audio
/// playback will be wired in once the audio asset is provided.
///
/// TODO: After assets/audio/rest_chime.m4a is bundled:
///   1. Add `audioplayers: ^6.1.0` to pubspec.yaml under dependencies.
///   2. Register `assets/audio/` under `flutter.assets` in pubspec.yaml.
///   3. Replace the no-op `playRestComplete` in [NoopRestSoundService]
///      (or replace the provider with a real implementation) with:
///
///         final player = AudioPlayer();
///         await player.play(AssetSource('audio/rest_chime.m4a'));
///         player.onPlayerComplete.listen((_) => player.dispose());
///
/// The service is invoked only when the rest timer hits T-0 AND the user's
/// "Rest completion sound" preference is enabled (see [workoutPreferencesProvider]).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction over rest-completion audio playback.
///
/// Kept as an interface so the no-op fallback can be swapped for a real
/// implementation without touching call sites.
abstract class RestSoundService {
  /// Plays the soft rest-complete chime. Returns once playback is scheduled
  /// (not once it finishes). Safe to call from the main isolate.
  Future<void> playRestComplete();
}

/// No-op implementation used until the audio asset ships.
///
/// See the TODO at the top of this file for the migration steps.
class NoopRestSoundService implements RestSoundService {
  /// Creates a [NoopRestSoundService].
  const NoopRestSoundService();

  @override
  Future<void> playRestComplete() async {
    // Stub — see TODO at top of file.
  }
}

/// Riverpod provider for the rest sound service.
///
/// Swap the returned instance to enable real audio once the asset is bundled.
final restSoundServiceProvider = Provider<RestSoundService>((ref) {
  return const NoopRestSoundService();
});
