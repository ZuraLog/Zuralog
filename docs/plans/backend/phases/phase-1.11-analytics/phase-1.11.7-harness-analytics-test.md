# Phase 1.11.7: Harness: Analytics Test

**Parent Goal:** Phase 1.11 Analytics & Cross-App Reasoning
**Checklist:**
- [x] 1.11.1 Analytics Dashboard Data
- [x] 1.11.2 Correlation Analysis
- [x] 1.11.3 Trend Detection
- [x] 1.11.4 Goal Tracking
- [x] 1.11.5 Insight Generation
- [x] 1.11.6 Edge Agent Analytics Repository
- [x] 1.11.7 Harness: Analytics Test

---

## What
Add controls to the Developer UI Harness to fetch and view the Daily Summary and Insight data.

## Why
Verify that the aggregation pipeline (Cloud Brain -> DB -> API -> Edge Agent) is working.

## How
Simple "Fetch Analytics" button in `HarnessScreen`.

## Features
- **JSON Viewer:** Display the raw JSON result for inspection.

## Files
- Modify: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Add test controls (`zuralog/lib/features/harness/harness_screen.dart`)**

```dart
ElevatedButton(
  onPressed: () async {
    try {
      final repo = ref.read(analyticsRepositoryProvider);
      final summary = await repo.getDailySummary(DateTime.now());
      // Pretty print JSON
      _outputController.text = "Summary:\n$summary";
    } catch (e) {
      _outputController.text = "Error: $e";
    }
  },
  child: const Text('Fetch Daily Analytics'),
),
```

## Exit Criteria
- Can fetch and display analytics JSON.
