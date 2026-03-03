# Zuralog — Design System & Brand Guidelines

**Version:** 3.0  
**Last Updated:** 2026-03-03  
**Status:** Living Document

---

## Design Philosophy

Zuralog's design targets **award-winning premium quality**. The visual language is inspired by Apple Fitness+ — editorial typography, bold color-coded health domains, borderless cards on pure black, and charts that feel alive. The goal is an app people screenshot and share because it *looks* that good.

**Design direction:** Editorial / Typographic — Apple Fitness+ caliber  
**North star apps:** Apple Fitness+, Linear, Opal  
**Design ambition:** Awwwards-level mobile design — not functional-but-forgettable

### Core Principles

1. **Typography carries the design.** Large, confident type with strict hierarchy. If the layout works without color, it works.
2. **Color is semantic, not decorative.** Every color means something — a health category, a state, a brand element. No color without purpose.
3. **Content is the interface.** No visible chrome (borders, shadows, dividers) unless absolutely necessary. Data fills the screen edge-to-edge.
4. **Motion earns its place.** Every animation communicates a state change. Nothing moves just to move.
5. **Black is the canvas.** Pure black backgrounds let OLED screens shine and make every color pop. The app should feel like colored light on darkness.

### What Stays Constant
- Color palette and semantic tokens
- Typography (Inter font family)
- Spacing and border radius conventions
- Category color assignments

### What Should Always Be Explored
- Screen layouts, card arrangements, navigation patterns
- Animation styles and motion choreography
- User flows and information hierarchy
- Component visual treatments

> Never settle for "good enough." Every screen should make the user feel like they're holding something premium.

---

## Color Palette

### Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `sage-green` | `#CFE1B9` | Primary brand accent — buttons, active tab indicator, interactive elements, user chat bubbles |
| `sage-dark` | `#A8C68A` | Pressed states, secondary accent |
| `sage-light` | `#E8F3D6` | Subtle backgrounds, badge fills |

Sage green is the **brand color only**. It never competes with category colors — it is muted and light, while category colors are vivid and saturated. Sage green appears on: primary buttons, active navigation indicators, toggle states, user-sent chat bubbles, and brand marks.

### Health Category Colors

Each of the 10 health categories has a signature color used on cards, charts, icons, progress rings, and category headers. These colors are vivid and designed to pop on pure black backgrounds.

| Category | Token | Hex | Rationale |
|----------|-------|-----|-----------|
| Activity | `category-activity` | `#30D158` | Movement, energy. Apple Move ring convention. |
| Sleep | `category-sleep` | `#5E5CE6` | Night sky, calm, rest. Apple sleep convention. |
| Heart | `category-heart` | `#FF375F` | Heartbeat. Most instinctive health color mapping. |
| Nutrition | `category-nutrition` | `#FF9F0A` | Food, warmth, energy intake. Distinct from Activity green. |
| Body | `category-body` | `#64D2FF` | Neutral, clinical, measurement-oriented. Weight/body comp. |
| Vitals | `category-vitals` | `#6AC4DC` | Medical, precise, trustworthy. SpO2, blood pressure, temperature. |
| Wellness | `category-wellness` | `#BF5AF2` | Mindfulness, holistic. Stress, HRV, recovery. |
| Cycle | `category-cycle` | `#FF6482` | Apple Health cycle tracking convention. |
| Mobility | `category-mobility` | `#FFD60A` | Energy, movement range, flexibility. Bright and active. |
| Environment | `category-environment` | `#63E6BE` | Nature, air quality, UV. Fresh and natural. |

**Usage rules:**
- Category color is used at **full saturation** on charts, progress rings, and active state icons
- Category color at **15–20% opacity** is used as card tint backgrounds when needed for subtle differentiation
- Category color as **text** is used only for metric values and category labels, never for body text
- Two category colors should never appear adjacent at full saturation without a black separator

### Surface Colors (Dark Theme — OLED Black)

| Token | Hex | Usage |
|-------|-----|-------|
| `surface-900` | `#000000` | Primary background — pure OLED black |
| `surface-800` | `#121212` | Card backgrounds, content containers |
| `surface-700` | `#1C1C1E` | Elevated cards, bottom sheets, drawers |
| `surface-600` | `#2C2C2E` | Dividers (used sparingly), disabled states |
| `surface-500` | `#3A3A3C` | Input backgrounds, chips, search bars |

