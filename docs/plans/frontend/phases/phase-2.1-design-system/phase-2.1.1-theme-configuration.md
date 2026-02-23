# Phase 2.1.1: Theme Configuration

**Parent Goal:** Phase 2.1 Design System Setup
**Checklist:**
- [x] 2.1.1 Theme Configuration
- [ ] 2.1.2 Reusable Components

---

## What
Define the core design tokens (Colors, Typography, Spacing, Radius) and configure the Flutter `ThemeData` for both Light and Dark modes.

## Why
Consistency is key to a premium feel. We don't want hardcoded hex values scattered across 50 widgets.

## How
Create `AppColors`, `AppTextStyles`, `AppDimens` classes and a central `AppTheme` factory.

## Features
- **Semantic Colors:** Use strict naming (e.g., `surface`, `onSurface`, `primary`, `onPrimary`).
- **Typography:** Custom font family (e.g., 'Inter' or 'SF Pro') configured globally.

## Files
- Create: `zuralog/lib/core/theme/app_colors.dart`
- Create: `zuralog/lib/core/theme/app_text_styles.dart`
- Create: `zuralog/lib/core/theme/app_dimens.dart`
- Create: `zuralog/lib/core/theme/app_theme.dart`

## Steps

1. **Define Colors (`zuralog/lib/core/theme/app_colors.dart`)**

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFFCEE0B8); // Soft Green
  static const Color secondary = Color(0xFFE07A5F); // Warm Terracotta
  
  // Neutral
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundDark = Color(0xFF111827);
  
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2937);
  
  static const Color textMainLight = Color(0xFF111827);
  static const Color textMainDark = Color(0xFFF9FAFB);
}
```

2. **Create Theme Factory (`zuralog/lib/core/theme/app_theme.dart`)**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textMainLight,
    ),
    // Define text theme, button theme, etc.
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textMainDark,
    ),
  );
}
```

## Exit Criteria
- `MaterialApp` in `main.dart` uses `AppTheme.light` and `AppTheme.dark`.
- Toggling system theme updates app UI.
