/// Life Logger Edge Agent — Developer Test Harness.
///
/// A raw, unstyled screen with buttons to manually trigger backend
/// functions and a text area to view logs/responses. This is NOT
/// the production UI — it exists solely for functional verification
/// during Phase 1 (backend-first development).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/core/di/providers.dart';

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

class _HarnessScreenState extends ConsumerState<HarnessScreen> {
  final _outputController = TextEditingController();

  @override
  void dispose() {
    _outputController.dispose();
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

  /// Clears the output area.
  void _clearOutput() {
    setState(() {
      _outputController.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST HARNESS - NO STYLING')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                ElevatedButton(
                  onPressed: _testHealthCheck,
                  child: const Text('1. Health Check'),
                ),
                ElevatedButton(
                  onPressed: _testSecureStorage,
                  child: const Text('2. Secure Storage'),
                ),
                ElevatedButton(
                  onPressed: _testLocalDb,
                  child: const Text('3. Local DB'),
                ),
                ElevatedButton(
                  onPressed: _clearOutput,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'OUTPUT:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _outputController,
                maxLines: null,
                expands: true,
                readOnly: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Output will appear here...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
