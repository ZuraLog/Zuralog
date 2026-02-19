# View Design Document: Life Logger Mobile App

**Version:** 1.1
**Date:** February 18, 2026
**Status:** Draft
**Theme:** "Sophisticated Softness" (Apple-Style Health) — Light & Dark Mode Supported

---

## 1. Design System

### 1.1 Color Palette
The app supports both Light and Dark modes, adhering to the user's system preference by default.

| Role | Color Name | Light Mode Hex | Dark Mode Hex | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Primary** | **Sage Green** | `#CFE1B9` | `#CFE1B9` | Main actions, active states, brand identity. |
| **Secondary** | **Muted Slate** | `#5B7C99` | `#7DA4C7` | Secondary buttons, info icons, graphs. |
| **Accent** | **Soft Coral** | `#E07A5F` | `#FF8E72` | Alerts, destructive actions. |
| **Background** | **Base** | `#FAFAFA` | `#000000` | Main app background (OLED Black in Dark Mode). |
| **Surface** | **Card/Sheet** | `#FFFFFF` | `#1C1C1E` | Cards, modals, bottom sheets. |
| **Text Primary** | **Content** | `#1C1C1E` | `#F2F2F7` | Headings, body text. |
| **Text Secondary** | **Subtext** | `#8E8E93` | `#8E8E93` | Subtitles, captions, disabled states. |
| **Border** | **Separator** | `#E5E5EA` | `#38383A` | Dividers, card borders. |

### 1.2 Typography
**Font Family:** SF Pro Display (iOS) / Inter (Android).
*   **H1 (Large Title):** 34pt, Bold.
*   **H2 (Title 2):** 22pt, Semibold.
*   **H3 (Headline):** 17pt, Semibold.
*   **Body:** 17pt, Regular.
*   **Caption:** 12pt, Medium.

### 1.3 UI Components
*   **Cards:** 24px corner radius.
    *   *Light:* Soft diffusion shadow (`0px 4px 20px rgba(0,0,0,0.05)`).
    *   *Dark:* No shadow, 1px border (`#38383A`) or slightly lighter surface (`#1C1C1E`).
*   **Buttons:**
    *   *Primary:* Pill-shaped, Solid Sage Green, Dark Grey Text (always).
    *   *Secondary:* Translucent Grey (Light `#F2F2F7` / Dark `#2C2C2E`), Content Text.
*   **Inputs:** Minimalist with Sage Green cursor/caret.

---

## 2. Navigation Architecture

**Pattern:** Bottom Tab Bar + Stack Navigation.

*   **Tab 1: Dashboard ("Home")**
*   **Tab 2: Chat ("Coach")**
*   **Tab 3: Integrations ("Apps")**
*   **Profile/Settings:** Accessed via Avatar in Dashboard Header.

---

## 3. Detailed View Specifications

### 3.1 Onboarding Flow (The First Impression)

**Goal:** Build trust and explain the "Zero-Friction" value prop.

**Common Elements:**
*   Background adapts to system theme.
*   "Skip" button (top right).
*   "Next" button (bottom, floating).

**Screens:**
1.  **Welcome:**
    *   *Visual:* Large, abstract 3D render of a Sage Green loop.
    *   *Text:* "Your Health, Unified."
    *   *Action:* "Get Started" (Primary Button).
2.  **Value Prop 1 (Connections):**
    *   *Visual:* Icons of Strava, Oura, Apple Health floating into a central hub.
    *   *Text:* "Connect the apps you love. We handle the rest."
3.  **Value Prop 2 (Intelligence):**
    *   *Visual:* A chat bubble saying "I noticed you slept well..."
    *   *Text:* "AI Coaching that actually knows you."
4.  **Auth Selection:**
    *   *Layout:* Vertical stack of buttons.
    *   *Buttons:* "Continue with Apple", "Continue with Google".
    *   *Footer:* Terms & Privacy (small text).

---

### 3.2 Dashboard View ("The Command Center")

**Goal:** Immediate status awareness ("Am I on track or off track?").

**Header:**
*   **Left:** "Good Morning, [Name]" (H1).
*   **Right:** Profile Avatar (Circle). Tapping opens Settings Modal.

**Content (Scrollable):**

1.  **Hero Insight Card (Dynamic):**
    *   *Context:* Based on the most critical daily update.
    *   *Visual:*
        *   *Light:* Soft gradient background (White -> faint Sage Green).
        *   *Dark:* Dark gradient (`#1C1C1E` -> faint Sage Green tint).
    *   *Content:* "You're 200 calories over your target, but your 5K run balanced it out."
    *   *Interaction:* Tapping opens Chat with this context pre-filled.

