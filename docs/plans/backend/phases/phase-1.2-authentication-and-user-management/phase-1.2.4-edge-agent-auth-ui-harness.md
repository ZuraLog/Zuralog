# Phase 1.2.4: Edge Agent Auth UI Harness

**Parent Goal:** Phase 1.2 Authentication & User Management
**Checklist:**
- [x] 1.2.1 Cloud Brain Auth Endpoints
- [x] 1.2.2 User Sync to Local Database
- [x] 1.2.3 Edge Agent Auth Repository
- [ ] 1.2.4 Edge Agent Auth UI Harness
- [ ] 1.2.5 Token Refresh Logic

---

## What
Update the Developer UI Harness to include functional text fields and buttons for testing registration, login, and logout.

## Why
We need to manually verify that the entire authentication flow works end-to-end (Flutter -> Network -> Cloud Brain -> Supabase -> DB) before proceeding to build complex features that require an authenticated user.

## How
Add Material `TextField` widgets for email and password, and `ElevatedButton` widgets wired to the `AuthRepository` methods. Display success/error messages in the output console.

## Features
- **Manual Login:** Verify credentials and token storage.
- **Feedback Loop:** Immediate visual confirmation of auth status.
- **State Testing:** Verify that "isLoggedIn" state updates correctly.

## Files
- Modify: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Add login UI to harness**

```dart
class _HarnessScreenState extends ConsumerState<HarnessScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _outputController = TextEditingController();
  bool _isLoggedIn = false;
  
  void _handleLogin() async {
    final authRepo = ref.read(authRepositoryProvider);
    final success = await authRepo.login(
      _emailController.text,
      _passwordController.text,
    );
    
    setState(() {
      _isLoggedIn = success;
      _outputController.text = success 
          ? 'LOGIN SUCCESS: Token saved'
          : 'LOGIN FAILED: Check credentials';
    });
  }

  void _handleRegister() async {
     final authRepo = ref.read(authRepositoryProvider);
     final success = await authRepo.register(
       _emailController.text,
       _passwordController.text,
     );
     setState(() {
       _isLoggedIn = success;
       _outputController.text = success
          ? 'REGISTER SUCCESS: User created & Token saved'
          : 'REGISTER FAILED';
     });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST HARNESS - NO STYLING')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             // ... previous command buttons using Wrap ...
            
             const Divider(),
             const Text('AUTH'),
             TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
             TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password')),
             Row(children: [
               ElevatedButton(onPressed: _handleLogin, child: const Text('Login')),
               const SizedBox(width: 8),
               ElevatedButton(onPressed: _handleRegister, child: const Text('Register')),
             ]),
             
             // ... output fields ...
          ],
        ),
      ),
    );
  }
}
```

## Exit Criteria
- Harness allows entering email/password and logging in.
- UI reflects login success/failure.