**Note:** Primary background is now `#000000` (true black), upgraded from `#0A0A0A`. This maximizes OLED contrast and makes card backgrounds (`#121212`) clearly distinct without any border.

### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | `#FFFFFF` | Primary text, headlines, metric values |
| `text-secondary` | `#ABABAB` | Secondary text, captions, labels, hints |
| `text-tertiary` | `#636366` | Placeholder text, disabled states, timestamps |
| `text-inverse` | `#000000` | Text on sage-green buttons and light fills |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#34C759` | Connected states, positive deltas, goal completion |
| `warning` | `#FF9500` | Caution states, approaching limits |
| `error` | `#FF3B30` | Error states, disconnected, negative alerts |
| `syncing` | `#007AFF` | Loading/syncing indicators |

---

## Typography

**Font Family:** Inter (all platforms)

The typography system is the backbone of the editorial design language. Headlines are large and confident. Body text is readable and restrained. The contrast between display and body sizes creates the visual hierarchy that carries the entire layout.

### Flutter (AppTextStyles)

| Style | Font Size | Weight | Line Height | Usage |
|-------|-----------|--------|-------------|-------|
| `displayLarge` | 34pt | Bold (700) | 1.1 | Hero numbers (step count, calorie total), screen titles |
| `displayMedium` | 28pt | SemiBold (600) | 1.15 | Section headers, greeting text ("Good morning, Maria") |
| `displaySmall` | 24pt | SemiBold (600) | 1.2 | Card headlines, modal titles |
| `titleLarge` | 20pt | Medium (500) | 1.25 | Card titles, dialog headers |
| `titleMedium` | 17pt | Medium (500) | 1.3 | List item titles, navigation headers |
| `bodyLarge` | 16pt | Regular (400) | 1.5 | Primary body text, AI chat messages |
| `bodyMedium` | 14pt | Regular (400) | 1.45 | Secondary body, descriptions, insight explanations |
| `bodySmall` | 12pt | Regular (400) | 1.4 | Captions, timestamps, metadata, source attribution |
| `labelLarge` | 15pt | SemiBold (600) | 1.2 | Button text, action labels |
| `labelMedium` | 13pt | Medium (500) | 1.2 | Chip text, tab labels, category tags |
| `labelSmall` | 11pt | Medium (500) | 1.2 | Badge text, compact stats, unit labels |

**Key differences from v2.0:**
- `displayLarge` increased from 32pt to 34pt Bold (was SemiBold) — hero numbers need to command the screen
- Added `displaySmall` at 24pt for card headlines
- Added line height specifications for vertical rhythm consistency
- All display styles use tighter line heights (1.1–1.2) for compact, punchy headlines
- Body styles use looser line heights (1.4–1.5) for readability

### Font Assets

Flutter font files declared in `pubspec.yaml` and loaded from `zuralog/assets/fonts/`:
- `Inter-Regular.ttf` (400)
- `Inter-Medium.ttf` (500)
- `Inter-SemiBold.ttf` (600)
- `Inter-Bold.ttf` (700)

---

## Spacing & Shape

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Icon padding, tight gaps |
| `sm` | 8px | Component internal padding |
| `md` | 16px | Standard card padding, element spacing |
| `lg` | 24px | Section spacing, card gaps |
| `xl` | 32px | Screen-level horizontal padding |
| `xxl` | 48px | Major section breaks, top safe area offsets |

### Border Radius

| Context | Radius |
|---------|--------|
| Cards | 20px |
| Buttons | 14px |
| Chips / Tags | 8px |
| Bottom sheets | 28px (top corners only) |
| Progress rings | 50% (circular) |
| Avatars / Icons | 50% (circular) |
| Input fields | 12px |

**Key differences from v2.0:**
- Card radius increased from 16px to 20px — rounder, softer, more modern
- Button radius increased from 12px to 14px to match card proportion
- Bottom sheet radius increased from 24px to 28px for more dramatic reveal

---

## Component Conventions

### Cards

Cards are the primary content container across the app. They are defined by **background color contrast only** — no borders, no shadows, no elevation.

