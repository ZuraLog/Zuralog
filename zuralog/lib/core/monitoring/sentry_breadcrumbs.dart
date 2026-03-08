/// Zuralog — Sentry Breadcrumb Service.
///
/// Centralised helper for adding structured breadcrumbs to Sentry.
/// All breadcrumb emission in the app should go through this class
/// so categories, types, and log levels remain consistent.
///
/// Categories used in this project:
/// - `navigation`  — GoRouter page transitions, tab switches.
/// - `user.action` — Button taps, form submissions, gestures.
/// - `http`        — Outbound API calls to Cloud Brain.
/// - `ai`          — LLM chat sends, responses, tool execution hints.
/// - `health`      — Native health sync events.
/// - `auth`        — Login, logout, token refresh events.
library;

import 'package:sentry_flutter/sentry_flutter.dart';

/// Helper for emitting structured Sentry breadcrumbs throughout the app.
abstract final class SentryBreadcrumbs {
  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Records a GoRouter navigation event.
  ///
  /// Call from the GoRouter [redirect] callback or [NavigatorObserver].
  static Future<void> navigation({
    required String from,
    required String to,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'Navigate $from → $to',
        category: 'navigation',
        type: 'navigation',
        level: SentryLevel.info,
        data: {'from': from, 'to': to},
      ),
    );
  }

  // ── User Actions ───────────────────────────────────────────────────────────

  /// Records a user-initiated action (tap, swipe, form submit, etc.).
  ///
  /// [action] should be a short imperative string, e.g. `'send_message'`.
  /// [screen] is the current route name.
  static Future<void> userAction({
    required String action,
    required String screen,
    Map<String, dynamic>? data,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: action,
        category: 'user.action',
        type: 'user',
        level: SentryLevel.info,
        data: {
          'screen': screen,
          if (data != null) ...data,
        },
      ),
    );
  }

  // ── HTTP / API ─────────────────────────────────────────────────────────────

  /// Records an outbound HTTP request to the Cloud Brain API.
  static Future<void> apiRequest({
    required String method,
    required String path,
    int? statusCode,
    int? durationMs,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: '$method $path',
        category: 'http',
        type: 'http',
        level: statusCode != null && statusCode >= 400
            ? SentryLevel.warning
            : SentryLevel.info,
        data: {
          'method': method,
          'url': path,
          'status_code': ?statusCode,
          'duration_ms': ?durationMs,
        },
      ),
    );
  }

  // ── AI / Chat ──────────────────────────────────────────────────────────────

  /// Records a user sending a message to the AI coach.
  static Future<void> aiMessageSent({
    required int messageLength,
    required String conversationId,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'AI: message sent',
        category: 'ai',
        type: 'info',
        level: SentryLevel.info,
        data: {
          'message_length': messageLength,
          'conversation_id': conversationId,
        },
      ),
    );
  }

  /// Records the AI coach returning a response.
  static Future<void> aiResponseReceived({
    required int responseLength,
    required int latencyMs,
    required String conversationId,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'AI: response received (${latencyMs}ms)',
        category: 'ai',
        type: 'info',
        level: SentryLevel.info,
        data: {
          'response_length': responseLength,
          'latency_ms': latencyMs,
          'conversation_id': conversationId,
        },
      ),
    );
  }

  // ── Health Sync ────────────────────────────────────────────────────────────

  /// Records a native health sync event (start or completion).
  static Future<void> healthSync({
    required String platform,
    required String status,
    int? recordCount,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'Health sync: $platform — $status',
        category: 'health',
        type: 'info',
        level: SentryLevel.info,
        data: {
          'platform': platform,
          'status': status,
          'record_count': ?recordCount,
        },
      ),
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Records an auth lifecycle event (login, logout, token refresh).
  static Future<void> authEvent({
    required String event,
    String? method,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'Auth: $event',
        category: 'auth',
        type: 'user',
        level: SentryLevel.info,
        data: {
          'event': event,
          'method': ?method,
        },
      ),
    );
  }
}
