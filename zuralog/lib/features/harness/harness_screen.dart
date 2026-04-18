/// Zuralog Edge Agent — Developer Test Harness.
///
/// A polished test screen for manually triggering backend
/// functions and viewing real-time logs. Sections are organized
/// by feature with animated transitions and styled controls.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/deeplink/deeplink_handler.dart';
import 'package:zuralog/core/deeplink/deeplink_launcher.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/features/subscription/presentation/paywall_screen.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

// ---------------------------------------------------------------------------
// Design Tokens
// ---------------------------------------------------------------------------

/// Centralized color palette for the harness UI.
class _Colors {
  static const primary = Color(0xFF6C5CE7);
  static const primaryLight = Color(0xFFEDE9FE);
  static const success = Color(0xFF00B894);
  static const successLight = Color(0xFFE6FFF5);
  static const danger = Color(0xFFFF6B6B);
  static const dangerLight = Color(0xFFFFF0F0);
  static const warning = Color(0xFFFFA726);
  // ignore: unused_field
  static const warningLight = Color(0xFFFFF8E1);
  static const info = Color(0xFF0984E3);
  // ignore: unused_field
  static const infoLight = Color(0xFFE8F4FD);
  static const surface = Color(0xFFF8F9FA);
  static const surfaceDark = Color(0xFF2D3436);
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
  static const border = Color(0xFFE0E0E0);
}

// ---------------------------------------------------------------------------
// Harness Screen
// ---------------------------------------------------------------------------

/// The developer test harness screen.
class HarnessScreen extends ConsumerStatefulWidget {
  const HarnessScreen({super.key});

  @override
  ConsumerState<HarnessScreen> createState() => _HarnessScreenState();
}

