# Phase 1.2.3: Edge Agent Auth Repository

**Parent Goal:** Phase 1.2 Authentication & User Management
**Checklist:**
- [x] 1.2.1 Cloud Brain Auth Endpoints
- [x] 1.2.2 User Sync to Local Database
- [ ] 1.2.3 Edge Agent Auth Repository
- [ ] 1.2.4 Edge Agent Auth UI Harness
- [ ] 1.2.5 Token Refresh Logic

---

## What
Implement the `AuthRepository` class in the Flutter application. This class is responsible for communicating with the backend auth endpoints and managing the local persistence of authentication tokens.

## Why
Separating authentication logic into a repository follows the Clean Architecture pattern. It abstracts the API calls and storage details from the UI, making the app easier to test and maintain.

## How
We will use:
- **Dio:** To make HTTP requests to the Cloud Brain.
- **SecureStorage:** To safely store the JWT access token and refresh token.
- **Riverpod:** To expose the authentication state to the rest of the application.

## Features
- **Login/Register:** Connects variables from UI to Backend.
- **Token Management:** Auto-saves tokens upon successful login.
- **Session Check:** Provides a method to check if the user is currently logged in (for splash screen routing).
- **Logout:** Clears local tokens and invalidates server session.

## Files
- Create: `zuralog/lib/features/auth/data/auth_repository.dart`
- Create: `zuralog/lib/features/auth/domain/auth_service.dart`

## Steps

1. **Create auth repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  
  AuthRepository({required ApiClient apiClient, required SecureStorage secureStorage})
      : _apiClient = apiClient,
        _secureStorage = secureStorage;
  
  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final session = response.data['session'];
      await _secureStorage.saveAuthToken(session['access_token']);
      await _secureStorage.write('refresh_token', session['refresh_token']);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> register(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/register', data: {
        'email': email,
        'password': password,
      });
      final session = response.data['session'];
      await _secureStorage.saveAuthToken(session['access_token']);
      await _secureStorage.write('refresh_token', session['refresh_token']);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {
      // Ignore errors on logout
    }
    await _secureStorage.clearAuthToken();
  }
  
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getAuthToken();
    return token != null;
  }
}
```

2. **Create Riverpod provider**

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.isLoggedIn();
});
```

## Exit Criteria
- Auth repository compiles with login, register, and logout methods.
