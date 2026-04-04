# ZuraLog App Navigation — Coach Reference

## When to use this skill
Use this skill when the user asks where to find a feature, how to do something in the app, or needs guidance navigating ZuraLog.

---

## App Structure

ZuraLog has five tabs in the bottom navigation bar, plus a side panel accessible by tapping the profile avatar in the top-left corner of any screen.

- **Today** — what's happening right now
- **Data** — full health history and metrics
- **Coach** — conversation with Zura
- **Progress** — goals, streaks, achievements, journal
- **Trends** — auto-discovered patterns across metrics
- **Side panel** — Profile and Settings (not a tab)

---

## Today Tab

The home screen — answers "How am I doing today?"

- **Daily metric grid** — key numbers at a glance: steps, sleep, heart rate, calories, and any other tracked metrics
- **Quick logs** — tap to record water intake, mood, energy level, or a workout without leaving the tab
- **AI insight cards** — short, plain-language observations about the user's patterns (pre-computed daily, not real-time)
- **Notification history** — past app alerts visible here

---

## Data Tab

The full health picture — answers "What does my data actually look like?"

- **Health dashboard** — all connected sources merged into one view; data is deduplicated across apps
- **Category drill-down** — explore by category: sleep, activity, heart health, nutrition, weight, and more
- **Metric history** — charts across any time range (daily, weekly, monthly)
- **Health score** — a single composite number reflecting overall health based on what the user tracks

---

## Coach Tab

The conversation interface — answers "What should I do about my health?"

- **Idle state** — shows the Zura mascot, a time-adaptive greeting, and three quick-start suggestion cards
- **Conversation state** — scrollable chat thread; user messages on the right, Zura's responses on the left with markdown support
- **Ghost Mode** — optional state (toggled in settings) where nothing is saved; a persistent banner confirms the mode is active
- **Artifact cards** — inline cards that appear when Zura suggests saving a memory, creating a journal entry, or showing a data visualization
- Coach personality, proactivity, and response length are set in Settings → Coach Preferences

---

## Progress Tab

Goals and motivation — answers "Am I making progress toward what matters to me?"

- **Goals** — health targets the user has set; shows current progress and weekly comparisons
- **Streaks** — consistency rewards; counts consecutive days meeting a goal
- **Achievements** — milestone markers: first time hitting a goal, personal bests, long streaks
- **Weekly report** — summary of the user's performance across the past week
- **Journal** — private written reflections; can also start a guided AI conversation to process thoughts
- Zura can read journal entries and goal progress through its available tools

---

## Trends Tab

Hidden patterns — answers "What patterns am I missing?"

- **Correlation cards** — each card links two metrics (e.g. sleep duration → resting heart rate) with a plain-language explanation
- Correlations are auto-computed by the system; the user does not configure them
- Requires at least one week of data before anything appears; patterns grow richer over months
- This tab loads instantly — correlations are pre-computed, not real-time

---

## Settings

Accessed by tapping the profile avatar (top-left) → Settings. Not a bottom tab.

- **Account & Profile** — name, photo, birthday, height, gender, email, password, emergency health info, account deletion
- **Integrations** — connect and manage fitness apps and wearables; each shows sync status and can be disconnected; upcoming integrations shown as "coming soon"
- **Notifications** — fine-grained control over every alert type; includes quiet hours
- **Coach Preferences** — personality (tough / balanced / gentle), proactivity level, response length; Memory management (view, delete, or toggle stored facts)
- **Appearance** — dark/light/system theme, haptic feedback, tooltips
- **Privacy & Data** — view or delete AI-stored data, export all data, analytics opt-out, privacy policy
- **Subscription** — current plan, upgrade, restore purchases, billing history

---

## Profile

Accessed by tapping the profile avatar (top-left). Shows the user's name, photo, and a shortcut into Settings. This is also where Ghost Mode can be toggled.