- Background: `surface-800` (`#121212`) on `surface-900` (`#000000`) background
- **No border.** The color difference between `#000000` and `#121212` provides sufficient definition on OLED screens.
- **No shadow.** Flat design; depth is communicated through color layering, not drop shadows.
- Radius: 20px
- Padding: 16px (`md`) internal, 24px (`lg`) gap between cards
- Category cards may use their category color at 8–12% opacity as a subtle background tint to reinforce color coding

**Elevated cards** (bottom sheets, drawers, modals) use `surface-700` (`#1C1C1E`) to create a second level of depth above standard cards.

### Buttons

- **Primary action:** Filled sage-green (`#CFE1B9`) background, black text (`#000000`). Rounded 14px. Scale-down animation on press (0.96x, 100ms).
- **Secondary action:** Transparent background, sage-green text, no border. Hover/press state uses sage-green at 10% opacity as background fill.
- **Destructive action:** Transparent background, `error` red text. Press state uses red at 10% opacity.
- **Ghost:** Transparent background, `text-secondary` color. Lowest emphasis.
- **Category action:** Filled with category color, black text. Used for category-specific CTAs (e.g., "View Sleep Details" uses `category-sleep` fill).

### Metric Value Display

Health metrics use a specific typography pattern to feel data-rich yet readable:

```
[Value]        displayLarge (34pt Bold, white or category color)
[Unit]         labelSmall (11pt Medium, text-secondary)
[Label]        bodySmall (12pt Regular, text-tertiary)
[Delta]        labelMedium (13pt Medium, success/error color with arrow icon)
```

Example: Steps today
```
8,432          ← large, white, bold
steps          ← small, gray
Daily total    ← smaller, darker gray
↑ 12%          ← green, with up arrow
```

### Progress Rings

Inspired by Apple Fitness+ activity rings. Used on the Today feed, Progress tab, and Goal detail screens.

- Stroke width: 10px (large rings), 6px (compact rings)
- Background track: category color at 15% opacity
- Fill: category color at full saturation
- Animated on load: fills from 0 to current value over 800ms with `Curves.easeOutCubic`
- Concentric rings for multi-metric summaries (activity + calories + sleep)

### Charts

- Library: `fl_chart`
- Background: transparent (chart sits directly on card background)
- Grid lines: `surface-600` at 30% opacity — barely visible, just enough for reference
- Data lines/bars: category color at full saturation
- Fill area: category color at 15% opacity (gradient fade to transparent at bottom)
- Animated on load: lines draw left-to-right, bars grow bottom-up (400ms, `Curves.easeOutCubic`)
- Touch interaction: crosshair with value tooltip on long-press/drag
- Time range selector: segmented control (Day / Week / Month / Year) using `surface-500` background with sage-green active indicator

### Chat Bubbles

- **User messages:** Sage-green (`#CFE1B9`) background, black text, right-aligned. Radius: 20px (with 4px bottom-right for tail effect).
- **AI messages:** `surface-700` (`#1C1C1E`) background, white text, left-aligned, markdown-rendered. Radius: 20px (with 4px bottom-left for tail effect).
- **Streaming:** Animated typing indicator using three dots with staggered pulse animation in sage-green.
- **Suggested prompts:** Horizontal scrollable chips below the input bar when conversation is empty. `surface-500` background, `text-secondary` text, sage-green border on tap.

### Integration Tiles (Settings > Integrations)

- Connected state: category-appropriate color dot + "Connected" label in `success` green
- Available state: standard `surface-800` card, white text
- Coming Soon: 40% opacity overall, "Coming Soon" badge in `surface-500`
- Platform badge (iOS only / Android only): small pill in `surface-600`, `labelSmall` text

### Bottom Navigation Bar

- Frosted glass effect retained: `BackdropFilter` with Gaussian blur beneath the nav bar
- Background: `surface-900` at 70% opacity (true black, translucent)
- 5 destinations: Today, Data, Coach, Progress, Trends
- Active tab: sage-green icon + label
- Inactive tab: `text-tertiary` icon + label
- No indicator pill/dot — the color change is sufficient
- Tab switch animation: 200ms cross-fade

### Skeleton Loading States

