/// Zuralog — Haptic Feedback barrel export.
///
/// Import this single file to access all haptic feedback types.
///
/// ```dart
/// import 'package:zuralog/core/haptics/haptic.dart';
///
/// // In a ConsumerWidget:
/// final haptics = ref.read(hapticServiceProvider);
/// await haptics.light();
/// ```
library;

export 'haptic_providers.dart';
export 'haptic_service.dart';
