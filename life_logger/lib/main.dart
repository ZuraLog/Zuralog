/// Life Logger Edge Agent — Application Entry Point.
///
/// Initializes Flutter bindings, sets up Firebase, registers
/// the FCM background message handler, and wraps the app in a
/// Riverpod [ProviderScope] for dependency injection.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/app.dart';
import 'package:life_logger/core/network/fcm_service.dart';

/// Application entry point.
///
/// Ensures Flutter bindings are initialized, sets up Firebase,
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

  runApp(const ProviderScope(child: LifeLoggerApp()));
}
