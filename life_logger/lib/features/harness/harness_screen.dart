/// Life Logger Edge Agent — Developer Test Harness.
///
/// A raw, unstyled screen with buttons to manually trigger backend
/// functions and a text area to view logs/responses. This is NOT
/// the production UI — it exists solely for functional verification
/// during Phase 1 (backend-first development).
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

/// The developer test harness screen.
///
/// Provides manual triggers for core backend operations and displays
/// output in a scrollable text area. No styling — if it looks good,
/// we're wasting time (per execution plan rules).
class HarnessScreen extends ConsumerStatefulWidget {
  /// Creates a new [HarnessScreen].
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
    super.dispose();
  }

  /// Appends a line of text to the output area with a timestamp.
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _outputController.text += '[$timestamp] $message\n';
    });
  }

  /// Tests the health endpoint via the API client.
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

  /// Tests secure storage write/read cycle.
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

  /// Tests local database insert/read cycle.
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

  /// Tests login via the AuthRepository.
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

  /// Tests registration via the AuthRepository.
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

  /// Tests logout via the AuthRepository.
  Future<void> _handleLogout() async {
    _log('Logging out...');
    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.logout();
    _log('✅ LOGOUT: Tokens cleared');
  }

  /// Clears the output area.
  void _clearOutput() {
    setState(() {
      _outputController.text = '';
    });
  }

  // -- HealthKit Harness Methods --

  /// Tests HealthKit availability on this device.
  Future<void> _testHealthAvailable() async {
    _log('Checking HealthKit availability...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final available = await healthRepo.isAvailable;
    _log(available ? '✅ HealthKit AVAILABLE' : '❌ HealthKit UNAVAILABLE');
  }

  /// Requests HealthKit authorization from the user.
  Future<void> _testHealthAuth() async {
    _log('Requesting HealthKit authorization...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final authorized = await healthRepo.requestAuthorization();
    _log(
      authorized ? '✅ HealthKit AUTHORIZED' : '❌ HealthKit DENIED/UNAVAILABLE',
    );
  }

  /// Reads today's step count from HealthKit.
  Future<void> _testReadSteps() async {
    _log('Reading steps for today...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final steps = await healthRepo.getSteps(DateTime.now());
    _log('✅ Steps today: $steps');
  }

  /// Reads workouts from the last 7 days.
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

  /// Reads sleep data from the last 7 days.
  Future<void> _testReadSleep() async {
    _log('Reading sleep (last 7 days)...');
    final healthRepo = ref.read(healthRepositoryProvider);
    final sleep = await healthRepo.getSleep(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    _log('✅ Sleep segments: ${sleep.length}');
  }

  /// Reads the latest body weight from HealthKit.
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

  /// Reads nutrition (calorie) data from the last 7 days.
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

  // -- CalAI Harness Methods (Phase 1.7) --

  /// Opens CalAI for food photo logging via deep link.
  ///
  /// Falls back to CalAI web/store URL if the app is not installed.
  Future<void> _openCalAI() async {
    _log('Opening CalAI for food logging...');
    final opened = await DeepLinkLauncher.openFoodLogging();
    if (opened) {
      _log('✅ CalAI launched (or web fallback opened)');
    } else {
      _log('❌ Could not open CalAI or fallback URL');
    }
  }

  // -- Chat Harness Methods (Phase 1.9) --

  /// Connects the WebSocket to the Cloud Brain.
  void _connectWebSocket() {
    _log('Connecting WebSocket...');
    final chatRepo = ref.read(chatRepositoryProvider);

    // Listen for incoming messages
    _wsSubscription?.cancel();
    _wsSubscription = chatRepo.messages.listen((msg) {
      _log('💬 [${msg.role}] ${msg.content}');
    });

    // Listen for connection status changes
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

    // Use a mock token for testing — replace with real auth token
    chatRepo.connect('test_token');
  }

  /// Updates the tracked chat connection status and rebuilds the UI.
  void _updateChatStatus(ConnectionStatus status) {
    setState(() {
      _chatStatus = status;
    });
  }

  /// Returns the color associated with the current chat connection status.
  Color get _chatStatusColor => switch (_chatStatus) {
    ConnectionStatus.connected => Colors.green.shade600,
    ConnectionStatus.connecting => Colors.orange.shade600,
    ConnectionStatus.disconnected => Colors.grey.shade500,
  };

  /// Returns the label text for the current chat connection status.
  String get _chatStatusLabel => switch (_chatStatus) {
    ConnectionStatus.connected => 'Connected',
    ConnectionStatus.connecting => 'Connecting...',
    ConnectionStatus.disconnected => 'Disconnected',
  };

  /// Sends a chat message via WebSocket.
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

  /// Disconnects the WebSocket.
  void _disconnectWebSocket() {
    _log('Disconnecting WebSocket...');
    final chatRepo = ref.read(chatRepositoryProvider);
    chatRepo.dispose();
    _wsSubscription?.cancel();
    _wsStatusSubscription?.cancel();
    _updateChatStatus(ConnectionStatus.disconnected);
    _log('✅ WS Disconnected');
  }

  // -- Strava Harness Methods (Phase 1.6) --

  /// Fetches the Strava OAuth URL from the Cloud Brain and opens it in the
  /// system browser. On return, Strava redirects to lifelogger://oauth/strava
  /// which [DeeplinkHandler] intercepts automatically.
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

  /// Logs a reminder that Strava connection status is visible in server logs.
  /// A dedicated status endpoint will be added in a future phase.
  void _checkStravaStatus() {
    _log('ℹ️ Strava status: check server logs for stored token.');
    _log(
      '   After connecting, the StravaServer instance holds your token in-memory.',
    );
    _log(
      '   Phase 1.7 will add DB persistence and a /integrations/strava/status endpoint.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TEST HARNESS - NO STYLING'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                authState == AuthState.authenticated
                    ? '🟢 AUTHED'
                    : '🔴 UNAUTHED',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMANDS:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _testHealthCheck,
                          icon: const Icon(
                            Icons.favorite_border,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                          label: const Text(
                            '1. Health Check',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade50,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _testSecureStorage,
                          icon: const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                          label: const Text(
                            '2. Secure Storage',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade50,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _testLocalDb,
                          icon: const Icon(
                            Icons.storage,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                          label: const Text(
                            '3. Local DB',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade50,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _clearOutput,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'AUTH:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _handleLogin,
                          child: const Text('Login'),
                        ),
                        ElevatedButton(
                          onPressed: _handleRegister,
                          child: const Text('Register'),
                        ),
                        ElevatedButton(
                          onPressed: _handleLogout,
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'HEALTHKIT:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _testHealthAvailable,
                          child: const Text('Check Available'),
                        ),
                        ElevatedButton(
                          onPressed: _testHealthAuth,
                          child: const Text('Request Auth'),
                        ),
                        ElevatedButton(
                          onPressed: _testReadSteps,
                          child: const Text('Read Steps'),
                        ),
                        ElevatedButton(
                          onPressed: _testReadWorkouts,
                          child: const Text('Read Workouts'),
                        ),
                        ElevatedButton(
                          onPressed: _testReadSleep,
                          child: const Text('Read Sleep'),
                        ),
                        ElevatedButton(
                          onPressed: _testReadWeight,
                          child: const Text('Read Weight'),
                        ),
                        ElevatedButton(
                          onPressed: _readNutrition,
                          child: const Text('Read Nutrition'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'STRAVA:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _connectStrava,
                          child: const Text('Connect Strava'),
                        ),
                        ElevatedButton(
                          onPressed: _checkStravaStatus,
                          child: const Text('Check Strava Status'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'CALAI:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _openCalAI,
                          child: const Text('Log Food (CalAI)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'CHAT:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // -- Connection Status Pill --
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _chatStatusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _chatStatusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulsing dot for connecting state
                          if (_chatStatus == ConnectionStatus.connecting)
                            FadeTransition(
                              opacity: _pulseAnimation,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _chatStatusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _chatStatusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _chatStatusLabel,
                              key: ValueKey(_chatStatus),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _chatStatusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // -- Chat Input + Send --
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            onSubmitted: (_) => _sendChatMessage(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Colors.deepPurple,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _chatStatus == ConnectionStatus.connected
                                  ? [
                                      Colors.deepPurple,
                                      Colors.deepPurple.shade300,
                                    ]
                                  : [
                                      Colors.grey.shade400,
                                      Colors.grey.shade300,
                                    ],
                            ),
                            shape: BoxShape.circle,
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
                    // -- Connect / Disconnect Buttons --
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: ElevatedButton.icon(
                              onPressed:
                                  _chatStatus == ConnectionStatus.disconnected
                                  ? _connectWebSocket
                                  : null,
                              icon: Icon(
                                Icons.power_settings_new_rounded,
                                size: 18,
                                color:
                                    _chatStatus == ConnectionStatus.disconnected
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                              label: Text(
                                'Connect',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _chatStatus ==
                                          ConnectionStatus.disconnected
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _chatStatus == ConnectionStatus.disconnected
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: ElevatedButton.icon(
                              onPressed:
                                  _chatStatus != ConnectionStatus.disconnected
                                  ? _disconnectWebSocket
                                  : null,
                              icon: Icon(
                                Icons.power_off_rounded,
                                size: 18,
                                color:
                                    _chatStatus != ConnectionStatus.disconnected
                                    ? Colors.red.shade700
                                    : Colors.grey,
                              ),
                              label: Text(
                                'Disconnect',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _chatStatus !=
                                          ConnectionStatus.disconnected
                                      ? Colors.red.shade700
                                      : Colors.grey,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _chatStatus != ConnectionStatus.disconnected
                                    ? Colors.red.shade50
                                    : Colors.grey.shade100,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'OUTPUT:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _outputController,
                  maxLines: null,
                  expands: true,
                  readOnly: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    hintText: 'System output will appear here...',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
