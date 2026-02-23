# View Design Document: Zuralog Mobile App

**Version:** 2.0
**Date:** February 23, 2026
**Status:** Active — Enforced
**Theme:** "Sophisticated Softness" (Apple-Style Health) — Light & Dark Mode Supported

> [!IMPORTANT]
> **This document is the single source of truth for all UI decisions.**
> Every screen, widget, and component MUST conform to the rules defined here.
> Deviating from this document without updating it first is treated as a bug.
> See also: AGENTS.md Rule 21.

---

## 1. Design System

### 1.1 Color Palette

The app supports both Light and Dark modes, honouring the user's system preference by default.

| Role | Token | Light Mode | Dark Mode | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Primary** | `AppColors.primary` | `#CFE1B9` | `#CFE1B9` | Main actions, active states, brand identity (Sage Green). |
| **Secondary** | `AppColors.secondary` | `#5B7C99` | `#7DA4C7` | Secondary buttons, info icons, graphs (Muted Slate). |
| **Accent** | `AppColors.accent` | `#E07A5F` | `#FF8E72` | Alerts, destructive actions (Soft Coral). |
| **Background** | `AppColors.backgroundLight/Dark` | `#FAFAFA` | `#000000` | **Scaffold background only.** OLED black in dark. |
| **Surface** | `AppColors.surfaceLight/Dark` | `#FFFFFF` | `#1C1C1E` | Cards, modals, bottom sheets, drawers. |
| **Text Primary** | `AppColors.textPrimary` (via theme) | `#1C1C1E` | `#F2F2F7` | Headings, body text. |
| **Text Secondary** | `AppColors.textSecondary` | `#8E8E93` | `#8E8E93` | Subtitles, captions, disabled. |
| **Border** | `AppColors.border` | `#E5E5EA` | `#38383A` | Dividers, card borders (dark mode only). |

#### Colour Usage Rules (Non-Negotiable)

1. **`scaffoldBackgroundColor`** — ALL `Scaffold` widgets across ALL screens must use `Theme.of(context).scaffoldBackgroundColor`. Never override with `colorScheme.surface`, `Colors.black`, or any hardcoded hex.
2. **`colorScheme.surface`** — Used exclusively for cards, bottom sheets, modals, side panels, and dialogs.
3. **No hardcoded hex values in widget files.** Always reference `AppColors.*` tokens or `Theme.of(context)` properties.
4. **Green (`AppColors.primary`) is reserved for:** active/connected badges, primary CTA buttons, the activity ring, and success states. It must NEVER appear on inactive elements, "Connect" buttons, or decorative chips.

---

### 1.2 Typography

**Font Family:** SF Pro Display (iOS) / Inter (Android) — resolved automatically via platform theme.

| Style Token | Size | Weight | Usage |
| :--- | :--- | :--- | :--- |
| `AppTextStyles.h1` | 34pt | Bold | Large titles (dashboard greeting). |
| `AppTextStyles.h2` | 22pt | Semibold | Section headings, screen titles. |
| `AppTextStyles.h3` | 17pt | Semibold | Card titles, list headers. |
| `AppTextStyles.body` | 17pt | Regular | Body text, descriptions. |
| `AppTextStyles.caption` | 12pt | Medium | Labels, timestamps, captions. |

**Typography Rules:**
- Use only `AppTextStyles.*` tokens — never create ad-hoc `TextStyle(...)` objects in widget files.
- Heading hierarchy must be respected in order: H1 → H2 → H3 → Body → Caption.

---

### 1.3 UI Components

#### Cards
- `borderRadius: BorderRadius.circular(24)` on all `Card`/`Container` cards.
- *Light mode:* Soft diffusion shadow `BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 4))`.
- *Dark mode:* No shadow; 1px `AppColors.border` stroke; no elevation.
- Background: `Theme.of(context).colorScheme.surface`.

#### Buttons
- **Primary action:** Pill-shaped `FilledButton` with `AppColors.primary` background and dark grey text (`AppColors.textPrimary` light).
- **Secondary / Connect (unconnected):** Neutral pill — `TextButton.icon`, `StadiumBorder`, `onSurface` background at 8% opacity, `onSurface` text colour, `+` icon prefix, ~30px height. **Never green.**
- **Connected / success badge:** `AppColors.primary` green dot or chip. Green only here.
- **Destructive:** `AppColors.accent` (Soft Coral).

#### Inputs
- Minimalist style with `AppColors.primary` cursor/caret.
- Background: `colorScheme.surface` (never scaffold background).

#### Bottom Sheets & Modals
- Background: `colorScheme.surface`.
- Corner radius: 24px top corners.

#### Side Panel / Drawer
- Background: `colorScheme.surface`.
- Width: 280–300px (slides in from the right).
- Never use `scaffoldBackgroundColor` for the panel itself.

---

## 2. Navigation Architecture

**Pattern:** Bottom Tab Bar (frosted glass) + Stack Navigation + Right-side Profile Panel.

| Tab | Route | Label |
| :--- | :--- | :--- |
| 0 | `/dashboard` | Home |
| 1 | `/chat` | Coach |
| 2 | `/integrations` | Apps |

**Profile / Settings access:** Tapping the avatar in the Dashboard header opens a **right-side slide-in panel** (not a full-screen push). The panel contains navigation links: Profile, Settings, and Sign Out.

**Full-screen routes (pushed over shell):**
- `/settings` — Full settings screen.
- `/profile` — Profile screen (if added).

---

