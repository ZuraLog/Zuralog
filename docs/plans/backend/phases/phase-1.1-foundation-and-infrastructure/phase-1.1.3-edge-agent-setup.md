# Phase 1.1.3: Edge Agent (Flutter) Project Setup

**Parent Goal:** Phase 1.1 Foundation & Infrastructure
**Checklist:**
- [x] 1.1.1 Cloud Brain Repository Setup
- [x] 1.1.2 Database Setup
- [ ] 1.1.3 Edge Agent Setup
- [ ] 1.1.4 Network Layer
- [ ] 1.1.5 Local Storage
- [ ] 1.1.6 UI Harness

---

## What
Initialize the mobile application using Flutter, compatible with both iOS and Android. This includes setting up the directory structure, dependency management via `pubspec.yaml`, and the basic application entry point.

## Why
Flutter allows for a single codebase to deploy to both major mobile platforms. Setting up the project correctly with the right dependencies (Riverpod for state management, GoRouter for navigation) prevents technical debt later.

## How
We will use:
- **Flutter:** Cross-platform framework.
- **Riverpod:** For reactive state management and dependency injection.
- **GoRouter:** For declarative routing.
- **Dio:** For HTTP requests.

## Features
- **Cross-Platform Support:** Ready for iOS and Android.
- **State Management:** Riverpod configured for scalable state handling.
- **Routing:** Structured navigation setup.

## Files
- Create: `life_logger/pubspec.yaml`
- Create: `life_logger/lib/main.dart`
- Create: `life_logger/lib/app.dart`
- Create: `life_logger/lib/core/di/providers.dart`

## Steps

1. **Initialize Flutter project**

```bash
flutter create life_logger --org com.lifelogger --platforms ios,android
cd life_logger
```

2. **Configure `pubspec.yaml` with dependencies**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  dio: ^5.3.0
  go_router: ^12.0.0
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.18
  flutter_secure_storage: ^9.0.0
  web_socket_channel: ^2.4.0
  url_launcher: ^6.2.0
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
```

3. **Create basic app shell in `life_logger/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: LifeLoggerApp(),
    ),
  );
}
```

4. **Create minimal `app.dart`**

```dart
import 'package:flutter/material.dart';

class LifeLoggerApp extends StatelessWidget {
  const LifeLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Logger',
      home: const Scaffold(
        body: Center(child: Text('Life Logger - Test Harness')),
      ),
    );
  }
}
```

5. **Build to verify**

```bash
cd life_logger
flutter build ios --simulator --no-codesign
flutter build apk --debug
```

## Exit Criteria
- Flutter app builds successfully for iOS simulator and Android APK.
