# iOS Live Activity Setup — Manual Steps

The Dart + Swift code for the workout Live Activity / Dynamic Island is in
place, but the Widget Extension target itself must be added manually in Xcode
(one-time setup per developer machine).

## Why manually?

Xcode's `project.pbxproj` file format is brittle to generate from scripts. This
is the standard flow for iOS extension targets in a Flutter app — `flutter
create` does not scaffold Widget Extensions.

## Steps

1. On a Mac, open the Runner workspace:

   ```bash
   open zuralog/ios/Runner.xcworkspace
   ```

2. In Xcode, **File → New → Target** → pick **Widget Extension** → **Next**.

3. Configure the target:
   - **Product Name:** `ZuralogWorkoutLiveActivity`
   - **Include Configuration Intent:** unchecked
   - **Include Live Activity:** checked
   - **Project:** Runner
   - **Embed in Application:** Runner

4. Xcode will auto-generate three files inside a new `ZuralogWorkoutLiveActivity`
   group. **Delete the auto-generated files** (move them to trash) — we've
   already placed the real sources at `ios/ZuralogWorkoutLiveActivity/`.

5. Add our existing files to the new target:
   - Right-click the `ZuralogWorkoutLiveActivity` group in the Xcode
     navigator → **Add Files to "Runner"**.
   - Select all files inside `ios/ZuralogWorkoutLiveActivity/`:
     - `ZuralogWorkoutLiveActivity.swift`
     - `ZuralogWorkoutLiveActivityBundle.swift`
     - `Info.plist`
   - In the add-files dialog, under **Add to targets**, tick
     `ZuralogWorkoutLiveActivity` only (NOT Runner).

6. Set the extension's deployment target to **iOS 16.1** under the target's
   **General** tab.

7. Bundle identifier for the extension: `com.zuralog.ZuralogWorkoutLiveActivity`
   (or whatever matches `<Runner bundle id>.ZuralogWorkoutLiveActivity`).

8. In the **Runner** target → **General** → **Frameworks, Libraries, and
   Embedded Content**, add **ActivityKit.framework** with status **Optional**
   (so older iOS devices don't hard-fail the load).

9. Build and run on an iPhone 14 Pro simulator or device running iOS 16.1+.

10. Start a workout in the app — the Live Activity should appear on the lock
    screen and (on Dynamic Island devices) in the island.

## Sharing `WorkoutAttributes`

The Live Activity requires an `ActivityAttributes` struct with identical
shape in both:

- The requesting target (Runner) — at
  `ios/Runner/WorkoutLiveActivityBridge.swift`
- The rendering target (Widget Extension) — at
  `ios/ZuralogWorkoutLiveActivity/ZuralogWorkoutLiveActivity.swift`

If you change one, change the other. ActivityKit matches by struct shape, not
by type identity — the codec will silently fail if the two drift.

## Troubleshooting

### Activity does not appear
Check both system toggles:
- **Settings → Face ID & Passcode → Allow Access When Locked → Live Activities**
- **Settings → Face ID & Passcode → Live Activities** (device-wide)

Also verify `NSSupportsLiveActivities` is set to `true` in `Runner/Info.plist`.

### Build fails with "`WorkoutAttributes` redeclared"
You included `WorkoutLiveActivityBridge.swift` in the extension target by
mistake. The bridge file belongs only to Runner; the extension has its own
copy of the struct. In Xcode, select
`Runner/WorkoutLiveActivityBridge.swift` → **File Inspector** → **Target
Membership** and tick only **Runner**.

### Build fails with "`WorkoutAttributes` missing"
`ActivityKit` framework isn't linked. In Xcode, **Runner target** → **General**
→ **Frameworks, Libraries, and Embedded Content** → **+** → add
`ActivityKit.framework` (status: Optional).

### Runner builds but no channel response (`MissingPluginException`)
The Dart side catches this and logs silently — app behaviour is unaffected.
It means the extension target isn't registered yet; re-do the steps above.
You can confirm by checking Xcode's console for
`[LiveActivity] Runner registered channel`.

### Dynamic Island doesn't show but lock screen does
Dynamic Island only exists on iPhone 14 Pro, 15 Pro, 16 (all), and later.
Older devices correctly show only the lock-screen presentation — nothing
to fix.