class _HarnessScreenState extends ConsumerState<HarnessScreen>
    with TickerProviderStateMixin {
  final _outputController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();

  bool _backendOnline = false;

  @override
  void initState() {
    super.initState();
    DeeplinkHandler.init(ref, onLog: _log);
    _checkBackendStatus();
  }

  @override
  void dispose() {
    DeeplinkHandler.dispose();
    _outputController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Logging
  // -----------------------------------------------------------------------

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    // TextEditingController notifies its own listeners — setState is redundant
    // here and would trigger a full rebuild of the ~1900-line widget tree on
    // every log message, causing jank during keyboard animations.
    _outputController.text += '[$timestamp] $message\n';
  }

  // -----------------------------------------------------------------------
  // Backend Connectivity
  // -----------------------------------------------------------------------

  /// Checks if the Cloud Brain backend is reachable.
  ///
  /// Updates [_backendOnline] and logs the result. Called automatically
  /// on startup and can be re-triggered via the Health Check button.
  Future<void> _checkBackendStatus() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.get('/health');
      if (mounted) setState(() => _backendOnline = true);
    } on DioException catch (_) {
      if (mounted) setState(() => _backendOnline = false);
    } catch (_) {
      if (mounted) setState(() => _backendOnline = false);
    }
  }

  // -----------------------------------------------------------------------
  // Backend Actions
  // -----------------------------------------------------------------------

  Future<void> _testHealthCheck() async {
    _log('Testing /health endpoint...');
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/health');
      if (mounted) setState(() => _backendOnline = true);
      _log('✅ Response: ${response.data}');
    } on DioException catch (e) {
      if (mounted) setState(() => _backendOnline = false);
      _log('❌ ${ApiClient.friendlyError(e)}');
    } catch (e) {
      if (mounted) setState(() => _backendOnline = false);
      _log('❌ Unexpected error: $e');
    }
  }

  Future<void> _testSecureStorage() async {
    _log('Testing secure storage...');
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.saveAuthToken('test-token-12345');
      final token = await storage.getAuthToken();
      _log('✅ Stored and retrieved token: $token');
      await storage.clearAuthToken();
      _log('✅ Token cleared');
    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  Future<void> _testLocalDb() async {
    _log('Testing local DB (Drift)...');
    try {
      final db = ref.read(localDbProvider);
      final messages = await db.getAllMessages();
      _log('✅ Messages in DB: ${messages.length}');
    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Auth Actions
  // -----------------------------------------------------------------------

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _log('⚠️ Email and password are required');
      return;
    }
    _log('Attempting login with $email...');
    final authNotifier = ref.read(authStateProvider.notifier);
    final result = await authNotifier.login(email, password);
    switch (result) {
      case AuthSuccess(:final userId):
        _log('✅ LOGIN SUCCESS: User ID = $userId');
        _log('Initializing RevenueCat for user $userId...');
        try {
          await ref.read(subscriptionProvider.notifier).initialize(userId);
          _log('✅ RevenueCat initialized');
        } catch (e) {
          _log('⚠️ RevenueCat init error: $e');
        }
      case AuthFailure(:final message):
        _log('❌ LOGIN FAILED: $message');
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _log('⚠️ Email and password are required');
      return;
    }
    _log('Attempting registration with $email...');
    final authNotifier = ref.read(authStateProvider.notifier);
    final result = await authNotifier.register(email, password);
    switch (result) {
      case AuthSuccess(:final userId):
        _log('✅ REGISTER SUCCESS: User ID = $userId');
      case AuthFailure(:final message):
        _log('❌ REGISTER FAILED: $message');
    }
  }

  Future<void> _handleLogout() async {
    _log('Logging out...');
    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.logout();
    await ref.read(subscriptionProvider.notifier).logOut();
    _log('✅ LOGOUT: Tokens cleared, RevenueCat session ended');
  }

  void _clearOutput() {
    setState(() => _outputController.text = '');
  }

  // -----------------------------------------------------------------------
  // HealthKit Actions
  // -----------------------------------------------------------------------

  Future<void> _testHealthAvailable() async {
    _log('Checking HealthKit availability...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final available = await healthRepo.isAvailable();
    _log(available ? '✅ HealthKit AVAILABLE' : '❌ HealthKit UNAVAILABLE');
  }

  Future<void> _testHealthAuth() async {
    _log('Requesting HealthKit authorization...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final authorized = await healthRepo.requestAuthorization();
    _log(
      authorized ? '✅ HealthKit AUTHORIZED' : '❌ HealthKit DENIED/UNAVAILABLE',
    );
  }

  Future<void> _testReadSteps() async {
    _log('Reading steps for today...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final steps = await healthRepo.getSteps(DateTime.now());
    _log('✅ Steps today: $steps');
  }

  Future<void> _testReadWorkouts() async {
    _log('Reading workouts (last 7 days)...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final workouts = await healthRepo.getWorkouts(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    _log('✅ Workouts: ${workouts.length}');
    for (final w in workouts) {
      _log(
        '  - ${w["activityType"]}: ${w["duration"]}s, ${w["energyBurned"]} kcal',
      );
    }
  }

  Future<void> _testReadSleep() async {
    _log('Reading sleep (last 7 days)...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final sleep = await healthRepo.getSleep(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    _log('✅ Sleep segments: ${sleep.length}');
  }

  Future<void> _testReadWeight() async {
    _log('Reading latest weight...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final weight = await healthRepo.getWeight();
    _log(
      weight != null
          ? '✅ Weight: ${weight.toStringAsFixed(1)} kg'
          : '⚠️ No weight data',
    );
  }

  Future<void> _readNutrition() async {
    _log('Reading nutrition calories (today)...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final kcal = await healthRepo.getNutritionCalories(DateTime.now());
    _log(
      kcal != null && kcal > 0
          ? '✅ Nutrition today: ${kcal.toStringAsFixed(0)} kcal'
          : '⚠️ No nutrition data for today',
    );
  }

  // -----------------------------------------------------------------------
  // CalAI Actions
  // -----------------------------------------------------------------------

  Future<void> _openCalAI() async {
    _log('Opening CalAI for food logging...');
    final opened = await DeepLinkLauncher.openFoodLogging();
    if (opened) {
      _log('✅ CalAI launched (or web fallback opened)');
    } else {
      _log('❌ Could not open CalAI or fallback URL');
    }
  }

  // -----------------------------------------------------------------------
  // AI Brain Actions
  // -----------------------------------------------------------------------

  Future<void> _testAiChat() async {
    _log('Sending test AI message via /api/v1/chat/ws...');
    _log('ℹ️  Use the Coach tab (Tab 2) to send real AI messages.');
    _log('   This endpoint is now tested end-to-end through the Coach UI.');
  }

  // -----------------------------------------------------------------------
  // Background Sync Actions
  // -----------------------------------------------------------------------

  /// Sends a simulated AI write request to the backend.
  ///
  /// Calls the /dev/trigger-write endpoint which sends an FCM
  /// data message to this device, triggering the background handler.
  ///
  /// [dataType] is the health data category (e.g., 'steps', 'nutrition').
  /// [value] is the data payload to write.
  Future<void> _triggerWrite(
    String dataType,
    Map<String, dynamic> value,
  ) async {
    _log('Triggering AI write: $dataType...');
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/api/v1/dev/trigger-write',
            data: {'data_type': dataType, 'value': value},
          );
      _log('Write triggered: ${response.data}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _log(
          '⚠️ No device registered. Tap "Init FCM" first, then retry.',
        );
      } else {
        _log('❌ ${ApiClient.friendlyError(e)}');
      }
    } catch (e) {
      _log('❌ Unexpected error: $e');
    }
  }

  // -----------------------------------------------------------------------
  // FCM Actions
  // -----------------------------------------------------------------------

  /// Initializes Firebase Cloud Messaging and registers this device with
  /// the Cloud Brain backend.
  ///
  /// Requires google-services.json to be present and Firebase configured.
  /// Logs step-by-step progress for developer testing.
  Future<void> _initFcm() async {
    _log('Initializing FCM...');
    try {
      final fcmService = ref.read(fcmServiceProvider);
      final token = await fcmService.initialize();
      if (token == null) {
        _log('❌ FCM permission denied or init failed');
        return;
      }
      _log('✅ FCM token obtained: ${token.substring(0, 20)}...');
      _log('Registering device with backend...');
      final apiClient = ref.read(apiClientProvider);
      final registered = await fcmService.registerWithBackend(apiClient);
      if (registered) {
        _log('✅ Device registered — AI Write buttons are now ready');
      } else {
        _log('❌ Device registration failed — check backend logs');
      }
    } catch (e) {
      _log('❌ FCM init error: $e');
      _log('  → Ensure google-services.json is in android/app/');
      _log('  → Tap the "Firebase Setup" button for instructions');
    }
  }

  // -----------------------------------------------------------------------
  // Strava Actions
  // -----------------------------------------------------------------------

  Future<void> _connectStrava() async {
    _log('Fetching Strava auth URL...');
    final oauthRepo = ref.read(oauthRepositoryProvider);
    final authUrl = await oauthRepo.getStravaAuthUrl();
    if (authUrl == null) {
      _log('❌ Failed to get Strava auth URL — is the backend running?');
      return;
    }
    final uri = Uri.parse(authUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _log('🌐 Opened Strava login: $authUrl');
    } else {
      _log('❌ Could not launch URL: $authUrl');
    }
  }

  void _checkStravaStatus() {
    _log('ℹ️ Strava status: check server logs for stored token.');
    _log('   After connecting, the StravaServer holds your token in-memory.');
  }

  // -----------------------------------------------------------------------
  // Subscription Actions (Phase 1.13)
  // -----------------------------------------------------------------------

  /// Check subscription status from the backend and display tier info.
  Future<void> _checkSubscriptionStatus() async {
    _log('Checking subscription status from backend...');
    try {
      final notifier = ref.read(subscriptionProvider.notifier);
      await notifier.refresh();
      final state = ref.read(subscriptionProvider);
      _log('Tier: ${state.tier.name}');
      _log('Premium: ${state.isPremium}');
      _log('Expires: ${state.expiresAt ?? "N/A"}');
    } catch (e) {
      _log('Error: $e');
    }
  }

  /// Check RevenueCat entitlements and display active/all entitlement keys.
  Future<void> _checkEntitlements() async {
    _log('Checking RevenueCat entitlements...');
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final info = await repo.getCustomerInfo();
      _log('Active Entitlements: ${info.entitlements.active.keys.toList()}');
      _log('All Entitlements: ${info.entitlements.all.keys.toList()}');
    } catch (e) {
      _log('Error: $e');
    }
  }

  /// Fetch RevenueCat offerings and display available packages.
  Future<void> _viewOfferings() async {
    _log('Fetching RevenueCat offerings...');
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final offerings = await repo.getOfferings();
      if (offerings == null || offerings.current == null) {
        _log('No offerings available');
        return;
      }
      final current = offerings.current!;
      _log('Current offering: ${current.identifier}');
      for (final pkg in current.availablePackages) {
        final price = pkg.storeProduct.priceString;
        _log('  Package: ${pkg.identifier} - $price');
      }
    } catch (e) {
      _log('Error: $e');
    }
  }

  /// Restore previous purchases via RevenueCat.
  Future<void> _restorePurchases() async {
    _log('Restoring purchases...');
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final info = await repo.restorePurchases();
      _log('Restored. Active: ${info.entitlements.active.keys.toList()}');
    } catch (e) {
      _log('Error: $e');
    }
  }

  /// Present the full RevenueCat Paywall via the PaywallScreen route.
  Future<void> _presentPaywall() async {
    _log('Presenting full paywall...');
    final result = await Navigator.push<PaywallResult>(
      context,
      MaterialPageRoute<PaywallResult>(builder: (_) => const PaywallScreen()),
    );
    _log('Paywall result: ${result?.name ?? "dismissed"}');
    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      await _checkSubscriptionStatus();
    }
  }

  /// Present the paywall only if the user lacks ZuraLog Pro entitlement.
  Future<void> _presentPaywallIfNeeded() async {
    _log('Presenting paywall if needed...');
    try {
      final result = await ref
          .read(subscriptionProvider.notifier)
          .presentPaywallIfNeeded();
      _log('Paywall if needed result: ${result.name}');
    } catch (e) {
      _log('Error: $e');
    }
  }

  /// Present the RevenueCat Customer Center for subscription management.
  Future<void> _presentCustomerCenter() async {
    _log('Opening Customer Center...');
    try {
      await ref.read(subscriptionProvider.notifier).presentCustomerCenter();
      _log('✅ Customer Center closed');
    } catch (e) {
      _log('Error: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isAuthed = authState == AuthState.authenticated;

    return Scaffold(
      backgroundColor: _Colors.surface,
      appBar: _buildAppBar(isAuthed),
      body: SafeArea(
        child: Column(
          children: [
            // Sections
            Expanded(
              flex: 5,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  _buildCommandsSection(),
                  const SizedBox(height: 16),
                  _buildAuthSection(),
                  const SizedBox(height: 16),
                  _buildHealthKitSection(),
                  const SizedBox(height: 16),
                  _buildIntegrationsSection(),
                  const SizedBox(height: 16),
                  _buildAiBrainSection(),
                  const SizedBox(height: 16),
                  _buildBackgroundSyncSection(),
                  const SizedBox(height: 16),
                  _buildAnalyticsSection(),
                  const SizedBox(height: 16),
                  _buildSubscriptionSection(),
                  const SizedBox(height: 16),
                  _buildDeepLinksSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Output Log
            _buildOutputSection(),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // AppBar
  // -----------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(bool isAuthed) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_Colors.primary, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.science_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'ZuraLog',
            style: TextStyle(
              color: _Colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _Colors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DEV',
              style: TextStyle(
                color: _Colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Backend connectivity indicator
        GestureDetector(
          onTap: _checkBackendStatus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _backendOnline
                  ? _Colors.successLight
                  : _Colors.dangerLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _backendOnline
                    ? _Colors.success.withValues(alpha: 0.3)
                    : _Colors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _backendOnline ? _Colors.success : _Colors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _backendOnline ? 'API' : 'API',
                  style: TextStyle(
                    color: _backendOnline ? _Colors.success : _Colors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Auth state indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAuthed ? _Colors.successLight : _Colors.dangerLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAuthed
                  ? _Colors.success.withValues(alpha: 0.3)
                  : _Colors.danger.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isAuthed ? _Colors.success : _Colors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isAuthed ? 'AUTH' : 'UNAUTH',
                style: TextStyle(
                  color: isAuthed ? _Colors.success : _Colors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Commands
  // -----------------------------------------------------------------------

  Widget _buildCommandsSection() {
    return _SectionCard(
      icon: Icons.terminal_rounded,
      iconColor: _Colors.primary,
      title: 'COMMANDS',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.favorite_border_rounded,
              label: 'Health Check',
              color: _Colors.primary,
              onTap: _testHealthCheck,
            ),
            _ActionChip(
              icon: Icons.lock_outline_rounded,
              label: 'Secure Storage',
              color: _Colors.primary,
              onTap: _testSecureStorage,
            ),
            _ActionChip(
              icon: Icons.storage_rounded,
              label: 'Local DB',
              color: _Colors.primary,
              onTap: _testLocalDb,
            ),
            _ActionChip(
              icon: Icons.delete_sweep_rounded,
              label: 'Clear Log',
              color: _Colors.textSecondary,
              onTap: _clearOutput,
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Auth
  // -----------------------------------------------------------------------

  Widget _buildAuthSection() {
    return _SectionCard(
      icon: Icons.shield_rounded,
      iconColor: _Colors.info,
      title: 'AUTH',
      children: [
        _StyledTextField(
          controller: _emailController,
          hint: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        _StyledTextField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Login',
                icon: Icons.login_rounded,
                color: _Colors.success,
                onTap: _handleLogin,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Register',
                icon: Icons.person_add_rounded,
                color: _Colors.info,
                onTap: _handleRegister,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Logout',
                icon: Icons.logout_rounded,
                color: _Colors.danger,
                onTap: _handleLogout,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: HealthKit
  // -----------------------------------------------------------------------

  Widget _buildHealthKitSection() {
    return _SectionCard(
      icon: Icons.monitor_heart_rounded,
      iconColor: _Colors.danger,
      title: 'HEALTHKIT',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.check_circle_outline,
              label: 'Available',
              color: _Colors.success,
              onTap: _testHealthAvailable,
            ),
            _ActionChip(
              icon: Icons.verified_user_outlined,
              label: 'Request Auth',
              color: _Colors.info,
              onTap: _testHealthAuth,
            ),
            _ActionChip(
              icon: Icons.directions_walk_rounded,
              label: 'Steps',
              color: _Colors.primary,
              onTap: _testReadSteps,
            ),
            _ActionChip(
              icon: Icons.fitness_center_rounded,
              label: 'Workouts',
              color: _Colors.warning,
              onTap: _testReadWorkouts,
            ),
            _ActionChip(
              icon: Icons.bedtime_rounded,
              label: 'Sleep',
              color: Color(0xFF6C5CE7),
              onTap: _testReadSleep,
            ),
            _ActionChip(
              icon: Icons.monitor_weight_rounded,
              label: 'Weight',
              color: _Colors.info,
              onTap: _testReadWeight,
            ),
            _ActionChip(
              icon: Icons.restaurant_rounded,
              label: 'Nutrition',
              color: _Colors.success,
              onTap: _readNutrition,
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Integrations (Strava + CalAI)
  // -----------------------------------------------------------------------

  Widget _buildIntegrationsSection() {
    return _SectionCard(
      icon: Icons.extension_rounded,
      iconColor: _Colors.warning,
      title: 'INTEGRATIONS',
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Strava',
                icon: Icons.directions_bike_rounded,
                color: const Color(0xFFFC4C02),
                onTap: _connectStrava,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Strava Status',
                icon: Icons.info_outline_rounded,
                color: _Colors.textSecondary,
                onTap: _checkStravaStatus,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'CalAI',
                icon: Icons.camera_alt_rounded,
                color: _Colors.success,
                onTap: _openCalAI,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.help_outline_rounded,
              label: 'Strava Guide',
              color: _Colors.info,
              onTap: () {
                _log('--- STRAVA TESTING GUIDE ---');
                _log('Prerequisites:');
                _log(
                  '  1. Cloud Brain must be running '
                  '(cd cloud-brain && make dev)',
                );
                _log(
                  '  2. .env must have STRAVA_CLIENT_ID '
                  'and STRAVA_CLIENT_SECRET',
                );
                _log(
                  '  3. STRAVA_REDIRECT_URI must be: '
                  'zuralog://oauth/strava',
                );
                _log('  4. You must be logged in (use AUTH section first)');
                _log('');
                _log('Steps:');
                _log('  1. Log in via the AUTH section first');
                _log(
                  '  2. Tap "Strava" above — opens browser '
                  'to Strava auth page',
                );
                _log('  3. Log into your Strava account in the browser');
                _log('  4. Authorize "Zuralog" to access your data');
                _log(
                  '  5. Browser redirects to '
                  'zuralog://oauth/strava?code=XXX',
                );
                _log('  6. The app intercepts the deep link automatically');
                _log('  7. Code is exchanged for tokens on the backend');
                _log('  8. Check this log for exchange confirmation');
                _log('----------------------------');
              },
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: AI Brain
  // -----------------------------------------------------------------------

  Widget _buildAiBrainSection() {
    return _SectionCard(
      icon: Icons.psychology_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'AI BRAIN',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.smart_toy_rounded,
              label: 'Test AI Chat',
              color: _Colors.primary,
              onTap: _testAiChat,
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Background Sync
  // -----------------------------------------------------------------------

  Widget _buildBackgroundSyncSection() {
    return _SectionCard(
      icon: Icons.sync_rounded,
      iconColor: _Colors.info,
      title: 'BACKGROUND SYNC',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.notifications_active_rounded,
              label: 'Init FCM',
              color: _Colors.success,
              onTap: _initFcm,
            ),
            _ActionChip(
              icon: Icons.help_outline_rounded,
              label: 'Firebase Setup',
              color: _Colors.warning,
              onTap: () {
                _log('--- FIREBASE SETUP GUIDE ---');
                _log('FCM (push notifications) requires a Firebase project:');
                _log('');
                _log('1. Go to https://console.firebase.google.com');
                _log('2. Create a project (or use an existing one)');
                _log('3. Add Android app: com.zuralog.zuralog');
                _log('4. Download google-services.json');
                _log('5. Place it at: android/app/google-services.json');
                _log('6. Rebuild the app: flutter run');
                _log('');
                _log('For backend FCM sends:');
                _log('7. Firebase Console → Project Settings → Service Accounts');
                _log('8. Generate new private key → save JSON file');
                _log('9. Set FCM_CREDENTIALS_PATH=<path> in cloud-brain/.env');
                _log('10. Restart the Cloud Brain');
                _log('');
                _log('Then tap "Init FCM" → "AI Write (Steps/Nutrition)"');
                _log('----------------------------');
              },
            ),
            _ActionChip(
              icon: Icons.directions_walk_rounded,
              label: 'AI Write (Steps)',
              color: _Colors.info,
              onTap: () => _triggerWrite('steps', {
                'count': 500,
                'date': DateTime.now().toIso8601String(),
              }),
            ),
            _ActionChip(
              icon: Icons.restaurant_rounded,
              label: 'AI Write (Nutrition)',
              color: _Colors.info,
              onTap: () => _triggerWrite('nutrition', {
                'calories': 650,
                'meal': 'lunch',
                'date': DateTime.now().toIso8601String(),
              }),
            ),
            _ActionChip(
              icon: Icons.sync_rounded,
              label: 'Sync Status',
              color: _Colors.info,
              onTap: () async {
                _log('Checking sync status...');
                final store = ref.read(syncStatusStoreProvider);
                final lastSync = await store.getLastSyncTime();
                final inProgress = await store.isSyncInProgress();
                if (inProgress) {
                  _log('🔄 Sync is currently in progress...');
                } else if (lastSync != null) {
                  final ago = DateTime.now().difference(lastSync);
                  final String agoStr;
                  if (ago.inMinutes < 1) {
                    agoStr = '${ago.inSeconds}s ago';
                  } else if (ago.inHours < 1) {
                    agoStr = '${ago.inMinutes}m ago';
                  } else {
                    agoStr =
                        '${ago.inHours}h ${ago.inMinutes % 60}m ago';
                  }
                  _log('✅ Last sync: $agoStr ($lastSync)');
                } else {
                  _log(
                    '⚠️ Never synced. Background sync runs every '
                    '~15 min via WorkManager.',
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Analytics
  // -----------------------------------------------------------------------

  /// Builds the Analytics harness section with buttons for daily summaries,
  /// weekly trends, and AI-generated dashboard insights.
  Widget _buildAnalyticsSection() {
    return _SectionCard(
      icon: Icons.insights_rounded,
      iconColor: _Colors.success,
      title: 'ANALYTICS',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.today_rounded,
              label: 'Daily Summary',
              color: _Colors.success,
              onTap: () async {
                try {
                  _log('Fetching daily summary...');
                  final repo = ref.read(analyticsRepositoryProvider);
                  final summary = await repo.getDailySummary(DateTime.now());
                  _log(
                    'Summary for ${summary.date}:\n'
                    '  Steps: ${summary.steps}\n'
                    '  Cal In: ${summary.caloriesConsumed}\n'
                    '  Cal Out: ${summary.caloriesBurned}\n'
                    '  Workouts: ${summary.workoutsCount}\n'
                    '  Sleep: ${summary.sleepHours}h\n'
                    '  Weight: ${summary.weightKg ?? "N/A"} kg',
                  );
                } on DioException catch (e) {
                  _log('❌ ${ApiClient.friendlyError(e)}');
                } catch (e) {
                  _log('❌ Unexpected error: $e');
                }
              },
            ),
            _ActionChip(
              icon: Icons.show_chart_rounded,
              label: 'Weekly Trends',
              color: _Colors.success,
              onTap: () async {
                try {
                  _log('Fetching weekly trends...');
                  final repo = ref.read(analyticsRepositoryProvider);
                  final trends = await repo.getWeeklyTrends();
                  _log(
                    'Weekly Trends:\n'
                    '  Dates: ${trends.dates}\n'
                    '  Steps: ${trends.steps}\n'
                    '  Cal In: ${trends.caloriesIn}\n'
                    '  Cal Out: ${trends.caloriesOut}\n'
                    '  Sleep: ${trends.sleepHours}',
                  );
                } on DioException catch (e) {
                  _log('❌ ${ApiClient.friendlyError(e)}');
                } catch (e) {
                  _log('❌ Unexpected error: $e');
                }
              },
            ),
            _ActionChip(
              icon: Icons.lightbulb_rounded,
              label: 'Dashboard Insight',
              color: _Colors.warning,
              onTap: () async {
                try {
                  _log('Fetching dashboard insight...');
                  final repo = ref.read(analyticsRepositoryProvider);
                  final insight = await repo.getDashboardInsight();
                  _log(
                    'Insight: ${insight.insight}\n'
                    'Goals: ${insight.goals.length} active\n'
                    'Trends: ${insight.trends.keys.toList()}',
                  );
                } on DioException catch (e) {
                  _log('❌ ${ApiClient.friendlyError(e)}');
                } catch (e) {
                  _log('❌ Unexpected error: $e');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Subscription (Phase 1.13)
  // -----------------------------------------------------------------------

  /// Builds the Subscription harness section with buttons for checking
  /// backend status, RevenueCat entitlements, offerings, and restoring
  /// purchases.
  Widget _buildSubscriptionSection() {
    final subState = ref.watch(subscriptionProvider);
    return _SectionCard(
      icon: Icons.workspace_premium_rounded,
      iconColor: _Colors.warning,
      title: 'SUBSCRIPTION',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: subState.isPremium
              ? _Colors.warning.withValues(alpha: 0.12)
              : _Colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: subState.isPremium
                ? _Colors.warning.withValues(alpha: 0.4)
                : _Colors.border,
          ),
        ),
        child: Text(
          subState.isLoading
              ? 'LOADING'
              : subState.isPremium
              ? 'PRO'
              : 'FREE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: subState.isPremium ? _Colors.warning : _Colors.textSecondary,
          ),
        ),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.verified_user_rounded,
              label: 'Check Status',
              color: _Colors.success,
              onTap: _checkSubscriptionStatus,
            ),
            _ActionChip(
              icon: Icons.card_membership_rounded,
              label: 'Entitlements',
              color: _Colors.info,
              onTap: _checkEntitlements,
            ),
            _ActionChip(
              icon: Icons.shopping_bag_rounded,
              label: 'View Offerings',
              color: _Colors.primary,
              onTap: _viewOfferings,
            ),
            _ActionChip(
              icon: Icons.restore_rounded,
              label: 'Restore',
              color: _Colors.warning,
              onTap: _restorePurchases,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Paywall',
                icon: Icons.star_rounded,
                color: _Colors.warning,
                onTap: _presentPaywall,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'If Needed',
                icon: Icons.lock_open_rounded,
                color: _Colors.primary,
                onTap: _presentPaywallIfNeeded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Manage',
                icon: Icons.manage_accounts_rounded,
                color: _Colors.info,
                onTap: _presentCustomerCenter,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Deep Links (Phase 1.12)
  // -----------------------------------------------------------------------

  /// Builds the Deep Links harness section with buttons for testing
  /// outbound deep link launches to third-party apps (Strava, CalAI).
  Widget _buildDeepLinksSection() {
    return _SectionCard(
      icon: Icons.link_rounded,
      iconColor: _Colors.info,
      title: 'DEEP LINKS',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              icon: Icons.directions_bike_rounded,
              label: 'Strava (Record)',
              color: const Color(0xFFFC4C02),
              onTap: () async {
                _log('Testing Strava Record deep link...');
                final success = await DeepLinkLauncher.executeDeepLink(
                  'strava://record',
                  fallbackUrl: 'https://www.strava.com',
                );
                _log(success ? '✅ Strava launched!' : '❌ Strava launch failed');
              },
            ),
            _ActionChip(
              icon: Icons.camera_alt_rounded,
              label: 'CalAI (Camera)',
              color: _Colors.success,
              onTap: () async {
                _log('Testing CalAI Camera deep link...');
                final success = await DeepLinkLauncher.executeDeepLink(
                  'calai://camera',
                  fallbackUrl: 'https://www.calai.app',
                );
                _log(success ? '✅ CalAI launched!' : '❌ CalAI launch failed');
              },
            ),
            _ActionChip(
              icon: Icons.search_rounded,
              label: 'CalAI (Search)',
              color: _Colors.primary,
              onTap: () async {
                _log('Testing CalAI Search deep link...');
                final success = await DeepLinkLauncher.executeDeepLink(
                  'calai://search?q=coffee',
                  fallbackUrl: 'https://www.calai.app',
                );
                _log(
                  success
                      ? '✅ CalAI search launched!'
                      : '❌ CalAI search failed',
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Output Log
  // -----------------------------------------------------------------------

  Widget _buildOutputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _Colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 14,
                  color: _Colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'OUTPUT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _Colors.textSecondary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearOutput,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _Colors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CLEAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _Colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: _Colors.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              // Dev harness log output — read-only, chrome comes from the outer Container's
              // surface color. Outline intentionally omitted. Phase 6 Plan 6 reviewed and kept.
              child: TextField(
                controller: _outputController,
                maxLines: null,
                expands: true,
                readOnly: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFFDFE6E9),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  hintText: 'Logs will appear here...',
                  hintStyle: TextStyle(color: Color(0xFF636E72)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Reusable Components
// ===========================================================================

/// A card that wraps a harness section with consistent styling.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 14, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _Colors.textPrimary,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// A styled action chip button used in command/health sections.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A styled action button used for auth/chat/integration actions.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A styled text field with consistent look across sections.
class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _Colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _Colors.textSecondary.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(icon, size: 18, color: _Colors.textSecondary),
        filled: true,
        fillColor: _Colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _Colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _Colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _Colors.primary, width: 1.5),
        ),
      ),
    );
  }
}


