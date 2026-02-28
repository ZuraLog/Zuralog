import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Riverpod [ProviderObserver] that reports provider errors to Sentry.
///
/// Catches errors from any provider in the tree — AsyncNotifier errors,
/// FutureProvider failures, StreamProvider errors, etc.
class SentryRiverpodObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    Sentry.captureException(error, stackTrace: stackTrace);
  }
}
