/// Life Logger Edge Agent — Developer Test Harness.
///
/// A polished test screen for manually triggering backend
/// functions and viewing real-time logs. Sections are organized
/// by feature with animated transitions and styled controls.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:life_logger/core/deeplink/deeplink_handler.dart';
import 'package:life_logger/core/deeplink/deeplink_launcher.dart';
import 'package:life_logger/core/di/providers.dart';
import 'package:life_logger/core/network/ws_client.dart';
import 'package:life_logger/features/auth/domain/auth_providers.dart';
import 'package:life_logger/features/auth/domain/auth_state.dart';
import 'package:life_logger/features/chat/data/chat_repository.dart';
import 'package:life_logger/features/chat/domain/message.dart';

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
  static const warningLight = Color(0xFFFFF8E1);
  static const info = Color(0xFF0984E3);
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
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<ChatMessage>? _wsSubscription;
  StreamSubscription<ConnectionStatus>? _wsStatusSubscription;
  ConnectionStatus _chatStatus = ConnectionStatus.disconnected;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    DeeplinkHandler.init(ref, onLog: _log);
  }

  @override
  void dispose() {
    DeeplinkHandler.dispose();
    _pulseController.dispose();
    _wsSubscription?.cancel();
    _wsStatusSubscription?.cancel();
    _outputController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Logging
  // -----------------------------------------------------------------------

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _outputController.text += '[$timestamp] $message\n';
    });
  }

  // -----------------------------------------------------------------------
  // Chat Status
  // -----------------------------------------------------------------------

  void _updateChatStatus(ConnectionStatus status) {
    setState(() => _chatStatus = status);
  }

  Color get _chatStatusColor => switch (_chatStatus) {
    ConnectionStatus.connected => _Colors.success,
    ConnectionStatus.connecting => _Colors.warning,
    ConnectionStatus.disconnected => _Colors.textSecondary,
  };

  String get _chatStatusLabel => switch (_chatStatus) {
    ConnectionStatus.connected => 'Connected',
    ConnectionStatus.connecting => 'Connecting...',
    ConnectionStatus.disconnected => 'Disconnected',
  };

  // -----------------------------------------------------------------------
  // Backend Actions
  // -----------------------------------------------------------------------

  Future<void> _testHealthCheck() async {
    _log('Testing /health endpoint...');
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/health');
      _log('✅ Response: ${response.data}');
    } catch (e) {
      _log('❌ Error: $e');
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
    _log('✅ LOGOUT: Tokens cleared');
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
    final available = await healthRepo.isAvailable;
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
    _log('Reading nutrition (last 7 days)...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final nutrition = await healthRepo.getNutrition(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    _log('✅ Nutrition entries: ${nutrition.length}');
    for (final entry in nutrition) {
      _log('  - ${entry["calories"]} kcal on ${entry["date"]}');
    }
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
  // Chat Actions
  // -----------------------------------------------------------------------

  void _connectWebSocket() {
    _log('Connecting WebSocket...');
    final chatRepo = ref.read(chatRepositoryProvider);

    _wsSubscription?.cancel();
    _wsSubscription = chatRepo.messages.listen((msg) {
      _log('💬 [${msg.role}] ${msg.content}');
    });

    _wsStatusSubscription?.cancel();
    _wsStatusSubscription = chatRepo.connectionStatus.listen((status) {
      _updateChatStatus(status);
      switch (status) {
        case ConnectionStatus.connected:
          _log('✅ WS Connected');
        case ConnectionStatus.connecting:
          _log('⏳ WS Connecting...');
        case ConnectionStatus.disconnected:
          _log('🔴 WS Disconnected');
      }
    });

    chatRepo.connect('test_token');
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      _log('⚠️ Chat message is empty');
      return;
    }
    _log('📤 Sending: $text');
    final chatRepo = ref.read(chatRepositoryProvider);
    chatRepo.sendMessage(text);
    _chatController.clear();
  }

  void _disconnectWebSocket() {
    _log('Disconnecting WebSocket...');
    final chatRepo = ref.read(chatRepositoryProvider);
    chatRepo.dispose();
    _wsSubscription?.cancel();
    _wsStatusSubscription?.cancel();
    _updateChatStatus(ConnectionStatus.disconnected);
    _log('✅ WS Disconnected');
  }

  // -----------------------------------------------------------------------
  // AI Brain Actions
  // -----------------------------------------------------------------------

  Future<void> _testAiChat() async {
    _log('Sending test AI message...');
    final chatRepo = ref.read(chatRepositoryProvider);
    if (_chatStatus != ConnectionStatus.connected) {
      _log('Connecting WS first...');
      _connectWebSocket();
      // Give time for connection
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    chatRepo.sendMessage('How are my steps today?');
    _log('Sent: "How are my steps today?"');
  }

  Future<void> _testVoiceUpload() async {
    _log('Testing voice transcription endpoint...');
    try {
      final apiClient = ref.read(apiClientProvider);
      // Send a minimal test request to check the endpoint exists.
      // Real audio upload requires platform-specific recording.
      final response = await apiClient.post('/transcribe');
      _log('Transcribe response: ${response.data}');
    } catch (e) {
      _log('Transcribe endpoint: $e (expected — no file attached)');
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
                  _buildChatSection(),
                  const SizedBox(height: 16),
                  _buildAiBrainSection(),
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
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section: Chat
  // -----------------------------------------------------------------------

  Widget _buildChatSection() {
    return _SectionCard(
      icon: Icons.chat_bubble_rounded,
      iconColor: _Colors.primary,
      title: 'CHAT',
      trailing: _buildStatusPill(),
      children: [
        // Input + Send
        Row(
          children: [
            Expanded(
              child: _StyledTextField(
                controller: _chatController,
                hint: 'Type a message...',
                icon: Icons.message_outlined,
                onSubmitted: (_) => _sendChatMessage(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _chatStatus == ConnectionStatus.connected
                      ? [_Colors.primary, const Color(0xFF8B5CF6)]
                      : [_Colors.border, _Colors.border],
                ),
                shape: BoxShape.circle,
                boxShadow: _chatStatus == ConnectionStatus.connected
                    ? [
                        BoxShadow(
                          color: _Colors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: IconButton(
                onPressed: _chatStatus == ConnectionStatus.connected
                    ? _sendChatMessage
                    : null,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Connect / Disconnect
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Connect',
                icon: Icons.power_settings_new_rounded,
                color: _Colors.success,
                enabled: _chatStatus == ConnectionStatus.disconnected,
                onTap: _connectWebSocket,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Disconnect',
                icon: Icons.power_off_rounded,
                color: _Colors.danger,
                enabled: _chatStatus != ConnectionStatus.disconnected,
                onTap: _disconnectWebSocket,
              ),
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
            _ActionChip(
              icon: Icons.mic_rounded,
              label: 'Voice Test',
              color: _Colors.warning,
              onTap: _testVoiceUpload,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _chatStatusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _chatStatusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chatStatus == ConnectionStatus.connecting
              ? FadeTransition(
                  opacity: _pulseAnimation,
                  child: _Dot(color: _chatStatusColor),
                )
              : _Dot(color: _chatStatusColor),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _chatStatusLabel,
              key: ValueKey(_chatStatus),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _chatStatusColor,
              ),
            ),
          ),
        ],
      ),
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
                if (trailing != null) trailing!,
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
  final bool enabled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : _Colors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: effectiveColor.withValues(alpha: enabled ? 0.2 : 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
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
  final ValueChanged<String>? onSubmitted;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
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

/// A tiny colored dot for status indicators.
class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
