# Phase 1.6.4: Edge Agent OAuth Flow

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [x] 1.6.1 Strava API Setup
- [x] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [x] 1.6.3 Strava MCP Server
- [ ] 1.6.4 Edge Agent OAuth Flow
- [ ] 1.6.5 Deep Link Handling
- [ ] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Implement the client-side logic in Flutter to handle the "Connect Strava" button press. This involves fetching the auth URL from the backend and listening for the callback.

## Why
The mobile app initiates the flow, even though the token exchange happens on the server.

## How
Use `OAuthRepository` to talk to the backend.

## Features
- **Stateless:** The app doesn't need to know the Client ID/Secret.
- **Secure:** Auth code is passed via secure channel (Deep Link -> API call).

## Files
- Create: `life_logger/lib/features/integrations/data/oauth_repository.dart`

## Steps

1. **Create OAuth repository (`life_logger/lib/features/integrations/data/oauth_repository.dart`)**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class OAuthRepository {
  final ApiClient _apiClient;
  
  OAuthRepository({required ApiClient apiClient})
      : _apiClient = apiClient;
  
  /// Get the authorization URL to open in a browser/webview
  Future<String?> getStravaAuthUrl() async {
    try {
      final response = await _apiClient.get('/integrations/strava/authorize');
      return response.data['auth_url'];
    } catch (e) {
      return null;
    }
  }
  
  /// Send the auth code back to the backend to finalize connection
  Future<bool> handleStravaCallback(String code) async {
    try {
      // Note: Endpoint changed to POST /exchange in 1.6.2
      final response = await _apiClient.post('/integrations/strava/exchange', queryParameters: {
        'code': code,
      });
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }
}

// Riverpod Provider
final oauthRepositoryProvider = Provider<OAuthRepository>((ref) {
  return OAuthRepository(apiClient: ref.read(apiClientProvider));
});
```

## Exit Criteria
- Repository compiles.
- Can fetch auth URL.
