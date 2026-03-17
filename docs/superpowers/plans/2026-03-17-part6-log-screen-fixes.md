# Part 6 Log Screen Fixes — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four targeted bugs and missing features across the Sleep, Run, Meal, and Symptom full-screen log screens.

**Architecture:** All changes are confined to three existing Flutter screen files and one widget file — no new files, no new providers, no schema changes. The Run screen gets a session-scoped km/mi toggle that reads `unitsSystemProvider` as its default. The Meal screen gets a custom calorie `TextEditingController` in quick mode. Sleep and Symptom get single-line logic corrections.

**Tech Stack:** Flutter 3 / Dart 3, Riverpod 2, `ConsumerStatefulWidget`, `SharedPreferences` (already imported where needed), `unitsSystemProvider` from `settings/providers/settings_providers.dart`.

---

## Chunk 1: Two one-line correctness fixes (Sleep + Symptom)

These are the cheapest changes. Do them first so they can be committed and out of the way before the more complex work begins.

### Files

- Modify: `zuralog/lib/features/today/presentation/log_screens/sleep_log_screen.dart` (lines 64–71)
- Modify: `zuralog/lib/features/today/presentation/log_screens/symptom_log_screen.dart` (line 105)

---

### Task 1: Fix Sleep screen overnight duration display

**Problem:** `_formatDuration()` at line 66 computes `_wakeTime!.difference(_bedtime!).inMinutes`. For overnight sleep (e.g. bedtime 11 pm, wake 7 am) this returns a negative number and the method returns `'Invalid range'`. The save path (`_canSave` and `_save`) already corrects for overnight by adding `24 * 60` when `mins < 0`, but `_formatDuration` does not.

**File:** `zuralog/lib/features/today/presentation/log_screens/sleep_log_screen.dart`

- [ ] **Step 1: Open the file and locate `_formatDuration` (line 64)**

  Current code:
  ```dart
  String _formatDuration() {
    if (_bedtime == null || _wakeTime == null) return '';
    final mins = _wakeTime!.difference(_bedtime!).inMinutes;
    if (mins <= 0) return 'Invalid range';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }
  ```

- [ ] **Step 2: Replace with overnight-aware version**

  Replace the body of `_formatDuration` so it applies the same +24h correction that `_canSave` and `_save` already use:
  ```dart
  String _formatDuration() {
    if (_bedtime == null || _wakeTime == null) return '';
    int mins = _wakeTime!.difference(_bedtime!).inMinutes;
    if (mins < 0) mins += 24 * 60;   // overnight: wake is next calendar day
    if (mins <= 0) return '';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }
  ```

  Note: Return `''` (empty) rather than `'Invalid range'` for the `mins <= 0` edge case — this matches the `_canSave` guard (which already blocks Save when duration is 0) and avoids showing confusing text to the user.

- [ ] **Step 3: Hot-reload and manually verify**

  Open the Sleep screen in the app. Set bedtime to 11:00 PM and wake time to 7:00 AM. The duration pill should show `8h 0m`. Previously it showed `Invalid range`.

- [ ] **Step 4: Commit**

  ```
  fix: correct overnight sleep duration display in SleepLogScreen
  ```

---

### Task 2: Prevent severity deselection in Symptom screen

**Problem:** In `_SymptomLogScreenState.build`, the severity emoji row uses:
```dart
onTap: () => setState(() => _severityIndex = selected ? null : i),
```
Tapping a selected severity sets `_severityIndex = null`, which disables the Save button — severity is a required field. Once chosen, it should not be deselectable.

**File:** `zuralog/lib/features/today/presentation/log_screens/symptom_log_screen.dart`

- [ ] **Step 1: Locate the severity GestureDetector (lines 102–114)**

  Current code:
  ```dart
  onTap: () => setState(() => _severityIndex = selected ? null : i),
  ```

- [ ] **Step 2: Remove the deselection branch**

  Replace with:
  ```dart
  onTap: () => setState(() => _severityIndex = i),
  ```

  The `selected` local variable (used for sizing the emoji) is still computed above this line and remains correct — only the tap handler changes.

- [ ] **Step 3: Hot-reload and manually verify**

  Open the Symptom screen. Tap "Mild". Tap "Mild" again — it should stay selected (not deselect). Tap "Severe" — severity changes to Severe. Save button remains enabled.

- [ ] **Step 4: Commit**

  ```
  fix: prevent symptom severity from being deselected once chosen
  ```

---

## Chunk 2: Meal screen — custom calorie input + Save label fix

### Files

- Modify: `zuralog/lib/features/today/presentation/log_screens/meal_log_screen.dart`

---

### Task 3: Add custom calorie input in quick mode + fix Save button label