2.  **Health Rings (The 'North Star'):**
    *   *Visual:* Three concentric rings (Sage Green = Activity, Muted Slate = Sleep, Soft Coral = Nutrition).
    *   *Data:* Center text shows primary metric.

3.  **Integrations Rail:**
    *   *Layout:* Horizontal scroll of pill-shaped cards.
    *   *State (Connected):* Icon + Green Dot + "Synced".
    *   *Visual:* Light: White pill / Dark: `#1C1C1E` pill.
    *   *Action:* Tapping deep-links to the respective app.

4.  **Metrics Grid (Bento Style):**
    *   *Card 1 (Sleep):* Moon Icon + "7h 42m" + "85 Score".
    *   *Card 2 (Recovery):* Waveform graph + "High Readiness".
    *   *Card 3 (Weight):* "165.4 lbs" + Trend Arrow (Down).

---

### 3.3 Chat Interface ("The Neural Coach")

**Goal:** Zero-friction logging and reasoning.

**Header:**
*   **Title:** "Coach" (H2).
*   **Status:** Pulsing Green Dot ("Online").
*   **Action:** "Flash" icon (for Quick Actions).

**Chat Stream:**
*   **Empty State:** "Ask me anything about your health..." (Suggestion chips adapt to theme).
*   **User Message:** Sage Green bubble, right-aligned. text-color: `#1C1C1E`.
*   **AI Message:**
    *   *Light:* Light Grey bubble (`#F2F2F7`), text `#1C1C1E`.
    *   *Dark:* Dark Grey bubble (`#2C2C2E`), text `#F2F2F7`.
    *   *Streaming:* Smooth text rendering.
*   **Rich Widgets (Embedded in Chat):**
    *   *Run Summary:* Map thumbnail + Duration + Distance.
    *   *Food Log:* List of items + Total Calories.
    *   *Confirmation:* Green checkmark animation "Logged to Apple Health".

**Input Bar (Sticky Bottom):**
*   **Left:** "+" Button.
*   **Center:** Text Field "Type a message..." (Background adapta to theme).
*   **Right:** Microphone Icon (Sage Green).

---

### 3.4 Integrations Hub

**Goal:** Manage connections and troubleshoot sync.

**Layout:** List View (Table).

**Row Item:**
*   **Icon:** App Logo.
*   **Title:** App Name.
*   **Subtitle:** "Last synced: 2m ago" or "Not connected".
*   **Action:** Toggle Switch (Sage Green on active).
    *   *On Toggle On:* Opens OAuth Web View.
    *   *On Toggle Off:* Confirm disconnect modal.

**Sections:**
*   **Connected:** Active apps.
*   **Available:** Disconnected apps supported by MVP.
*   **Coming Soon:** Visual roadmap.

---

### 3.5 Settings & Profile (Modal)

**Goal:** User preferences and account management.

**Sections:**
1.  **Appearance:**
    *   *Theme Selector:* "System" (Default) | "Light" | "Dark".
2.  **Profile:**
    *   Name, Email.
    *   Physical Stats (Weight, Height, Age, Gender).
3.  **Coach Persona:**
    *   *Selector:* "Gentle" vs "Balanced" vs "Tough Love".
4.  **Data & Privacy:**
    *   "Export My Data".
    *   "Delete Account".
    *   "HealthKit Permissions".
5.  **Subscription:**
    *   "Manage Pro Subscription".

---

## 4. Interaction Models

### 4.1 "Zero-Friction" Logging
*   **Scenario:** User says "I ate a banana."
*   **Feedback:** Immediate "optimistic" message in chat.
*   **Background:** Edge Agent writes to HealthKit.
*   **Confirmation:** Message updates to checked state.

### 4.2 Voice Mode
*   **Trigger:** Tap Microphone in Chat.
*   **Visual:** Full-screen overlay or expanded bottom sheet.
    *   *Light:* Blur over white.
    *   *Dark:* Blur over black.
    *   *Animation:* Sage Green waveform.

---

## 5. Technical Constraints & Edge Cases

*   **Offline Mode:**
    *   Chat: Read-only access to history (cached in SQLite).
    *   Dashboard: Shows last known cached data.
*   **Sync Latency:**
    *   Integrations Rails must handle "Syncing..." state gracefully.
