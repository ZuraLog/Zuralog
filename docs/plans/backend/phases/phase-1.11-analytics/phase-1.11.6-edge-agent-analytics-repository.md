# Phase 1.11.6: Edge Agent Analytics Repository

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [x] 1.11.2 Correlation Analysis
- [x] 1.11.3 Trend Detection
- [x] 1.11.4 Goal Tracking
- [x] 1.11.5 Insight Generation
- [x] 1.11.6 Edge Agent Analytics Repository
- [ ] 1.11.7 Harness: Analytics Test

---

## What
Client-side repository to fetch analytics summaries from the Cloud Brain.

## Why
The Dashboard UI needs a clean source of truth for the charts.

## How
Standard Repository pattern using `ApiClient`.

## Features
- **Caching:** Cache the daily summary for at least 15 minutes to save API calls.
- **Error Handling:** Return cached data if offline.

## Files
- Create: `life_logger/lib/features/analytics/data/analytics_repository.dart`
- Create: `life_logger/lib/features/analytics/domain/daily_summary.dart` (Model)

## Steps

1. **Create repository (`life_logger/lib/features/analytics/data/analytics_repository.dart`)**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class AnalyticsRepository {
  final ApiClient _apiClient;
  
  AnalyticsRepository({required ApiClient apiClient}) : _apiClient = apiClient;
  
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    // In real app: check local cache first
    try {
      final response = await _apiClient.get(
        '/analytics/daily-summary', 
        queryParameters: {'date_str': date.toIso8601String().split('T')[0]}
      );
      return response.data;
    } catch (e) {
      // Return cached or rethrow
      rethrow;
    }
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(apiClient: ref.read(apiClientProvider));
});
```

## Exit Criteria
- Repository compiles.
- Returns Map (or Model) of summary data.
