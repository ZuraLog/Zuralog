# Phase 2.2.3: Dashboard Screen

**Parent Goal:** Phase 2.2 Screen Implementation (Wiring)
**Checklist:**
- [x] 2.2.1 Welcome & Auth Screen
- [x] 2.2.2 Coach Chat Screen
- [x] 2.2.3 Dashboard Screen
- [ ] 2.2.4 Integrations Hub Screen
- [ ] 2.2.5 Settings Screen

---

## What
The main "Heads Up Display" for the user's life. It shows aggregated health stats, the "Insight of the Day", and quick actions.

## Why
Users need a quick "Health Check" without diving into spreadsheets.

## How
Fetch data from `AnalyticsRepository` (created in 1.11.6).

## Features
- **Insight Card:** Top section showing the AI-generated text ("You're crushing your step goal!").
- **Health Rings:** Visual progress indicators (Apple-style) for Steps, Sleep, Calories.
- **Trend Charts:** Small sparkline charts for weekly trends (using `fl_chart`).

## Files
- Create: `life_logger/lib/features/dashboard/presentation/dashboard_screen.dart`
- Create: `life_logger/lib/features/dashboard/presentation/widgets/insight_card.dart`
- Create: `life_logger/lib/features/dashboard/presentation/widgets/activity_rings.dart`

## Steps

1. **Create Dashboard (`life_logger/lib/features/dashboard/presentation/dashboard_screen.dart`)**

```dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Poll for data on init
    final analytics = ref.watch(analyticsProvider); 

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text("Dashboard"), floating: true),
          SliverToBoxAdapter(
            child: InsightCard(text: analytics.insight),
          ),
          SliverToBoxAdapter(
            child: ActivityRings(data: analytics.dailyStats),
          ),
          // Weekly Charts grid
        ],
      ),
    );
  }
}
```

## Exit Criteria
- Dashboard loads data from API.
- Rings animate to correct values.
