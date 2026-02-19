# Phase 2.1.2: Reusable Components

**Parent Goal:** Phase 2.1 Design System Setup
**Checklist:**
- [x] 2.1.1 Theme Configuration
- [x] 2.1.2 Reusable Components

---

## What
Build the "Atomic" building blocks of the UI: Custom Buttons, Inputs, and Cards.

## Why
Accelerate screen development in Phase 2.2 by having pre-built, polished components ready to drop in.

## How
Create standalone widgets in `shared/widgets`.

## Features
- **PrimaryButton:** Full-width, rounded corners, loading state.
- **GlassCard:** Frosted glass effect for that "Premium" feel (using `BackdropFilter`).
- **AppTextField:** Custom styled input with validation support.

## Files
- Create: `life_logger/lib/shared/widgets/buttons/primary_button.dart`
- Create: `life_logger/lib/shared/widgets/cards/glass_card.dart`
- Create: `life_logger/lib/shared/widgets/inputs/app_text_field.dart`

## Steps

1. **Create PrimaryButton (`life_logger/lib/shared/widgets/buttons/primary_button.dart`)**

```dart
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  // Uses AppColors.primary, rounded corners (Radius.circular(16))
  // Shows CircularProgressIndicator when isLoading is true
}
```

2. **Create GlassCard (`life_logger/lib/shared/widgets/cards/glass_card.dart`)**

```dart
class GlassCard extends StatelessWidget {
  final Widget child;
  
  // Uses ClipRRect, BackdropFilter (ImageFilter.blur), and Container with semi-transparent color
}
```

## Exit Criteria
- Components compile.
- Visual verification via `HarnessScreen` (create a "Component Gallery" section).
