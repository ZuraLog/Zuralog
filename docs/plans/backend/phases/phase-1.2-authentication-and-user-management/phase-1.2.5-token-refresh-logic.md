# Phase 1.2.5: Token Refresh Logic

**Parent Goal:** Phase 1.2 Authentication & User Management
**Checklist:**
- [x] 1.2.1 Cloud Brain Auth Endpoints
- [x] 1.2.2 User Sync to Local Database
- [x] 1.2.3 Edge Agent Auth Repository
- [x] 1.2.4 Edge Agent Auth UI Harness
- [ ] 1.2.5 Token Refresh Logic

---

## What
Implement "Silent Token Refresh" logic. When the backend rejects a request with a `401 Unauthorized` error, the app should automatically attempt to use the long-lived `refresh_token` to get a new `access_token` and retry the original request transparently to the user.

## Why
JWT access tokens typically have short expirations (e.g., 1 hour) for security. We don't want to force the user to log in again every hour. Refresh tokens allow us to maintain a seamless session while keeping access tokens short-lived.

## How
We will use **Dio Interceptors**. Specifically, the `onError` interceptor.
1. Catch 401 errors.
2. Lock the request queue.
3. Call the refresh endpoint.
4. If successful, update the token and retry the failed request.
5. If failed, logout the user.

## Features
- **Seamless UX:** Users stay logged in indefinitely (until refresh token expires).
- **Security:** Access tokens remain short-lived.

## Files
- Modify: `cloud-brain/app/api/v1/auth.py`
- Modify: `zuralog/lib/core/network/api_client.dart`

## Steps

1. **Add Refresh Endpoint to Cloud Brain (`cloud-brain/app/api/v1/auth.py`)**

```python
class RefreshRequest(BaseModel):
    refresh_token: str

@router.post("/refresh")
async def refresh_token(request: RefreshRequest):
    """Exhange refresh token for new session."""
    try:
        # Supabase API to refresh session
        auth_response = supabase.auth.refresh_session(request.refresh_token)
        return {"session": auth_response.session}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
```

2. **Update API Client with Refresh Logic (`zuralog/lib/core/network/api_client.dart`)**

```dart
// Inside ApiClient constructor
_dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  },
  onError: (DioException error, handler) async {
    if (error.response?.statusCode == 401) {
      // Attempt refresh
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          // Call refresh endpoint using a fresh Dio instance to avoid recursive loop
          final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
          final response = await refreshDio.post('/auth/refresh', data: {
            'refresh_token': refreshToken
          });
          
          final newToken = response.data['session']['access_token'];
          final newRefreshToken = response.data['session']['refresh_token'];
          
          await _storage.saveAuthToken(newToken);
          await _storage.write('refresh_token', newRefreshToken);
          
          // Retry original request
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          
          final cloneReq = await _dio.request(
            opts.path,
            options: Options(
              method: opts.method,
              headers: opts.headers,
            ),
            data: opts.data,
            queryParameters: opts.queryParameters,
          );
          return handler.resolve(cloneReq);
        } catch (e) {
          // Refresh failed, logout
          await _storage.clearAuthToken();
          await _storage.delete(key: 'refresh_token');
        }
      }
    }
    return handler.next(error);
  },
));
```

## Exit Criteria
- 401 responses trigger a refresh attempt.
- `/auth/refresh` endpoint implemented in Cloud Brain.
- Successful refresh retries the original request.
