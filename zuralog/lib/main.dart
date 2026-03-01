/// Zuralog Edge Agent — Application Entry Point.
///
/// Initializes Flutter bindings, sets up Firebase, registers
/// the FCM background message handler, and wraps the app in a
/// Riverpod [ProviderScope] for dependency injection.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/app.dart';
import 'package:zuralog/core/monitoring/sentry_riverpod_observer.dart';
import 'package:zuralog/core/network/fcm_service.dart';

/// RevenueCat public API key (dev key by default).
///
/// Override at build time: `flutter run --dart-define=REVENUECAT_API_KEY=key`
const _kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: 'test_gZWuFxwZilsfhakSXGNPoSduuYz',
);

/// Sentry DSN for crash reporting and error monitoring.
///
/// Override at build time: `flutter run --dart-define=SENTRY_DSN=<dsn>`
/// When empty, Sentry is disabled (e.g., local development without a DSN).
const _kSentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

/// PostHog project API key for analytics.
///
/// Injected at build time: `flutter run --dart-define=POSTHOG_API_KEY=phc_...`
/// Reads automatically from cloud-brain/.env via `make run`.
/// When empty, PostHog is not initialized and all analytics calls are no-ops.
const _kPosthogApiKey =
    String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');

/// Application entry point.
///
/// Ensures Flutter bindings are initialized, sets up Firebase,
/// configures RevenueCat anonymously (user identity linked after login),
/// registers the FCM background handler, then runs the app.
/// The [ProviderScope] at the root enables Riverpod state management
/// throughout the entire widget tree.
/// Initializes Firebase and RevenueCat, then runs the app.
///
/// Called after Sentry is initialized so any init failures are captured.
Future<void> _initAndRun() async {
  // Initialize Firebase (required before any Firebase service).
  // Wrapped in try-catch for environments without Firebase config files.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, stackTrace) {
    Sentry.captureException(e, stackTrace: stackTrace);
    debugPrint('Firebase init skipped: $e');
  }

  // Configure RevenueCat early (anonymous session).
  // User identity is linked via Purchases.logIn(userId) after authentication.
  try {
    await Purchases.configure(PurchasesConfiguration(_kRevenueCatApiKey));
    debugPrint('RevenueCat configured (anonymous)');
  } catch (e, stackTrace) {
    Sentry.captureException(e, stackTrace: stackTrace);
    debugPrint('RevenueCat init skipped: $e');
  }

  // Initialize PostHog analytics (Dart-side init — key injected via --dart-define).
  // Key is intentionally not embedded in native platform config files.
  if (_kPosthogApiKey.isNotEmpty) {
    try {
      final config = PostHogConfig(_kPosthogApiKey)
        ..host = 'https://us.i.posthog.com'
        ..captureApplicationLifecycleEvents = true
        ..debug = kDebugMode;
      await Posthog().setup(config);
      debugPrint('PostHog configured');
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('PostHog init skipped: $e');
    }
  }

  runApp(
    ProviderScope(
      observers: [SentryRiverpodObserver()],
      child: const ZuralogApp(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_kSentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = _kSentryDsn;
      options.environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      );
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 0.25;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
      options.sendDefaultPii = false;
      options.enableAutoNativeBreadcrumbs = true;
      options.enableAutoPerformanceTracing = true;
      options.anrEnabled = true;
      options.anrTimeoutInterval = const Duration(seconds: 5);
    }, appRunner: _initAndRun);
  } else {
    await _initAndRun();
  }
}