**Background:** Quick mode currently only offers 5 preset calorie chips (`[200, 400, 600, 800, 1000]`). The spec says the user should be able to type a custom value. The design: keep the preset chips as shortcuts, but add a numeric text field above them so the user can type any number. Tapping a preset chip populates the field (and clears it if the chip is tapped again to deselect). Typing directly in the field clears the chip selection.

The Save button currently always shows `'Save Meal'`. In quick mode it should show `'Save'`.

**File:** `zuralog/lib/features/today/presentation/log_screens/meal_log_screen.dart`

- [ ] **Step 1: Add a `_caloriesCtrl` TextEditingController**

  In `_MealLogScreenState`, alongside the existing controllers, add:
  ```dart
  final _caloriesCtrl = TextEditingController();
  ```

  Dispose it in `dispose()`:
  ```dart
  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _caloriesCtrl.dispose();   // add this line
    _notesCtrl.dispose();
    super.dispose();
  }
  ```

- [ ] **Step 2: Remove `_caloriesPreset` and replace with a unified `_calories` int**

  The existing `int? _caloriesPreset` field handles both modes today. Replace it with a single field that represents the entered/chosen calorie value:
  ```dart
  int? _calories;
  ```

  In `_save()` (line 88), change:

  Before:
  ```dart
  caloriesKcal: _caloriesPreset,
  ```
  After:
  ```dart
  caloriesKcal: _calories,
  ```

  The full-mode calorie `ChoiceChip` at lines 168–174 also references `_caloriesPreset` in two places — both the `selected:` check and the `onSelected:` handler. Replace the full-mode calorie chip block (lines 168–174):

  Before:
  ```dart
  children: _kCaloriePresets.map((c) => ChoiceChip(
    label: Text('~$c'),
    selected: _caloriesPreset == c,
    onSelected: (_) => setState(() => _caloriesPreset = c),
  )).toList(),
  ```

  After:
  ```dart
  children: _kCaloriePresets.map((c) => ChoiceChip(
    label: Text('~$c'),
    selected: _calories == c,
    onSelected: (_) => setState(() => _calories = _calories == c ? null : c),
  )).toList(),
  ```

  > Note: Full-mode chips remain toggleable (tap again to deselect). Quick-mode chips use `_onPresetChipTapped` which also syncs the text field — they are separate handlers intentionally.

- [ ] **Step 3: Add a helper to sync text field ↔ chip state**

  Preset chip selection needs to populate the text field; typing in the field needs to clear the chip. Add two helpers:

  ```dart
  void _onCaloriesTyped(String raw) {
    final parsed = int.tryParse(raw.trim());
    setState(() => _calories = parsed);
  }

  void _onPresetChipTapped(int preset) {
    final isDeselecting = _calories == preset;
    setState(() {
      _calories = isDeselecting ? null : preset;
      _caloriesCtrl.text = isDeselecting ? '' : preset.toString();
    });
  }
  ```

- [ ] **Step 4: Update the quick mode UI section**

  Locate the `if (_quickMode) ...` block in `build()` (lines 143–153). 

  Before:
  ```dart
  if (_quickMode) ...[
    const ZSectionLabel(label: 'Calories'),
    const SizedBox(height: AppDimens.spaceSm),
    Wrap(
      spacing: AppDimens.spaceSm,
      children: _kCaloriePresets.map((c) => ChoiceChip(
        label: Text('~$c'),
        selected: _caloriesPreset == c,
        onSelected: (_) => setState(() => _caloriesPreset = c),
      )).toList(),
    ),
  ]
  ```

  Replace it with:

  ```dart
  if (_quickMode) ...[
    const ZSectionLabel(label: 'Calories'),
    const SizedBox(height: AppDimens.spaceSm),
    TextField(
      controller: _caloriesCtrl,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        hintText: 'Enter calories',
        suffixText: 'kcal',
      ),
      onChanged: _onCaloriesTyped,
    ),
    const SizedBox(height: AppDimens.spaceSm),
    Wrap(
      spacing: AppDimens.spaceSm,
      children: _kCaloriePresets.map((c) => ChoiceChip(
        label: Text('~$c'),
        selected: _calories == c,
        onSelected: (_) => _onPresetChipTapped(c),
      )).toList(),
    ),
  ]
  ```

  The full-mode calorie section update was handled in Step 2 above.

- [ ] **Step 5: Fix Save button label**

  Locate the `FilledButton` child at the bottom of `build()`:
  ```dart
  child: _isSaving ? const CircularProgressIndicator.adaptive() : const Text('Save Meal'),
  ```

  Replace with:
  ```dart
  child: _isSaving
      ? const CircularProgressIndicator.adaptive()
      : Text(_quickMode ? 'Save' : 'Save Meal'),
  ```

