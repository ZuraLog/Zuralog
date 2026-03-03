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