- Base color: `surface-800` (`#121212`)
- Shimmer highlight: `surface-600` (`#2C2C2E`)
- Animation: horizontal shimmer sweep, 1200ms loop, `Curves.easeInOut`
- Skeleton shapes match the layout of the content they replace (rounded rectangles for text, circles for avatars, card-shaped blocks for cards)

---

## Navigation Structure

> **See [`docs/screens.md`](./screens.md) for the full screen inventory, user intent model, and navigation structure.** The table below is a summary.

**Bottom tab bar (5 tabs):**

| Tab | Icon Concept | Screen | User Intent |
|-----|-------------|--------|-------------|
| Today | sun / calendar-today | Curated daily briefing + insights feed | "What do I need to know right now?" |
| Data | grid / chart-bar | Customizable health dashboard | "Show me MY data, MY way." |
| Coach | chat bubble / sparkle | AI chat (Gemini-style, fresh conversation) | "Help me understand or do something." |
| Progress | target / trophy | Goals, streaks, achievements, journal | "Am I actually getting better?" |
| Trends | trend-up / wave | Correlations, reports, data sources | "Show me the patterns." |

Settings, Profile, Integrations, and Subscription are accessed from header icons or avatar taps — not from the bottom bar.

---

## Dark Theme First

Zuralog is **dark-first** — dark mode is the primary theme and the default experience. A light mode is supported but dark is the priority, as it is the mode most users will use.

**Dark mode (primary):**
- True OLED black (`#000000`) background — pixels turn off entirely on OLED screens for battery savings and visual depth
- Maximum contrast — every category color, every chart, every piece of text pops against pure black
- Premium aesthetic aligned with the editorial design direction
- The Apple Fitness+ and Linear apps both use this approach to great effect

**Light mode (supported):**
- Light mode should feel equally polished, not like an afterthought
- Surface and text color tokens must have light-mode equivalents defined in `AppColors` / `AppTheme`
- Category colors remain the same across both themes — they are designed to work on both light and dark backgrounds
- Sage green brand color remains unchanged

---

## Motion & Animation

### Principles

1. **Purposeful:** Every animation communicates a state change — loading, completion, transition, feedback. Nothing moves for decoration.
2. **Fast:** 200–400ms for most animations. Users should never wait for an animation to finish before they can act.
3. **Physical:** Spring curves and ease-out curves that feel like real objects with mass. No linear animations.
4. **Choreographed:** When multiple elements animate simultaneously (e.g., cards loading in), they should be staggered, not synchronized. Sequential entry (50ms delay per item) creates rhythm.

### Flutter Duration Constants

| Context | Duration | Curve |
|---------|----------|-------|
| Button press (scale) | 100ms | `easeInOut` |
| Tab switch (cross-fade) | 200ms | `easeOut` |
| Card press feedback | 150ms | `easeOut` |
| Screen transition | 300ms | `easeOutCubic` |
| Chart draw-in | 400ms | `easeOutCubic` |
| Progress ring fill | 800ms | `easeOutCubic` |
| Skeleton shimmer | 1200ms (loop) | `easeInOut` |
| Bottom sheet reveal | 350ms | `easeOutCubic` |
| Drawer slide | 280ms | `easeOutCubic` |
| Stagger delay per item | 50ms | — |

### Specific Animation Behaviors

- **Charts:** Animate on first load only (not on tab switch back). Lines draw left-to-right, bars grow bottom-up, rings fill clockwise.
- **Cards:** Subtle scale feedback on press (0.96x scale, 150ms). No bounce — just a clean scale-down and release.
- **Screen transitions:** Slide-up for pushed screens, cross-fade for tab switches. No horizontal slide (feels dated).
- **Pull-to-refresh:** Custom refresh indicator using sage-green circular progress indicator, not the default Material pull indicator.
- **Achievement unlock:** Scale-up from 0 to 1 with a slight overshoot (spring curve), followed by a brief glow pulse in the achievement's color.
- **Drag-and-drop (Data tab):** Lifted card gains a subtle scale-up (1.03x) and shadow to indicate it's "picked up." Other cards smoothly reorder around it with 200ms transition.

### Website

The website uses GSAP + Framer Motion for more expressive marketing animations (hero text reveals, scroll-triggered effects). These are intentionally more theatrical than the mobile app animations.

---

