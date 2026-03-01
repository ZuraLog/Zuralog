/// Zuralog — IntegrationsNotifier Unit Tests.
///
/// Verifies that [IntegrationsNotifier.loadIntegrations] correctly:
///   - Restores persisted connected states from SharedPreferences
///   - Survives app restarts (persisted state across notifier reconstruction)
///   - Preserves connected state across pull-to-refresh
///   - Does NOT call checkPermissions (SharedPreferences is authoritative)
///   - Loads default integrations when no persisted state exists
///   - Does not affect non-health integrations
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/features/health/data/health_repository.dart';
import 'package:zuralog/features/integrations/data/oauth_repository.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// A [SecureStorage] fake.
class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> delete(String key) async => _storage.remove(key);
  @override
  Future<void> saveAuthToken(String token) async => write('auth_token', token);
  @override
  Future<String?> getAuthToken() async => read('auth_token');
  @override
  Future<void> clearAuthToken() async => delete('auth_token');
  @override
  Future<void> saveIntegrationToken(String provider, String token) async =>
      write('integration_$provider', token);
  @override
  Future<String?> getIntegrationToken(String provider) async =>
      read('integration_$provider');
}

/// A [ApiClient] fake.
class _FakeApiClient implements ApiClient {
  @override
  String get baseUrl => 'https://api.test.com';

  @override
  void Function()? get onUnauthenticated => null;

  @override
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async =>
      throw UnimplementedError();
  @override
  Future<Response<dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async =>
      throw UnimplementedError();
  @override
  Future<Response<dynamic>> patch(String path, {Map<String, dynamic>? body}) async =>
      throw UnimplementedError();

  // ignore: unused_element
  static String friendlyError(DioException e) => '';
}

/// A [HealthRepository] fake with configurable return values.
///
/// Implements the concrete [HealthRepository] class to intercept all
/// method calls without hitting the real platform channel.
class _FakeHealthRepository implements HealthRepository {
  bool isAvailableResult = true;
  bool requestAuthorizationResult = true;
  bool checkPermissionsResult = true;

  @override
  Future<bool> isAvailable() async => isAvailableResult;
  @override
  Future<bool> requestAuthorization() async => requestAuthorizationResult;
  @override
  Future<bool> checkPermissions() async => checkPermissionsResult;

  // Unused stubs — required to satisfy the HealthRepository interface.
  @override
  Future<double> getSteps(DateTime date) async => 0;
  @override
  Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime s,
    DateTime e,
  ) async => [];
  @override
  Future<List<Map<String, dynamic>>> getSleep(DateTime s, DateTime e) async =>
      [];
  @override
  Future<double?> getWeight() async => null;
  @override
  Future<double?> getCaloriesBurned(DateTime date) async => null;
  @override
  Future<double?> getNutritionCalories(DateTime date) async => null;
  @override
  Future<double?> getRestingHeartRate() async => null;
  @override
  Future<double?> getHRV() async => null;
  @override
  Future<double?> getCardioFitness() async => null;
  @override
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) async => false;
  @override
  Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) async => false;
  @override
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime date,
  }) async => false;
  @override
  Future<bool> startBackgroundObservers() async => false;
  @override
  Future<bool> configureBackgroundSync({
    required String authToken,
    required String apiBaseUrl,
  }) async => true;

  // Phase 6 stubs — new HealthKit data types.
  @override
  Future<double> getDistance(DateTime date) async => 0;
  @override
  Future<double> getFlights(DateTime date) async => 0;
  @override
  Future<double?> getBodyFat() async => null;
  @override
  Future<double?> getRespiratoryRate() async => null;
  @override
  Future<double?> getOxygenSaturation() async => null;
  @override
  Future<double?> getHeartRate() async => null;
  @override
  Future<Map<String, double>?> getBloodPressure() async => null;
  @override
  Future<bool> triggerSync(String type) async => false;
}

/// A [OAuthRepository] fake.
///
/// Deviation from spec: the actual [OAuthRepository] interface has
/// [handleStravaCallback] (not `exchangeStravaCode`). This fake implements
/// the real method signatures discovered in
/// `zuralog/lib/features/integrations/data/oauth_repository.dart`.
class _FakeOAuthRepository implements OAuthRepository {
  @override
  Future<String?> getStravaAuthUrl() async => null;
  @override
  Future<bool> handleStravaCallback(String code, String userId) async => false;
  @override
  Future<String?> getFitbitAuthUrl() async => null;
  @override
  Future<bool> handleFitbitCallback(
    String code,
    String state,
    String userId,
  ) async =>
      false;
  @override
  Future<String?> getOuraAuthUrl() async => null;
  @override
  Future<bool> handleOuraCallback(String code, String state, String userId) async => false;
  @override
  Future<String?> getWithingsAuthUrl() async => null;
}

// ── Helper ─────────────────────────────────────────────────────────────────────