- [ ] **Step 6: Hot-reload and manually verify**

  - Open Meal screen, enable Quick mode.
  - Type `350` in the calorie field — no chip should be highlighted.
  - Tap the `~400` chip — the field should update to `400` and the chip should highlight.
  - Tap `~400` again — the field should clear and the chip should deselect.
  - Verify Save button reads `'Save'` in quick mode and `'Save Meal'` in full mode.
  - Switch to full mode: tap `~600` → chip highlights; tap again → chip deselects.
  - Save a quick-mode entry with a typed calorie value — should succeed and return to previous screen.

- [ ] **Step 7: Commit**

  ```
  feat: add custom calorie input to Meal quick mode, fix Save label
  ```

---

## Chunk 3: Run screen — km/mi toggle backed by unitsSystemProvider

This is the most significant change. The screen gains a session-scoped unit toggle that:
1. Defaults to the user's global `unitsSystemProvider` setting on open.
2. Lets the user flip between km and mi for this session.
3. Converts mi → km before posting (the backend always stores km).
4. Updates the pace display suffix to match the selected unit.

### Files

- Modify: `zuralog/lib/features/today/presentation/log_screens/run_log_screen.dart`

---

### Task 4: Add session-scoped km/mi toggle to Run screen

**File:** `zuralog/lib/features/today/presentation/log_screens/run_log_screen.dart`

- [ ] **Step 1: Add the settings import**

  The file needs `unitsSystemProvider` and `UnitsSystem`. Add to the import block:
  ```dart
  import 'package:zuralog/features/settings/providers/settings_providers.dart';
  import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
  ```

- [ ] **Step 2: Add `_useMetric` state field**

  In `_RunLogScreenState`, add:
  ```dart
  bool _useMetric = true; // initialised from unitsSystemProvider in initState
  ```

- [ ] **Step 3: Initialise `_useMetric` from the global preference in `initState`**

  Override `initState`:
  ```dart
  @override
  void initState() {
    super.initState();
    // Read the global units preference. This runs once — the toggle is
    // session-scoped and does not write back to the preference.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final units = ref.read(unitsSystemProvider);
      setState(() => _useMetric = units == UnitsSystem.metric);
    });
  }
  ```

  > Why `addPostFrameCallback`: `ref.read` is safe to call in `initState` on a `ConsumerStatefulWidget`, but we wrap the `setState` in a post-frame callback so we don't call `setState` before the first build completes.

- [ ] **Step 4: Update `_distanceKm` getter to convert mi → km when needed**

  Current getter (line 47):
  ```dart
  double? get _distanceKm => double.tryParse(_distanceCtrl.text.trim());
  ```

  Replace with:
  ```dart
  /// Returns the entered distance converted to km regardless of display unit.
  /// This is what gets posted to the API — the backend always stores km.
  double? get _distanceKm {
    final raw = double.tryParse(_distanceCtrl.text.trim());
    if (raw == null) return null;
    return _useMetric ? raw : raw * 1.60934; // mi → km
  }
  ```

- [ ] **Step 5: Update `_formatPace` to show the right unit**

  Current (line 63):
  ```dart
  return '$m:${s.toString().padLeft(2, '0')} / km';
  ```

  Replace with:
  ```dart
  return '$m:${s.toString().padLeft(2, '0')} / ${_useMetric ? 'km' : 'mi'}';
  ```

  The pace *value* (`_calcPaceSecondsPerKm`) is always computed from `_distanceKm` (already-converted km) and `_durationSeconds`, so it is always seconds-per-km. When displaying in imperial mode, we need to convert seconds-per-km → seconds-per-mile. Update `_calcPaceSecondsPerKm`:

  Current (line 56–61):
  ```dart
  int? _calcPaceSecondsPerKm() {
    final distKm = _distanceKm;
    final durSec = _durationSeconds;
    if (distKm == null || distKm == 0 || durSec == null) return null;
    return (durSec / distKm).round();
  }
  ```

  The method is fine as-is (it works on the already-converted km value). Keep `_calcPaceSecondsPerKm()` unchanged — it is still called in `_save()` at line 86 (`avgPaceSecondsPerKm: _calcPaceSecondsPerKm()`) to post sec/km to the backend, which is always metric. Only the *display* needs conversion. Add a display helper alongside it:

  ```dart
  /// Pace in seconds per km (always metric internally).
  int? _calcPaceSecondsPerKm() {
    final distKm = _distanceKm;
    final durSec = _durationSeconds;
    if (distKm == null || distKm == 0 || durSec == null) return null;
    return (durSec / distKm).round();
  }

  /// Pace converted to the display unit.
  int? _calcDisplayPace() {
    final secsPerKm = _calcPaceSecondsPerKm();
    if (secsPerKm == null) return null;
    if (_useMetric) return secsPerKm;
    // A mile is longer than a km, so pace per mile is a larger number — multiply.
    // e.g. 300 sec/km × 1.60934 ≈ 483 sec/mile ≈ 8:03/mi
    return (secsPerKm * 1.60934).round();
  }
  ```

