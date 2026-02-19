# Phase 2.2.1: Welcome & Auth Screen

**Parent Goal:** Phase 2.2 Screen Implementation (Wiring)
**Checklist:**
- [x] 2.2.1 Welcome & Auth Screen
- [ ] 2.2.2 Coach Chat Screen
- [ ] 2.2.3 Dashboard Screen
- [ ] 2.2.4 Integrations Hub Screen
- [ ] 2.2.5 Settings Screen

---

## What
The first screen the user sees. It greets them and provides options to Register or Log In.

## Why
First impressions matter. It needs to be clean, fast, and immediately explain the value prop ("Your AI Life Coach").

## How
Use `Scaffold` with a gradient background (from Design System) and `PrimaryButton` widgets.

## Features
- **Hero Image:** A welcoming illustration or logo.
- **Form Validation:** Email/Password validation using `flutter_form_builder` or simple `TextFormField`.
- **Loading State:** Buttons show spinners during API calls.
- **Error Handling:** SnackBar displays auth errors (e.g., "Invalid credentials").

## Files
- Create: `life_logger/lib/features/auth/presentation/welcome_screen.dart`
- Create: `life_logger/lib/features/auth/presentation/login_form.dart`
- Create: `life_logger/lib/features/auth/presentation/register_form.dart`

## Steps

1. **Create Welcome Screen (`life_logger/lib/features/auth/presentation/welcome_screen.dart`)**

```dart
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.background),
        child: Padding(
            padding: EdgeInsets.all(AppDimens.paddingLarge),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    LogoWidget(),
                    SizedBox(height: 48),
                    PrimaryButton(label: "Get Started", onPressed: () => _showRegister(context)),
                    SizedBox(height: 16),
                    TextButton(child: Text("I already have an account"), onPressed: () => _showLogin(context)),
                ]
            )
        )
      )
    );
  }
}
```

2. **Wire up Auth Logic**
   - Use `ref.read(authRepositoryProvider).login(...)`.
   - On success, navigate to `/dashboard`.

## Exit Criteria
- User can enter credentials.
- Successful login redirects to Dashboard.
