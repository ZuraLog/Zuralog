# Phase 1.1.6: Developer UI Harness (No Styling)

**Parent Goal:** Phase 1.1 Foundation & Infrastructure
**Checklist:**
- [x] 1.1.1 Cloud Brain Repository Setup
- [x] 1.1.2 Database Setup
- [x] 1.1.3 Edge Agent Setup
- [x] 1.1.4 Network Layer
- [x] 1.1.5 Local Storage
- [ ] 1.1.6 UI Harness

---

## What
Create a "Harness" screen—a raw, unstyled view containing buttons to manually trigger backend functions and a text area to view logs/responses.

## Why
Waiting for the final "Stitch" UI designs (Phase 2) blocks backend testing. A harness allows us to verify logic (auth, API calls, DB sync) immediately, separating functional verification from UI implementation.

## How
We will use standard Flutter Material widgets (`ElevatedButton`, `TextField`) without any custom styling. The harness will directly call Repository methods and print results to the screen.

## Features
- **Visual Console:** view logs and API responses on-device.
- **Manual Triggers:** Buttons to force actions like "Login", "Sync", "Clear DB".
- **Zero-Friction Testing:** No need to navigate complex UI flows to test a specific API.

## Files
- Modify: `zuralog/lib/app.dart`
- Create: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Create basic test harness screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HarnessScreen extends ConsumerStatefulWidget {
  const HarnessScreen({super.key});

  @override
  ConsumerState<HarnessScreen> createState() => _HarnessScreenState();
}

class _HarnessScreenState extends ConsumerState<HarnessScreen> {
  final _outputController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST HARNESS - NO STYLING')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('COMMANDS:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Login test...',
                  child: const Text('1. Login'),
                ),
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Strava connect...',
                  child: const Text('2. Connect Strava'),
                ),
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Fetch activities...',
                  child: const Text('3. Fetch Runs'),
                ),
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Health read...',
                  child: const Text('4. Read HealthKit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('OUTPUT:'),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _outputController,
                maxLines: null,
                expands: true,
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
```

2. **Update app.dart to show harness**

```dart
import 'features/harness/harness_screen.dart';

class ZuralogApp extends StatelessWidget {
  const ZuralogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HarnessScreen(),
    );
  }
}
```

## Exit Criteria
- App builds and shows raw test harness UI with buttons and text output area.
- Development cycle (edit -> hot reload) works.