- [ ] **Step 5b: Update the pace display row in `build()` to use `_calcDisplayPace()`**

  Locate line 181 in the source (inside the `if (_activityType != 'Swim')` block):

  Before:
  ```dart
  _formatPace(_calcPaceSecondsPerKm()),
  ```

  After:
  ```dart
  _formatPace(_calcDisplayPace()),
  ```

- [ ] **Step 6: Add the km/mi toggle widget to the distance section**

  Locate the distance `TextField` in `build()` (line ~143). Replace the current `InputDecoration`:

  ```dart
  // Before (hardcoded 'km'):
  decoration: const InputDecoration(hintText: '0.0', suffixText: 'km'),
  ```

  With a Row that puts the toggle to the right of the label:

  Replace the `const ZSectionLabel(label: 'Distance')` + `TextField` block with:
  ```dart
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const ZSectionLabel(label: 'Distance'),
      _UnitToggle(
        useMetric: _useMetric,
        onToggle: () => setState(() => _useMetric = !_useMetric),
      ),
    ],
  ),
  const SizedBox(height: AppDimens.spaceSm),
  TextField(
    controller: _distanceCtrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      hintText: '0.0',
      suffixText: _useMetric ? 'km' : 'mi',
    ),
    onChanged: (_) => setState(() {}),
  ),
  ```

- [ ] **Step 7: Add the `_UnitToggle` private widget at the bottom of the file**

  After the existing `_ModePicker` class, add:
  ```dart
  class _UnitToggle extends StatelessWidget {
    const _UnitToggle({required this.useMetric, required this.onToggle});
    final bool useMetric;
    final VoidCallback onToggle;

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'km',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: useMetric ? FontWeight.w700 : FontWeight.w400,
                  color: useMetric ? AppColors.primary : Colors.grey,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('·', style: TextStyle(color: Colors.grey)),
              ),
              Text(
                'mi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: !useMetric ? FontWeight.w700 : FontWeight.w400,
                  color: !useMetric ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 8: Hot-reload and manually verify**

  - Open the Run screen → tap "Log a past run".
  - Distance field should show `km` by default if the global setting is Metric.
  - Tap the `km · mi` toggle — suffix changes to `mi`, pace display changes to `/ mi`.
  - Type `3.1` miles and set duration to 25:00 (25 min, 0 sec). Pace should show `~8:03–8:04 / mi` (3.1 mi × 1.60934 ≈ 4.99 km; 1500s ÷ 4.99 ≈ 301 sec/km; 301 × 1.60934 ≈ 484 sec/mi = 8:04/mi).
  - Tap Save — check the backend receives `distance_km ≈ 4.99` (not 3.1).
  - Flip the global settings to Imperial, reopen the screen — toggle should default to `mi`.

- [ ] **Step 9: Commit**

  ```
  feat: add session-scoped km/mi toggle to Run log screen
  ```

---

## Chunk 4: Final verification and docs update

### Task 5: End-to-end smoke check

- [ ] **Step 1: Run a Flutter build to confirm zero compile errors**

  ```
  flutter build apk --debug
  ```

  Expected: exits 0 with no errors or warnings about the changed files.

- [ ] **Step 2: Manual smoke check of all four screens**

  | Screen | Check |
  |--------|-------|
  | Sleep | Set 11pm bedtime + 7am wake time → pill shows `8h 0m`, not `Invalid range` |
  | Symptom | Tap Mild, tap again → stays on Mild, Save stays enabled |
  | Meal (quick mode) | Type `350` → no chip highlighted. Tap `~400` → field shows `400`. Save button reads `'Save'` |
  | Meal (full mode) | Save button reads `'Save Meal'` |
  | Run | km/mi toggle defaults to global setting; toggling updates suffix + pace unit; Save posts km to backend regardless of selected display unit |

- [ ] **Step 3: Invoke `docs` subagent to update implementation-status.md**

  Ask the `docs` subagent to add an entry to `docs/implementation-status.md` recording that Part 6 log screen fixes were completed, listing the four changes made.

- [ ] **Step 4: Commit docs update via `git` subagent**

  ```
  docs: record Part 6 log screen fixes in implementation-status
  ```