/// Creates a fresh [IntegrationsNotifier] with fakes.
///
/// All tests disable the constructor's [_loadPersistedStates] side-effect by
/// relying on [SharedPreferences.setMockInitialValues] — any state written to
/// SharedPreferences in tests is isolated per test.
IntegrationsNotifier _makeNotifier({
  _FakeHealthRepository? health,
  _FakeOAuthRepository? oauth,
  _FakeSecureStorage? secureStorage,
  _FakeApiClient? apiClient,
}) {
  return IntegrationsNotifier(
    oauthRepository: oauth ?? _FakeOAuthRepository(),
    healthRepository: health ?? _FakeHealthRepository(),
    secureStorage: secureStorage ?? _FakeSecureStorage(),
    apiClient: apiClient ?? _FakeApiClient(),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntegrationsNotifier — persisted state restoration', () {
    test('loadIntegrations restores google_health_connect as connected '
        'from SharedPreferences', () async {
      // Arrange: HC was connected in a previous session.
      SharedPreferences.setMockInitialValues({
        'integration_connected_google_health_connect': true,
      });
      final notifier = _makeNotifier();

      // Act: simulate first load after constructor.
      await notifier.loadIntegrations();

      // Assert: tile must show as connected.
      final hc = notifier.state.integrations.firstWhere(
        (i) => i.id == 'google_health_connect',
      );
      expect(
        hc.status,
        IntegrationStatus.connected,
        reason: 'Persisted connected flag must be restored on load',
      );
    });

    test('loadIntegrations restores apple_health as connected '
        'from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'integration_connected_apple_health': true,
      });
      final notifier = _makeNotifier();

      await notifier.loadIntegrations();

      final ah = notifier.state.integrations.firstWhere(
        (i) => i.id == 'apple_health',
      );
      expect(ah.status, IntegrationStatus.connected);
    });

    test(
      'pull-to-refresh preserves connected state from SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'integration_connected_google_health_connect': true,
        });
        final notifier = _makeNotifier();

        // First load.
        await notifier.loadIntegrations();
        // Simulate pull-to-refresh.
        await notifier.loadIntegrations();

        final hc = notifier.state.integrations.firstWhere(
          (i) => i.id == 'google_health_connect',
        );
        expect(
          hc.status,
          IntegrationStatus.connected,
          reason: 'Pull-to-refresh must not reset persisted connection',
        );
      },
    );
  });

  group('IntegrationsNotifier — SharedPreferences as authoritative source', () {
    test(
      'checkPermissions returning false does NOT revert persisted connected state',
      () async {
        // SharedPreferences is the authoritative source of truth.
        // checkPermissions() is NOT called during loadIntegrations() because
        // Health Connect's getGrantedPermissions() is unreliable on cold start.
        SharedPreferences.setMockInitialValues({
          'integration_connected_google_health_connect': true,
        });
        // Even though checkPermissions returns false, status must stay connected.
        final health = _FakeHealthRepository()..checkPermissionsResult = false;
        final notifier = _makeNotifier(health: health);

        await notifier.loadIntegrations();

        final hc = notifier.state.integrations.firstWhere(
          (i) => i.id == 'google_health_connect',
        );
        expect(
          hc.status,
          IntegrationStatus.connected,
          reason:
              'SharedPreferences flag is authoritative — checkPermissions() '
              'result must not override it (HC getGrantedPermissions unreliable)',
        );
      },
    );

    test(
      'pull-to-refresh preserves connected state regardless of checkPermissions',
      () async {
        SharedPreferences.setMockInitialValues({
          'integration_connected_google_health_connect': true,
        });
        final health = _FakeHealthRepository()..checkPermissionsResult = false;
        final notifier = _makeNotifier(health: health);

        await notifier.loadIntegrations();
        // Simulate pull-to-refresh.
        await notifier.loadIntegrations();

        final hc = notifier.state.integrations.firstWhere(
          (i) => i.id == 'google_health_connect',
        );
        expect(
          hc.status,
          IntegrationStatus.connected,
          reason:
              'Pull-to-refresh must not reset connected state '
              'even when checkPermissions returns false',
        );
      },
    );
  });

  group('IntegrationsNotifier — defaults', () {
    test('loads all 8 default integrations when no persisted state', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _makeNotifier();

      await notifier.loadIntegrations();

      expect(notifier.state.integrations.length, 8);
      expect(notifier.state.isLoading, isFalse);
    });

    test('non-health integrations keep their default statuses', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _makeNotifier();

      await notifier.loadIntegrations();

      final strava = notifier.state.integrations.firstWhere(
        (i) => i.id == 'strava',
      );
      final garmin = notifier.state.integrations.firstWhere(
        (i) => i.id == 'garmin',
      );

      expect(strava.status, IntegrationStatus.available);
      expect(garmin.status, IntegrationStatus.comingSoon);
    });

    test('isLoading is false after loadIntegrations completes', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _makeNotifier();

      await notifier.loadIntegrations();

      expect(notifier.state.isLoading, isFalse);
    });
  });
}