## Dashboard Customization (Data Tab)

The Health Dashboard on the Data tab is the user's personal canvas. Three levels of customization:

### 1. Card Reorder (Drag-and-Drop)
- Long-press a card to enter edit mode
- Drag to reorder; other cards animate to make room
- Release to drop; new order persists to local storage (Drift or SharedPreferences)
- A subtle haptic feedback on pick-up and drop

### 2. Card Visibility (Show/Hide Toggle)
- In edit mode, each card shows a visibility toggle (eye icon)
- Hidden cards are removed from the dashboard entirely
- An "Edit Dashboard" button in the header or a long-press gesture enters edit mode
- At least one card must remain visible (prevent empty state)

### 3. Card Accent Color (Per-Category)
- In Appearance Settings, users can override the default category color for any card
- Color picker offers a curated palette (8–10 presets per category) rather than a free-form color wheel — prevents ugly combinations
- Custom color applies to: card accent elements, sparkline color, icon tint
- Default category colors (defined above) are the starting point; user overrides are stored locally

---

## Brand Assets

All brand assets live in `assets/brand/`. See [architecture.md — ADR 004](./architecture.md#adr-004-asset-strategy-multi-platform-monorepo) for the full asset strategy.

| Asset | Location |
|-------|----------|
| Logo (SVG) | `assets/brand/logo/zuralog-logo.svg` |
| App icon | `assets/brand/icons/` |
| Brand fonts | `assets/brand/fonts/` |
| Flutter copy | `zuralog/assets/` (synced via `scripts/sync-assets.sh`) |
| Website copy | `website/public/` (synced via `scripts/sync-assets.sh`) |

---

## v3.1 — MVP Component Specifications

Added: 2026-03-03. These specifications cover all new MVP components introduced in the Phase 0 design system rebuild.

---

### Light Mode Color Tokens

Light mode is a first-class theme. It mirrors dark mode's information density but replaces black canvases with white and grey surfaces. Category colors are identical in both themes.

| Token | AppColors constant | Light Hex | Dark Hex | Usage |
|-------|--------------------|-----------|----------|-------|
| Scaffold background | `backgroundLight` / `backgroundDark` | `#FFFFFF` | `#000000` | App scaffold (`Scaffold.backgroundColor`) |
| Surface (colorScheme.surface) | `surfaceLight` / `surfaceDark` | `#F2F2F7` | `#1C1C1E` | Elevated surfaces |
| Card background | `cardBackgroundLight` / `cardBackgroundDark` | `#FFFFFF` | `#121212` | Standard cards |
| Elevated surface | `elevatedSurfaceLight` / `elevatedSurfaceDark` | `#FFFFFF` | `#1C1C1E` | Bottom sheets, drawers, modals |
| Input background | `inputBackgroundLight` / `inputBackgroundDark` | `#F2F2F7` | `#1C1C1E` | Text fields, search bars |
| Divider / border | `borderLight` / `borderDark` | `#E5E5EA` | `#38383A` | Dividers, card separators |
| Text primary | `textPrimaryLight` / `textPrimaryDark` | `#000000` | `#F2F2F7` | Headlines, body text |
| Text secondary | `textSecondaryLight` / `textSecondaryDark` | `#636366` | `#8E8E93` | Captions, labels, metadata |
| Text tertiary | `textTertiary` | `#ABABAB` | `#ABABAB` | Placeholders, disabled, timestamps |

**Rules:**
- Category colors are identical in both themes and require no `Light`/`Dark` suffix.
- `AppColors.primary` (Sage Green `#CFE1B9`) is the same in both modes.
- Widget files must never use raw hex — always reference `AppColors.*` constants.

---

### Haptic Feedback Specification

All haptic calls go through `HapticService` (never `HapticFeedback` directly). The service is a no-op when the user disables haptics in Appearance Settings.

| Semantic Type | `HapticService` method | Platform API | Trigger Examples |
|---------------|------------------------|--------------|-----------------|
| Light | `light()` | `HapticFeedback.lightImpact()` | Tab switch, card tap, list selection, tooltip dismiss |
| Medium | `medium()` | `HapticFeedback.mediumImpact()` | Send message, confirm log, toggle setting, Quick Log submit |
| Success | `success()` | `HapticFeedback.heavyImpact()` | Goal reached, streak milestone, achievement unlock, report generated |
| Warning | `warning()` | `HapticFeedback.vibrate()` | Integration disconnect, anomaly alert, destructive action |
| Selection tick | `selectionTick()` | `HapticFeedback.selectionClick()` | Picker scrolls, slider drags, drag handles, segmented control |

**Provider:** `hapticServiceProvider` (Riverpod) — reads `hapticEnabledProvider` (SharedPreferences-backed, default `true`).

---

### Onboarding Tooltip Component

One-time coaching bubbles that surface contextual guidance the first time a user visits each screen.

| Property | Value |
|----------|-------|
| Background | `#3A3A3C` (dark) / `#EBEBF0` (light) |
| Border radius | 12px |
| Padding | 14px horizontal, 10px vertical |
| Max width | 240px |
| Body text | `AppTextStyles.caption` |
| Pointer arrow | 8px equilateral triangle (below bubble by default) |
| Dismiss button | "Got it" — `AppColors.primary` text, w600 |

**State management:** `tooltipSeenProvider` (AsyncNotifier, SharedPreferences-backed). Key format: `'{screenKey}.{tooltipKey}'`. `TooltipSeenNotifier.reset()` for "Reset Tooltips" in Appearance Settings.

**Sequential display:** Only one tooltip is visible per screen at a time. Multiple tooltips on one screen render in order as each is dismissed.

---

### Health Score Widget

Animated ring/gauge component displaying the composite AI health score (0–100).

| Property | Hero variant | Compact variant |
|----------|-------------|-----------------|
| Ring diameter | 120pt | 48pt |
| Stroke width | 12% of diameter (~14.4pt) | 12% of diameter (~5.8pt) |
| Score label | `h1` scaled to ~28% of diameter | `caption` w700 |
| Sparkline | 7-day fl_chart LineChart below ring | — |
| AI commentary | Text below sparkline | — |
| Animation | 800ms `easeOutCubic` fill | 800ms `easeOutCubic` fill |

**Color stops:**

| Score | Color | Token |
|-------|-------|-------|
| 0–39 | Red | `AppColors.healthScoreRed` (`#FF3B30`) |
| 40–69 | Amber | `AppColors.healthScoreAmber` (`#FF9F0A`) |
| 70–100 | Green | `AppColors.healthScoreGreen` (`#30D158`) |

**Track:** category color at 30% opacity (dark) / `borderLight` (light).
**Null score:** renders a `CircularProgressIndicator` stub inside the ring.

---

### Data Maturity Banner

Progressive disclosure banner shown for the user's first 30 days of data collection.

| Property | Value |
|----------|-------|
| Background | `cardBackground` token |
| Border radius | `radiusCard` (20px) |
| Progress bar height | 4px |
| Progress bar fill | `AppColors.primary` (sage green) |
| Progress track | `#3A3A3C` (dark) / `borderLight` (light) |
| Label | "Data maturity: X of Y days" — `caption` style |
| Sub-label | Unlock message — 10pt caption |
| Dismiss button | `Icons.close_rounded` 16px, `textSecondary` color |

**Milestones:** 7 days (correlations unlock), 14 days (anomaly detection), 30 days (full AI insights).
**Persistence:** Dismiss state stored via user preferences. "Re-enable" available in Privacy & Data Settings.

---

### Streak Counter Badge

| Property | Inline variant | Standalone variant |
|----------|---------------|-------------------|
| Flame icon | 16pt | 28pt |
| Count text | `caption` w700 | `h2` |
| Shield icon (freeze active) | ~14pt sage-green | ~24pt sage-green |
| Flame color | `AppColors.healthScoreAmber` (`#FF9F0A`) | `AppColors.healthScoreAmber` |

**Freeze visual:** When `isFrozen: true`, a shield icon (`Icons.shield_rounded`) in `AppColors.primary` appears to the right of the count, indicating a streak freeze is protecting the streak.

**Milestone celebrations:** At 7, 14, 30, 60, 90, 180, 365 days — trigger a `success()` haptic and show a celebration card on the Today Feed.

---

### Quick Log Bottom Sheet

Rapid manual health data entry, launched from the FAB on Today Feed and from Quick Actions.

| Property | Value |
|----------|-------|
| Top border radius | 28px |
| Reveal animation | 350ms `easeOutCubic` |
| Background | `elevatedSurface` token |
| Drag handle | 36px × 4px, `textSecondary` at 40% opacity |

**Sliders (Mood, Energy, Stress):**
- Range: 1–10, 9 divisions
- Track height: 4px
- Color: category-specific (`categoryWellness`, `categoryActivity`, `categoryHeart`)
- Thumb: 8pt radius

**Water counter:**
- Decrement/Increment buttons: 36×36pt, `AppColors.primary` at 15% opacity
- Count: `h2` text
- Minimum: 0 (decrement disabled at 0)

**Symptom chips:** `FilterChip` — selected state uses `AppColors.primary` at 20% fill + primary border.

**Submit bar:** `FilledButton` full-width, 52pt height, `borderRadius: 14`, `AppColors.primary` fill.

---

### Confirmation Card

In-chat card for NL logging, memory extraction, and food photo confirmations.

| Property | Value |
|----------|-------|
| Background | `cardBackground` token |
| Border radius | 20px |
| Header text | `h3` (`AppTextStyles.h3`) |
| Row label | `body` (`AppTextStyles.body`) — `textSecondary` color |
| Row value | `body` w600 — `textPrimary` color |
| Dividers | 0.5px `borderLight`/`borderDark` |
| Confirm button | `FilledButton` — `AppColors.primary`, `borderRadius: 14` |
| Edit button | `OutlinedButton` — secondary style |

**Variants:**
- **NL Logging:** Title "Log these entries?" — items are parsed health metrics
- **Memory Extraction:** Title "Save to memory?" — items are identified health facts
- **Food Photo:** Title "Nutrition estimate" — items are food name + macro breakdown

**Loading state:** `isLoading: true` replaces confirm button label with 18pt `CircularProgressIndicator`.

---

### File Attachment UI

Used in the Coach Chat Thread for uploading images, PDFs, and text files.

| Element | Spec |
|---------|------|
| Attachment button icon | `Icons.attach_file_rounded` 24pt |
| Camera button icon | `Icons.camera_alt_rounded` 24pt |
| Max file size | 10 MB per file |
| Max files per message | 3 |
| Supported formats | JPEG, PNG, HEIC, PDF, TXT, CSV |

**Preview cards (in message bubble):**
- Image: thumbnail 80×80pt with rounded corners (8px) + file name below
- PDF: `Icons.picture_as_pdf_rounded` 32pt + file name + file size
- Text/CSV: `Icons.description_rounded` 32pt + file name + file size

**Upload progress:** Thin `LinearProgressIndicator` below preview card, `AppColors.primary` fill.
**Upload complete:** Progress indicator replaced by a checkmark icon (`Icons.check_circle_rounded`, `statusConnected` color).

---

### Food Photo Response Card

Shown in chat after AI analyzes a food photo.

| Property | Value |
|----------|-------|
| Layout | `ConfirmationCard` variant with food-specific items |
| Food list | Each detected food item as a labeled row |
| Macros | Calories, protein, carbs, fat as sub-rows |
| Primary action | "Log this meal" — confirms to NL logging flow |
| Secondary action | "Adjust" — opens inline editing |

---

### Weekly Story Recap (Progress Tab)

Story-style swipeable card sequence shown on the Weekly Report screen.

| Property | Value |
|----------|-------|
| Layout | `PageView` with `NeverScrollableScrollPhysics` + swipe gesture |
| Card count | 6 cards per report |
| Transition | Horizontal page slide, 300ms `easeOutCubic` |
| Dot indicator | Row of 6pt dots below PageView, active dot in `AppColors.primary` |
| Background | Per-card gradient (dark → category color at 20% opacity) |
| Share button | `Icons.ios_share_rounded` in header — renders widget to image and shares via platform sheet |

**Card sequence:**
1. **Week Summary** — dates, total health score, mood trend
2. **Top Metrics** — top 3 categories with deltas
3. **Streaks & Goals** — current streaks, goals hit/missed
4. **AI Highlights** — 2–3 insight cards generated by the AI
5. **Areas for Improvement** — bottom 2 categories with specific advice
6. **Next Week Focus** — one actionable recommendation