## 3. Detailed View Specifications

### 3.1 Onboarding Flow

**Goal:** Build trust and explain the "Zero-Friction" value prop.

**Background:** Uses `scaffoldBackgroundColor` (adapts to system theme).

**Common Elements:**
- "Skip" button (top right).
- "Next" pill button (bottom, `AppColors.primary` filled).

**Screens:**
1. **Welcome:** Large Sage Green 3D loop visual. "Your Health, Unified." → "Get Started" primary button.
2. **Value Prop 1:** Icons of Strava, Oura, Apple Health floating into a central hub.
3. **Value Prop 2:** Chat bubble "I noticed you slept well..." — "AI Coaching that actually knows you."
4. **Auth Selection:** Vertical stack — "Continue with Apple", "Continue with Google". Footer: Terms & Privacy.

---

### 3.2 Dashboard ("The Command Center")

**Scaffold background:** `Theme.of(context).scaffoldBackgroundColor` — same in light (`#FAFAFA`) and dark (`#000000`).

**Header:**
- **Left:** Time-sensitive greeting "Good Morning/Afternoon/Evening, [Name]" in `AppTextStyles.h2` or larger. Name in `AppColors.primary`.
- **Right:** `CircleAvatar` (profile photo or initials). Tapping opens the **Profile Side Panel** (right-side slide-in, NOT a full navigation push).

**Content (Scrollable SliverList):**

1. **AI Insight Strip:** Compact left-border accent (`AppColors.primary`, 3px). Italic body text. `colorScheme.surface` background. Tapping opens Chat with context.
2. **Hero Row:** `ActivityRings` (constrained 180px wide, `Wrap` for pill row) left + 3 key stats (Steps / Sleep / Calories) stacked right.
3. **Metrics Grid (Bento 2×2):** Sleep, Recovery, Weight, Nutrition cards. Each uses `colorScheme.surface`.
4. **Connected Apps Rail:** Horizontal scroll of pill-shaped integration chips at the bottom. Light: white pill / Dark: `#1C1C1E` pill.

---

### 3.3 Chat Interface ("The Neural Coach")

**Scaffold background:** `scaffoldBackgroundColor`.

**Header:** "Coach" (H2), pulsing green online dot, flash icon.

**Chat Stream:**
- Empty state: suggestion chips (surface background).
- User message: `AppColors.primary` bubble, right-aligned, dark text.
- AI message: `colorScheme.surface` bubble, theme-appropriate text.

**Input Bar (sticky bottom):** "+" | Text field | Microphone (sage green). Background: `colorScheme.surface`.

---

### 3.4 Integrations Hub

**Scaffold background:** `scaffoldBackgroundColor`.

**Layout:** SliverList with sections: Connected, Available, Coming Soon.

**Row Item:**
- Icon: Brand logo (`IntegrationLogo` widget with `id` parameter).
- Title (H3) + Subtitle caption.
- State indicator: Connected → green dot + "Synced". Disconnected → neutral `_ConnectButton` pill.

**Platform Visibility:**
- Apple Health: iOS only.
- Google Health Connect: Android only.

---

### 3.5 Profile Side Panel

**Trigger:** Tapping the avatar in the Dashboard header.

**Layout:** Right-side slide-in overlay (280px wide). Background: `colorScheme.surface`. Rounded left corners (24px). Semi-transparent dark scrim behind.

**Contents:**
1. **User section (top):** Profile photo (placeholder with edit icon overlay) + display name + email.
2. **Navigation links:**
   - Profile / Edit Profile → opens Settings screen at profile section.
   - Settings → pushes `/settings`.
   - (Future: Subscription, Help & Support.)
3. **Sign Out** (bottom, destructive — `AppColors.accent` text).

---

### 3.6 Settings Screen

**Scaffold background:** `scaffoldBackgroundColor`.

**User Header:** Profile photo (placeholder, tappable to change) + display name (from `userProfileProvider` `.aiName`) + email + "Member since".

**Sections:**
1. Appearance — Theme Selector (System / Light / Dark).
2. Profile — Name, Email, Physical Stats (Weight, Height, Age, Gender).
3. Coach Persona — Gentle / Balanced / Tough Love.
4. Data & Privacy — Export, Delete Account, HealthKit Permissions.
5. Subscription — Manage Pro.

---

## 4. Interaction Models

### 4.1 "Zero-Friction" Logging
- User says "I ate a banana." → Optimistic message in chat → Edge Agent writes to HealthKit → Message updates to checked state.

### 4.2 Voice Mode
- Trigger: Tap Microphone in Chat.
- Full-screen overlay. Light: blur over white. Dark: blur over black. Sage Green waveform animation.

---

## 5. Technical Rules

### 5.1 Background Consistency
All `Scaffold` widgets in this app must set `backgroundColor` as follows:

```dart
// CORRECT — use in every Scaffold
backgroundColor: Theme.of(context).scaffoldBackgroundColor,

// WRONG — never do this on a Scaffold
backgroundColor: Theme.of(context).colorScheme.surface,
backgroundColor: Colors.black,
backgroundColor: const Color(0xFF1C1C1E),
```

Cards, bottom sheets, side panels, and modals use `colorScheme.surface`.

### 5.2 Offline Mode
- Chat: Read-only access to history (cached in SQLite).
- Dashboard: Shows last known cached data with "last updated" timestamp.

### 5.3 Sync Latency
- Integrations rail must handle "Syncing..." state gracefully with a shimmer or subtle loading indicator.
