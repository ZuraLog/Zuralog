# CalAI Integration (Zero-Friction)

> **Status:** Reference document for Phase 1.7 implementation  
> **Priority:** P0 (MVP - via Health Stores)

---

## Overview

CalAI integration uses a **Zero-Friction Strategy**: instead of building a direct API integration, we leverage CalAI's existing write to Apple Health / Google Health Connect, and we read that data from the Health Stores.

This approach:
- Requires no OAuth setup with CalAI
- Works automatically when user logs food in CalAI
- Uses existing Health Store infrastructure
- Avoids CalAI's private/nonexistent API

---

## Data Flow

```
┌──────────┐    Logs food    ┌─────────────┐    Writes to    ┌──────────────┐
│  CalAI   │ ─────────────> │ Apple Health │ ─────────────> │ Life Logger  │
│  App     │                │ / Health Conn│ <─────────────  │ (reads data) │
└──────────┘                └──────────────┘                 └──────────────┘
```

### Step-by-Step Flow
1. User opens CalAI and logs a meal (photo + AI recognition)
2. CalAI writes nutrition data to Apple Health / Health Connect
3. Life Logger detects new data via HKObserverQuery / WorkManager
4. Life Logger reads nutrition data from Health Store
5. Life Logger AI includes this data in context and insights

---

## What Data We Read

### Apple HealthKit
- **Type:** `HKQuantityType.dietaryEnergyConsumed`
- **Unit:** Kilocalories
- **Includes:** Total calories per meal/snack

### Google Health Connect
- **Type:** `NutritionRecord`
- **Includes:** Energy, macronutrients (if available)

### Data Available
```json
{
    "total_calories": 1850,
    "protein_grams": 95,
    "carbs_grams": 180,
    "fat_grams": 65,
    "meals": [
        {
            "name": "Grilled Chicken Salad",
            "calories": 420,
            "time": "2026-02-18T12:30:00Z"
        },
        {
            "name": "Banana",
            "calories": 105,
            "time": "2026-02-18T10:00:00Z"
        }
    ]
}
```

---

## Deep Links

While we don't have API access, we can deep link to CalAI:

### iOS (CalAI URL Scheme)
- Open CalAI: `calai://`
- Camera (log food): `calai://camera`
- Home: `calai://home`

### Android
- Open CalAI: Package name `com.calai.app`
- Intent: `android.intent.action.VIEW`

### Web Fallback
- CalAI Web: `https://calai.com/app`

---

## Future: Direct API (Post-MVP)

If CalAI releases a public API in the future, we can extend this integration:

### Potential API Endpoints
- `GET /meals` - List logged meals
- `POST /meals` - Create meal entry
- `GET /nutrition/summary` - Daily/weekly nutrition summary

### Considerations
- OAuth 2.0 would be required
- API rate limits would apply
- Data freshness would improve
- More granular food data (photos, individual items)

---

## Handling Missing Data

When CalAI is NOT connected:
1. User asks "What did I eat today?"
2. Life Logger responds: "I don't see any nutrition data. Would you like to log a meal in CalAI?"
3. Offer deep link to CalAI camera

When CalAI IS connected:
1. Detect nutrition entries in Health Store
2. Read and aggregate daily totals
3. Include in AI context
4. Show in dashboard cards

---

## MyFitnessPal Alternative

Similar strategy for MyFitnessPal (MFP):

1. **Primary:** Read from Health Stores (MFP writes to Apple Health)
2. **Fallback:** Deep link to MFP (`mfp://`)

```dart
static Future<bool> openMyFitnessPal() async {
    final uri = Uri.parse('mfp://');
    if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
    }
    return false;
}
```

---

## Testing Checklist

- [ ] User logs food in CalAI
- [ ] Data appears in Apple Health (iOS)
- [ ] Data appears in Health Connect (Android)
- [ ] Life Logger reads nutrition data
- [ ] Nutrition shows in daily summary
- [ ] Deep link opens CalAI camera
- [ ] AI includes nutrition in context

---

## Summary

| Aspect | Strategy |
|--------|----------|
| Read Data | Via Apple Health / Health Connect |
| Write Data | Not applicable (user uses CalAI directly) |
| OAuth | Not required |
| API | Not required |
| Deep Links | `calai://camera` for quick logging |

---

## References

- [CalAI App Store](https://apps.apple.com/app/calai-ai-calorie-tracker/id1622964796)
- [HealthKit Nutrition](https://developer.apple.com/documentation/healthkit/sample_nutrition_data)
- [Health Connect Nutrition](https://developer.android.com/health-connect/data/nutrition)
