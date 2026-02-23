/// Zuralog Edge Agent — Application Entry Point.
///
/// Initializes Flutter bindings, sets up Firebase, registers
/// the FCM background message handler, and wraps the app in a
/// Riverpod [ProviderScope] for dependency injection.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:zuralog/app.dart';
import 'package:zuralog/core/network/fcm_service.dart';

/// RevenueCat public API key (dev key by default).
///
/// Override at build time: `flutter run --dart-define=REVENUECAT_API_KEY=key`
const _kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: 'test_gZWuFxwZilsfhakSXGNPoSduuYz',
);

/// Application entry point.
///
/// Ensures Flutter bindings are initialized, sets up Firebase,
/// configures RevenueCat anonymously (user identity linked after login),
/// registers the FCM background handler, then runs the app.
/// The [ProviderScope] at the root enables Riverpod state management
/// throughout the entire widget tree.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before any Firebase service).
  // Wrapped in try-catch for environments without Firebase config files.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  // Configure RevenueCat early (anonymous session).
  // User identity is linked via Purchases.logIn(userId) after authentication.
  try {
    await Purchases.configure(PurchasesConfiguration(_kRevenueCatApiKey));
    debugPrint('RevenueCat configured (anonymous)');
  } catch (e) {
    debugPrint('RevenueCat init skipped: $e');
  }

  runApp(const ProviderScope(child: ZuralogApp()));
}
