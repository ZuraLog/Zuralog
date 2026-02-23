# Phase 1.1.5: Edge Agent Local Storage

**Parent Goal:** Phase 1.1 Foundation & Infrastructure
**Checklist:**
- [x] 1.1.1 Cloud Brain Repository Setup
- [x] 1.1.2 Database Setup
- [x] 1.1.3 Edge Agent Setup
- [x] 1.1.4 Network Layer
- [ ] 1.1.5 Local Storage
- [ ] 1.1.6 UI Harness

---

## What
Implement mechanisms for persisting data on the device. This involves secure storage for sensitive data (tokens) and a structured SQL database for caching app content (chat history, health metrics).

## Why
- **Security:** Auth tokens must be stored in the OS's secure enclave (Keychain/Keystore), not plain text.
- **Offline First:** A local database (Drift) allows the app to function without an internet connection and sync later.

## How
We will use:
- **flutter_secure_storage:** For AES-encrypted storage of keys/tokens.
- **Drift (sqlite):** For typed, reactive SQL database access.

## Features
- **Secure Token Storage:** Safe persistence of OAuth & JWT tokens.
- **Offline Caching:** Store chat messages and logs locally.
- **Reactive Data:** UI updates automatically when DB changes.

## Files
- Create: `zuralog/lib/core/storage/secure_storage.dart`
- Create: `zuralog/lib/core/storage/local_db.dart`

## Steps

1. **Create secure storage wrapper**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;
  
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> delete(String key) => _storage.delete(key: key);
  
  // Auth tokens
  Future<void> saveAuthToken(String token) => write('auth_token', token);
  Future<String?> getAuthToken() => read('auth_token');
  Future<void> clearAuthToken() => delete('auth_token');
  
  // Integration tokens
  Future<void> saveIntegrationToken(String provider, String token) =>
      write('integration_$provider', token);
  Future<String?> getIntegrationToken(String provider) =>
      read('integration_$provider');
}
```

2. **Create local DB (Drift) for offline caching**

```dart
// lib/core/storage/local_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'local_db.g.dart';

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get role => text()(); // 'user' or 'assistant'
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [Messages])
class LocalDb extends _$LocalDb {
  LocalDb() : super(NativeDatabase(File('local.db')));
  
  @override
  int get schemaVersion => 1;
  
  Future<List<Message>> getAllMessages() => select(messages).get();
  Future<int> insertMessage(MessagesCompanion msg) => into(messages).insert(msg);
}
```

3. **Run build_runner for Drift**

```bash
cd zuralog
flutter pub run build_runner build
```

## Exit Criteria
- Secure storage wrapper compiles.
- Local DB compiles and code generation runs successfully.
