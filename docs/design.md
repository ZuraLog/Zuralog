# Zuralog — Design System & Brand Guidelines

**Version:** 3.2  
**Last Updated:** 2026-03-06  
**Status:** Living Document

---

## Design Philosophy

Zuralog's design targets **award-winning premium quality**. The visual language is inspired by Apple Fitness+ — editorial typography, bold color-coded health domains, borderless cards on pure black, and charts that feel alive. The goal is an app people screenshot and share because it *looks* that good.

**Design direction:** Editorial / Typographic — Apple Fitness+ caliber  
**Motion direction:** M3 Expressive principles — spring physics, shape morphing, purposeful choreography  
**North star apps:** Apple Fitness+, Linear, Opal  
**Design ambition:** Awwwards-level mobile design — not functional-but-forgettable

### Core Principles

1. **Typography carries the design.** Large, confident type with strict hierarchy. If the layout works without color, it works.
2. **Color is semantic, not decorative.** Every color means something — a health category, a state, a brand element. No color without purpose.
3. **Content is the interface.** No visible chrome (borders, shadows, dividers) unless absolutely necessary. Data fills the screen edge-to-edge.
4. **Motion earns its place.** Every animation communicates a state change. Nothing moves just to move.
5. **Dark Charcoal is the canvas.** Brand Dark Charcoal (#2D2D2D) backgrounds create premium depth and make every color pop. The app should feel like colored light on a rich, warm darkness.

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

### Surface Colors (Dark Theme — Dark Charcoal)

| Token | Hex | Usage |
|-------|-----|-------|
| `surface-900` | `#2D2D2D` | Primary background — Brand Dark Charcoal |
| `surface-800` | `#383838` | Card backgrounds, content containers |
| `surface-700` | `#3A3A3C` | Input backgrounds, chip fills, search bars, surfaces |
| `surface-600` | `#444444` | Elevated cards, bottom sheets, disabled states |
| `surface-500` | `#4A4A4C` | Dividers, card borders, input field borders |

**Note:** Primary background is `#2D2D2D` (Brand Dark Charcoal), matching the Zuralog website dark palette. Card backgrounds (`#383838`) are clearly distinct without a border.

### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | `#FAFAF5` | Primary text, headlines, metric values |
| `text-secondary` | `#A0A0A5` | Secondary text, captions, labels, hints |
| `text-tertiary` | `#636366` | Placeholder text, disabled states, timestamps |
| `text-inverse` | `#1C1C1E` | Text on sage-green buttons and light fills |

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

### AppShapes — Shape Scale

Shape is a first-class design token in Zuralog, following M3 Expressive's shape-as-expression philosophy. Rounder shapes feel more approachable and expressive; sharper shapes feel more precise and informational. Use shapes intentionally — a button being a stadium pill is a design statement, not a coincidence.

All shape tokens map to `BorderRadius.circular(value)` and are implemented as constants on `AppDimens`.

| Token | Radius | M3 equivalent | Usage |
|-------|--------|----------------|-------|
| `shapeXs` | 8px | Extra Small | Chips, tags, small badges, tooltip arrows |
| `shapeSm` | 12px | Small | Input fields, tooltips, snackbars |
| `shapeMd` | 20px | Medium–Large | Cards, category cards, confirmation cards |
| `shapeLg` | 28px | Extra Large | Bottom sheets (top corners), modals, logo card, onboarding hero containers |
| `shapeXl` | 40px | — | Onboarding slide image frames, large feature containers |
| `shapePill` | 100px | Full / Stadium | All buttons — primary, secondary, ghost |

**Shape rules:**
- **Buttons are always `shapePill`** (stadium). No exceptions. A button with a small radius looks dated.
- **Cards are always `shapeMd`** (20px). Elevated cards (modals, sheets) use `shapeLg` (28px).
- **Inputs are always `shapeSm`** (12px) — slightly sharp to feel precise and form-like.
- **Do not mix shape scales on adjacent elements.** A `shapeXl` container next to a `shapeXs` chip creates visual chaos.
- **Interactive state does not change shape.** Shape is static; motion and color communicate interaction.

**v3.2 note:** The previous `radiusCard`, `radiusButton`, `radiusButtonMd`, `radiusInput`, `radiusChip`, `radiusSm` constants in `AppDimens` are superseded by this shape scale. They will be aliased during implementation for backwards compatibility but new code should use `AppDimens.shapeMd` etc.

---

## Component Conventions

### Cards

Cards are the primary content container across the app. They are defined by **background color contrast only** — no borders, no shadows, no elevation.

- Background: `cardBackgroundDark` (`#383838`) on `backgroundDark` (`#2D2D2D`)
- **No border** in dark mode. The color difference between `#2D2D2D` and `#383838` provides sufficient definition.
- **No shadow** in dark mode. Light mode uses `cardShadowLight` (`0px 4px 20px rgba(0,0,0,0.05)`).
- Shape: `shapeMd` (20px radius)
- Padding: 16px (`md`) internal, 24px (`lg`) gap between cards
- Category cards may use their category color at 8–12% opacity as a subtle background tint

**Elevated cards** (bottom sheets, drawers, modals) use `elevatedSurfaceDark` (`#444444`) — one step above standard cards.

#### Interactive State (tappable cards only)

Cards that are tappable use the `ZuralogCard(onTap: ...)` constructor. This enables:

- **Press scale:** `0.98x` on press-down, `fastSpatial` spring bounce-back on release
- **State layer:** `colorScheme.onSurface` at 8% opacity overlay on press (rendered via `InkWell` with custom splash color)
- Static (non-tappable) cards do **not** animate. The absence of animation signals non-interactivity.

**Do not** add `GestureDetector` directly to card children to handle taps — always pass `onTap` to `ZuralogCard` so the press animation is guaranteed.

### Buttons

Buttons follow a strict three-level hierarchy. The hierarchy is enforced by Flutter widget type — not style overrides. Using the wrong widget for the wrong emphasis level is a design bug.

#### Button Hierarchy

| Level | Flutter Widget | Background | Text | Shape | Height | When to use |
|-------|---------------|------------|------|-------|--------|-------------|
| **Primary** | `FilledButton` | `AppColors.primary` (Sage Green) | `AppColors.primaryButtonText` (dark) | `shapePill` (100px) | 56px | The single most important action on a screen. One per screen. |
| **Secondary** | `OutlinedButton` | Transparent | `colorScheme.onSurface` | `shapePill` (100px) | 56px | Supporting action alongside a primary. Max two per screen. |
| **Ghost / Link** | `TextButton` | Transparent | `AppColors.primary` or `colorScheme.onSurfaceVariant` | `shapePill` (100px) | 48px | Lowest emphasis — navigation links, skip actions, inline text actions. |
| **Destructive** | `TextButton` | Transparent | `AppColors.statusError` | `shapePill` (100px) | 48px | Delete, disconnect, irreversible actions. Never a `FilledButton`. |
| **Category action** | `FilledButton` | Category color | Black | `shapePill` (100px) | 56px | Category-specific CTA (e.g., "Log Sleep" uses `categorySleep` fill). |

#### Interactive State — Spring Press Animation

All tappable buttons animate on press using `GestureDetector` (or `InkWell` with custom splash) + `AnimatedScale`:

- **Press down:** scale to `0.97x`, `fastSpatial` spring
- **Release:** scale back to `1.0x`, `fastSpatial` spring with natural overshoot
- **State layer:** `colorScheme.onPrimary` at 8% opacity overlaid on press (M3 state layer)

This is implemented in a `ZuralogButton` wrapper widget that all three hierarchy levels use internally. Do **not** use raw `FilledButton` / `TextButton` / `OutlinedButton` directly in screen code — always go through the shared button components.

#### Button Sizing

- Full-width: use `SizedBox(width: double.infinity)` wrapping the button — never `minimumSize: Size(double.infinity, ...)` in style overrides
- Icon + label: icon is 20px, 8px gap before label text
- Loading state: replace label with an 18px `CircularProgressIndicator` in `colorScheme.onPrimary`. Button stays at full size (no layout shift).

> **v3.2 change:** `ElevatedButton` is no longer used for primary actions. It is replaced by `FilledButton` everywhere. The `elevatedButtonTheme` in `AppTheme` is preserved for legacy compatibility only.

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
- **AI messages:** `surface-700` (`#3A3A3C`) background, white text, left-aligned, markdown-rendered. Radius: 20px (with 4px bottom-left for tail effect).
- **Streaming:** Animated typing indicator using three dots with staggered pulse animation in sage-green.
- **Suggested prompts:** Horizontal scrollable chips below the input bar when conversation is empty. `surface-500` background, `text-secondary` text, sage-green border on tap.

### Integration Tiles (Settings > Integrations)

- Connected state: category-appropriate color dot + "Connected" label in `success` green
- Available state: standard `surface-800` card, white text
- Coming Soon: 40% opacity overall, "Coming Soon" badge in `surface-500`
- Platform badge (iOS only / Android only): small pill in `surface-600`, `labelSmall` text

### Bottom Navigation Bar

- Frosted glass effect retained: `BackdropFilter` with Gaussian blur beneath the nav bar
- Background: `surface-900` at 70% opacity (Brand Dark Charcoal, translucent)
- 5 destinations: Today, Data, Coach, Progress, Trends
- Active tab: sage-green icon + label
- Inactive tab: `text-tertiary` icon + label
- No indicator pill/dot — the color change is sufficient
- Tab switch animation: 200ms cross-fade

### Skeleton Loading States

- Base color: `surface-800` (`#383838`)
- Shimmer highlight: `surface-600` (`#444444`)
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

## Dark Theme Priority

Zuralog **prioritizes dark mode** — it is the default experience and the most tested theme. A light mode is fully supported but dark is primary, as it is the mode most users will choose.

**Dark mode (primary):**
- Brand Dark Charcoal (`#2D2D2D`) background — matches the Zuralog website dark palette, creating visual continuity across platforms
- High contrast — every category color, every chart, every piece of text pops against the warm dark canvas
- Premium aesthetic aligned with the editorial design direction
- Card backgrounds at `#383838` create visible hierarchy without borders

**Light mode (supported):**
- Brand Cream (`#FAFAF5`) background — matches the Zuralog website light palette
- Light mode should feel equally polished, not like an afterthought
- Surface and text color tokens must have light-mode equivalents defined in `AppColors` / `AppTheme`
- Category colors remain the same across both themes — they are designed to work on both light and dark backgrounds
- Sage green brand color remains unchanged

---

## Motion & Animation

### Principles

1. **Purposeful:** Every animation communicates a state change — loading, completion, transition, feedback. Nothing moves for decoration.
2. **Physical:** Spring physics, not bezier curves. Objects have mass and settle naturally. No linear animations. No easing curves for spatial movement.
3. **Fast:** Most interactions settle in under 400ms. Users should never wait for an animation to finish before they can act.
4. **Choreographed:** When multiple elements animate simultaneously (e.g., cards loading in), stagger them — never synchronize. 50ms delay per item creates rhythm without feeling slow.

### AppMotion — Spring Token System

Motion is defined by **spring physics** (damping ratio + stiffness), not fixed durations. This is the M3 Expressive motion approach: animations feel physical because they are governed by simulated physics, not arbitrary millisecond counts. Springs overshoot and settle — that's intentional and desirable for spatial movement.

All spring values are implemented in `lib/core/theme/app_motion.dart` as `SpringDescription` constants on the `AppMotion` class.

#### Spatial Springs (for things that move: position, scale, size)

Spatial springs have a moderate bounce (`dampingRatio < 1.0`) — they slightly overshoot before settling, which makes movement feel alive.

| Token | Damping Ratio | Stiffness | Typical use |
|-------|--------------|-----------|-------------|
| `fastSpatial` | 0.6 | 1400 | Button press scale, chip selection, icon morphs |
| `defaultSpatial` | 0.7 | 700 | Card entry, screen transitions, panel slides, hero entrances |
| `slowSpatial` | 0.8 | 300 | Progress ring fill, large hero scale-in, backdrop reveals |

#### Effects Springs (for appearance changes: opacity, color, blur)

Effects springs have no bounce (`dampingRatio = 1.0` / critically damped) — color and opacity changes should not oscillate, they should arrive cleanly.

| Token | Damping Ratio | Stiffness | Typical use |
|-------|--------------|-----------|-------------|
| `fastEffects` | 1.0 | 3800 | Tap feedback, icon color change, state layer |
| `defaultEffects` | 1.0 | 1600 | Text fade, badge reveal, shimmer end |
| `slowEffects` | 1.0 | 800 | Skeleton → content crossfade, background tint |

#### Stagger

When a list of elements enters the screen simultaneously, delay each by **50ms** per item. Use `defaultSpatial` for each item's scale/fade-in.

#### Bezier fallbacks (use only where `SpringSimulation` is unavailable)

A small number of Flutter widgets (e.g., `PageView` with `nextPage()`) require a `Curve` rather than a `SpringSimulation`. In these cases use:

| Context | Curve | Duration |
|---------|-------|----------|
| PageView slide | `Curves.easeOutCubic` | 380ms |
| Tab cross-fade | `Curves.easeOut` | 200ms |
| Skeleton shimmer (loop) | `Curves.easeInOut` | 1200ms |

### Specific Animation Behaviors

- **Button press:** Scale to `0.97x` on press-down, spring back with `fastSpatial`. Background state layer fades in with `fastEffects`. The combination reads as physical without being distracting.
- **Card press:** Scale to `0.98x` on press-down, spring back with `fastSpatial`. Tappable cards only — static cards do not animate.
- **Screen push (slide-up):** Pushed screens slide up from 40px below, fade from 0 opacity — `defaultSpatial`. Cross-fade for tab switches.
- **Charts:** Animate on first load only. Lines draw left-to-right, bars grow bottom-up, rings fill clockwise. Use `slowSpatial` for ring fill.
- **Progress ring fill:** `slowSpatial` spring from 0 to current value. The slight overshoot at completion reads as satisfying.
- **Achievement unlock:** Scale from 0.6 → 1.0 with `defaultSpatial` (notable overshoot). Follow with a 600ms glow pulse in the achievement's category color.
- **Drag-and-drop (Data tab):** Lifted card scales to `1.03x` (`fastSpatial`). Other cards reorder with `defaultSpatial` (200ms equivalent settle time).
- **Bottom sheet reveal:** Slides up from 100% off-screen, `defaultSpatial`. Backdrop fades in with `defaultEffects`.
- **Onboarding step dots:** Active dot morphs width from 6px → 20px with `fastSpatial`. The pill-to-circle transition is the primary visual progress signal.
- **Hero entrances (onboarding):** Scale from 0.75 → 1.0, opacity 0 → 1, `defaultSpatial`. Stagger text elements 80ms behind the hero image.

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

| Asset | File | Usage |
|-------|------|-------|
| Logo SVG — with background | `assets/brand/logo/Zuralog.svg` | Standalone icon contexts (documents, share sheets) |
| Logo SVG — transparent (Sage mark) | `assets/brand/logo/ZuraLog-Sage.svg` | In-app rendering on dark surfaces; accepts `ColorFilter` recoloring |
| Logo PNG — with background | `assets/brand/logo/ZuraLog-Logo-Main.png` | App icons, favicons, OG image, any self-contained icon |
| Logo PNG — transparent (Sage mark) | `assets/brand/logo/ZuraLog-Logo-Sage.png` | Inline image on dark surfaces where the surface provides background |
| App icon | `assets/brand/icons/` | Platform icon sources (currently empty — icons generated from logo PNGs) |
| Brand fonts | `assets/brand/fonts/` | Inter Regular / Medium / SemiBold / Bold |
| Flutter copy | `zuralog/assets/images/` | Manually synced from `assets/brand/logo/`. Use `AppAssets` constants in Dart — never hardcode paths. |
| Website copy | `website/public/logo/` | Manually synced from `assets/brand/logo/`. |

**Flutter asset path constants:** `zuralog/lib/core/theme/app_assets.dart` (`AppAssets.logoSvg`, `AppAssets.logoMainPng`, etc.)

**Logo variant rule:**
- **With background** (`Main`) → use when icon is self-contained: app icons, favicons, platform launchers, light-coloured surfaces.
- **Transparent** (`Sage`) → use on dark surfaces where the surrounding UI provides the background context.

---

## v3.2 — Auth & Onboarding Design Language

Added: 2026-03-06. This section defines the full visual language, component specs, and image direction for the three auth/onboarding experiences: the first-launch value prop slideshow, the auth gate, and the post-registration setup flow.

---

### Image Placeholder Format

All image placeholders in this document follow this format. When generating images through an AI image tool, use the full spec below each placeholder tag.

```
[IMAGE PLACEHOLDER — <Screen> — <Slot name>]
Style: <art direction style>
Content: <what the image should depict>
Mood: <emotional tone>
Colors: <dominant palette>
Dimensions: <aspect ratio or pixel size>
Notes: <any additional guidance>
```

Images should be exported to `zuralog/assets/images/onboarding/` and `zuralog/assets/images/auth/`.

---

### Value Prop Slideshow (`OnboardingPageView`)

The first thing a new user ever sees. Three full-bleed slides that establish Zuralog's identity before the user even creates an account. The goal is to create a sense of anticipation and premium quality — not to explain every feature.

#### Layout Structure (per slide)

```
┌─────────────────────────────┐  ← Full screen, Dark Charcoal scaffold
│                             │
│    [Hero Image / Visual]    │  ← Top 58% of screen height
│                             │     shapeLg (28px) corner radius
│                             │     image fills container, object-fit cover
├─────────────────────────────┤
│                        Skip │  ← Ghost TextButton, top-right of bottom panel
│                             │
│  Headline                   │  ← h1 (34pt Bold), left-aligned, white
│  Body copy                  │  ← bodyMedium (14pt), left-aligned, textSecondary
│                             │
│  ● ○ ○   [  Next  ]        │  ← Pill dot indicators + FilledButton CTA
└─────────────────────────────┘
```

**Hero image container:** `shapeLg` radius (28px), fills `0.58 * screenHeight`, clips the image. No border. A very subtle Sage Green glow at 6% opacity is applied as a `BoxDecoration` shadow behind the container — this is justified (not vibecoded) because it anchors the floating image to the dark background and creates depth, not decoration.

**Dot indicator:** Pill shape. Active dot: 20px wide × 6px tall, `AppColors.primary`. Inactive: 6px × 6px circle, `AppColors.borderDark`. Width morph uses `fastSpatial` spring. Positioned bottom-left of the action row.

**CTA button:** `FilledButton`, stadium pill, 56px height, 140px width (not full-width — the dots and button share a row). Label changes: "Next" → "Next" → "Get Started". Spring press scale applies.

**Skip:** `TextButton` ghost, `textSecondary` color, positioned right-aligned in the same row as the dots + CTA. On final slide, "Skip" is hidden — replaced with nothing (the "Get Started" CTA is the only exit).

**Slide transitions:** `PageView` driven. On swipe: `Curves.easeOutCubic` 380ms (bezier fallback — `PageView` does not accept `SpringSimulation`). On button tap: same. Hero image parallax: the image container translates at 30% of the page scroll offset, creating a subtle depth effect.

---

#### Slide 1 — "Your health, complete."

[IMAGE PLACEHOLDER — Onboarding Slide 1 — Hero]
Style: 3D rendered, dark background, premium tech aesthetic
Content: A glowing constellation of health-related 3D icons floating in a circular orbital arrangement on deep black — a stylized heart, running figure silhouette, sleep wave/moon, brain/mind icon, and fork+leaf (nutrition). Each icon emits a soft glow matching its category color (heart = red, sleep = purple, activity = green, etc.). The center of the orbit is empty negative space.
Mood: Awe, completeness, the feeling of everything coming together
Colors: Deep black (#000000) background; each icon in its category color at high saturation; subtle star-field or particle effect in the extreme background
Dimensions: 3:2 aspect ratio (e.g., 1200×800px)
Notes: Icons should feel 3D and premium — not flat illustration. Think Apple product imagery meets sci-fi UI. The orbital arrangement subconsciously communicates "everything in one place."

**Headline:** "Your health, complete."
**Body:** "Connect every app. See the full picture."
**Accent color:** `AppColors.primary` (Sage Green) — used for the dot indicator active state and CTA button

---

#### Slide 2 — "AI that gets you."

[IMAGE PLACEHOLDER — Onboarding Slide 2 — Hero]
Style: Abstract digital illustration, slightly expressive
Content: Flowing streams of data (thin luminous lines, like fiber optic strands) converging from the edges of the frame into a warm glowing central point. The center resolves into a softly abstract humanoid silhouette made of light — not photorealistic, more like an energy field taking human shape. The data streams carry subtle iconography (heartbeat waves, step counts, sleep arcs) dissolved into the flow.
Mood: Intelligence, personalization, the feeling of being understood
Colors: Deep black background; data streams in Sage Green (#CFE1B9) and wellness purple (#BF5AF2); the central glow warm white/gold
Dimensions: 3:2 aspect ratio
Notes: Should feel modern and intelligent — not clinical or cold. The humanoid center must be abstract enough to not depict any specific person (inclusive). Gradient use is justified here: the converging streams require gradient-to-center to sell the "flowing toward you" metaphor.

**Headline:** "AI that gets you."
**Body:** "Personalized insights from everything you track."
**Accent color:** `AppColors.categoryWellness` (`#BF5AF2`) — dot indicator active state

---

#### Slide 3 — "Built to last."

[IMAGE PLACEHOLDER — Onboarding Slide 3 — Hero]
Style: Dark lifestyle photography, cinematic
Content: A person (athlete/active lifestyle, gender-neutral framing — show from side or back to avoid identity specificity) glancing at a phone in a gym or outdoor training environment. The scene is lit with blue-green rim lighting (cinematic, editorial feel). The phone screen shows a faint glow — not a UI mockup, just light. The environment is dark — black or very dark concrete/industrial setting.
Mood: Premium, aspirational, real — grounding the abstract slides with a human moment
Colors: Deep blacks and dark greys dominate; rim lighting in activity green (#30D158) and a secondary blue tone; very minimal warm tones
Dimensions: 3:2 aspect ratio
Notes: Photography is used here specifically on the final slide to ground the previous two abstract slides with a real human moment. This is the moment the user decides to sign up — it should feel like joining something worth joining. No stock photo vibe — should look editorial or campaign-quality.

**Headline:** "Built to last."
**Body:** "Privacy-first. Your data, always yours."
**Accent color:** `AppColors.categoryActivity` (`#30D158`) — dot indicator active state

---

### Auth Gate (`WelcomeScreen`)

The screen the user lands on after the slideshow (or directly, on every subsequent app launch). This is the highest-traffic screen in the entire app — it must convert.

#### Layout Structure

```
┌─────────────────────────────┐  ← Full screen, Dark Charcoal scaffold
│                             │
│    [Sage Green radial bloom] │  ← Very subtle: 200px radial gradient at top-center
│                             │     AppColors.primary at 7% opacity, radial spread
│                             │     Justified: depth anchor, not decoration
│         [Logo Card]         │  ← 96×96px, shapeLg (28px), AppColors.primary fill
│          Zuralog            │  ← h1 (34pt Bold), white
│   Better health, together.  │  ← bodyMedium, textSecondary
│                             │
│  [  Continue with Apple  ]  │  ← FilledButton, black bg, white text, 56px, pill
│  [  Continue with Google ]  │  ← OutlinedButton, border, 56px, pill
│          ─── or ───         │  ← Divider row with "or" label
│      Log in with Email      │  ← TextButton ghost, textSecondary color, 48px
│                             │
│   Terms · Privacy Policy    │  ← Caption, textTertiary, centered
└─────────────────────────────┘
```

**Logo card:** 96×96px container, `shapeLg` (28px radius), `AppColors.primary` fill. Contains the Zuralog SVG logo in `AppColors.primaryButtonText`. Box shadow: `AppColors.primary` at 40% opacity, 24px blur, 8px Y offset — creates the brand glow characteristic of the app.

**Radial bloom:** `RadialGradient` centered at `Alignment(0, -1.2)` (top-center, above visible area). Colors: `[AppColors.primary.withOpacity(0.07), Colors.transparent]`. Radius: `0.8`. This is rendered as a full-screen `Container` behind the content — pixels off at the edges on OLED.

**Button specs:**
- Apple: `FilledButton`, `AppColors.black` background, white text + `Icons.apple` icon (20px). 56px height, full-width, `shapePill`.
- Google: `OutlinedButton`, transparent bg, `colorScheme.onSurface` text + "G" in `AppColors.googleBlue` (bold). Border: `AppColors.borderDark` 1.5px. 56px height, full-width, `shapePill`.
- Email: `TextButton`, `colorScheme.onSurface` text. 48px height, full-width. No border.

All three buttons use the spring press animation (`fastSpatial`, `0.97x` scale).

---

### Combined Auth Screen (`AuthScreen`)

Replaces the separate `LoginScreen` and `RegisterScreen`. A single screen with a tab toggle to switch between the two modes. Reduces navigation pushes and creates a more cohesive auth experience.

**Route:** `/auth` — both `/auth/login` and `/auth/register` redirect here (with a query parameter `?tab=login` or `?tab=register` to set the initial tab).

#### Layout Structure

```
┌─────────────────────────────┐  ← Full screen, Dark Charcoal scaffold
│ ←  Zuralog                  │  ← Back chevron + "Zuralog" wordmark (AppColors.primary)
│                             │
│ ╔═══════════╦═══════════╗   │  ← TabBar: "Log in" | "Create account"
│ ║  Log in   ║  Sign up  ║   │     Sage Green underline indicator (not pill)
│ ╚═══════════╩═══════════╝   │     Spring slide animation on switch
│                             │
│ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ ┄ │  ← TabBarView (NeverScrollableScrollPhysics)
│                             │
│  Welcome back.              │  ← h1 (34pt Bold) — or "Create account."
│  Sign in to continue.       │  ← bodyMedium, textSecondary
│                             │
│  [     Email address     ]  │  ← AppTextField, shapeSm (12px)
│  [       Password        ]  │  ← AppTextField with eye toggle
│                (Forgot?)    │  ← TextButton ghost, right-aligned (login only)
│                             │
│  [       Log In          ]  │  ← FilledButton, full-width, 56px, shapePill
│                             │
│  Don't have an account?     │  ← Caption + TextButton inline — switches tab
└─────────────────────────────┘
```

**Top bar:** Not an `AppBar`. A custom `Row` with:
- Back chevron `IconButton` (left)
- "Zuralog" `Text` in `AppTextStyles.h3` with `AppColors.primary` color (center, or left-aligned after back icon)
- 48px spacer (right, mirrors icon width for balance)

**Tab indicator:** `TabBar` with `TabController`. Indicator style: underline, `AppColors.primary`, 2px thick, rounded ends. Tab label text: `AppTextStyles.h3`. No background fill on the tabs. Spring-animated content transition when switching tabs: `AnimatedSwitcher` with `defaultSpatial` spring (opacity + slight vertical translate: 8px up on enter).

**Form fields:** `AppTextField` using `shapeSm` (12px). On focus, field container scales to `1.005x` with `fastSpatial` — barely perceptible but adds tactility.

**"Forgot password?"** TextButton: right-aligned below the password field. Login tab only — hidden on register tab.

**Switch link** ("Don't have an account? Sign up"): caption text + inline `TextButton` in `AppColors.primary`. Tapping calls `_tabController.animateTo(1)` — switches the tab without navigating away.

#### Register tab differences
- Heading: "Create account."
- Subheading: "Start your health journey."
- No "Forgot password?" link
- Switch link: "Already have an account? Log in"

---

### Post-Registration Onboarding Flow (`OnboardingFlowScreen`)

Shown once after registration. The shell (`OnboardingFlowScreen`) manages navigation, progress, and backend submission. Individual steps are self-contained widgets.

**Route:** `/auth/profile-questionnaire` (unchanged)

#### Shell Layout

```
┌─────────────────────────────┐
│ ←        ● ● ○ ○ ○ ○ ○ ○   │  ← Back arrow (left) + pill step dots (center)
│                   [Skip]    │  ← Ghost TextButton (top-right, steps 2–8 only)
├─────────────────────────────┤
│                             │
│      [Step Content]         │  ← PageView, NeverScrollableScrollPhysics
│                             │
│                             │
├─────────────────────────────┤
│  [  Back  ]  [    Next   ]  │  ← Back: OutlinedButton | Next: FilledButton
└─────────────────────────────┘  ← Step 1 manages its own CTA (no bottom nav)
```

**Step dots:** Pill-morphing dots (same component as `OnboardingPageView`). 8 dots total (8 steps). Active: 20px × 6px pill, `AppColors.primary`. Inactive: 6px circle, `AppColors.borderDark`. `fastSpatial` spring on width morph.

**Skip link:** `TextButton` ghost, `textSecondary` color, top-right. Visible on steps 2–8. Tapping advances to the next step without saving the current step's data (empty/default values are sent for that field). Step 1 (Welcome) has no skip — the only action is "Let's go".

**Bottom nav:** Back button is `OutlinedButton` (secondary hierarchy — less visual weight than the current gray-filled `SecondaryButton`). Next/Finish is `FilledButton`. They share equal width in a `Row`.

---

#### Step 1 — Welcome

**Purpose:** Brand moment. Animated entrance. Single CTA.

**Layout:**
```
┌─────────────────────────────┐
│                             │
│         [Logo Card]         │  ← 80×80px, shapeLg, AppColors.primary
│                             │     Spring scale-in: 0.6 → 1.0, defaultSpatial
│   Hi, welcome to Zuralog.   │  ← h1, staggered 80ms after logo
│   Let's set up your AI      │  ← bodyMedium, textSecondary
│   health coach.             │     Staggered 160ms after logo
│                             │
│    [  Let's go  →  ]        │  ← FilledButton, full-width, 56px
└─────────────────────────────┘
```

No top bar (no back arrow, no dots). Full screen feel. The logo card entrance is the primary motion moment: scale from `0.6 → 1.0` with `defaultSpatial` spring (visible overshoot to `1.04x` before settling). Text elements fade in + translate up 12px, staggered 80ms per element.

---

#### Step 2 — Name / Nickname

**Purpose:** Personalize the AI greeting from the very first message.

**Layout:**
```
┌─────────────────────────────┐
│   What should we call you?  │  ← h1
│   Your AI coach will use    │  ← bodyMedium, textSecondary
│   this name.                │
│                             │
│   [    Your name or         │  ← AppTextField, large — fontSize 20pt
│         nickname...    ]    │     Auto-focus on appear
│                             │
│   "Hi Alex, here's your     │  ← Live preview card (ZuralogCard)
│    morning briefing..."     │     Updates as user types
│                             │
└─────────────────────────────┘
```

**Live preview card:** A `ZuralogCard` below the field that shows a preview AI greeting with the current input. Updates on every keystroke with no animation (debounced 200ms). If empty, shows "Hi there, here's your morning briefing...". This makes the benefit of entering a name immediately tangible.

**Validation:** No hard validation. If skipped or left blank, the AI defaults to "Hey" / no name greeting. Backend field: `nickname` in `PATCH /api/v1/preferences`.

---

#### Step 3 — Goals

**Purpose:** Multi-select health goals. Informs AI priority and dashboard defaults.

**Layout:** 2×4 grid of goal chips. Each chip is a `FilterChip`-style card (not a standard Flutter `FilterChip` — custom widget for expressiveness):

```
┌─────────────┐  ┌─────────────┐
│  🏃 Lose    │  │  💪 Build   │
│    Weight   │  │   Muscle    │
└─────────────┘  └─────────────┘
```

**Chip spec:**
- Unselected: `cardBackgroundDark` (`#383838`) fill, `borderDark` border 1px, `shapeMd` (20px radius)
- Selected: Category-relevant color at 15% opacity fill + category color border 1.5px + category color checkmark icon top-right
- Spring press: scale `1.04x` on select, `fastSpatial` spring bounce-back
- The scale overshoot on select makes the chip feel "snappy" and satisfying

**Goal → Category color mapping:**
| Goal | Category | Color |
|------|----------|-------|
| Lose Weight | Body | `categoryBody` |
| Build Muscle | Activity | `categoryActivity` |
| Improve Sleep | Sleep | `categorySleep` |
| Boost Energy | Wellness | `categoryWellness` |
| Reduce Stress | Wellness | `categoryWellness` |
| Train for Event | Activity | `categoryActivity` |
| Track Nutrition | Nutrition | `categoryNutrition` |
| Improve Mobility | Mobility | `categoryMobility` |

Minimum 1 goal required to advance (soft validation — show inline hint, not a dialog).

---

#### Step 4 — AI Persona

**Purpose:** Choose the AI coach's communication style.

**Layout:** 3 full-width persona cards stacked vertically + proactivity slider below.

**Persona card spec:**
- Full-width `ZuralogCard`, `shapeMd` (20px)
- Left accent bar: 4px wide, full height, persona color, `shapePill` left corners
- Title: `h3`, white. Description: `bodyMedium`, `textSecondary`
- Selected state: Sage Green border 1.5px + `AppColors.primary` at 6% opacity background tint + checkmark icon
- Spring scale on select: `1.01x`, `fastSpatial`

**Persona color mapping:**
| Persona | UI Label | Color |
|---------|----------|-------|
| Tough Love | "Direct" | `categoryHeart` |
| Balanced | "Balanced" | `categoryActivity` |
| Gentle | "Supportive" | `categoryWellness` |

**Proactivity slider:** `Slider` widget, 3 labeled stops (Low / Medium / High). Track in `borderDark`, active track in `AppColors.primary`, thumb in `AppColors.primary`.

---

#### Step 5 — Fitness Level

**Purpose:** Self-assessment for AI language calibration. Fast and skippable.

**Layout:** 3 large selection tiles (full-width, stacked):

```
┌─────────────────────────────┐
│ 🚶 Beginner                 │  ← h3 + bodyMedium description
│ Just getting started        │
└─────────────────────────────┘
┌─────────────────────────────┐
│ 🏃 Active                   │
│ Regular exercise routine    │
└─────────────────────────────┘
┌─────────────────────────────┐
│ 🏋 Athletic                  │
│ Serious training & goals    │
└─────────────────────────────┘
```

Each tile: `ZuralogCard` with `onTap`. Selected state: `AppColors.primary` at 8% tint + `AppColors.primary` border 1.5px. Spring scale on select: `1.01x`, `fastSpatial`. Single-select — selecting one deselects the others. Backend field: `fitness_level` in `PATCH /api/v1/preferences` (new field — needs backend addition).

---

#### Step 6 — Connect Apps

**Purpose:** Informational. Sets expectations before Settings → Integrations.

**Layout:** Grid of 6 integration tiles (2 columns):

[IMAGE PLACEHOLDER — Onboarding Step 6 — Integration Logos]
Style: Flat brand logos on dark card backgrounds
Content: Logo tiles for Strava, Fitbit, Apple Health, Health Connect (Android), Oura, CalAI — each in its brand color on a `#121212` card background
Mood: Trustworthy, "compatible with your existing tools"
Colors: Each logo in its brand color; card bg `#121212`; "Later" badge in `surfaceDark`
Dimensions: Each tile 160×80px
Notes: These are informational only — no connect button on this step. A "Later" badge appears on each tile to signal non-urgency. Use actual brand logos (SVG) from `simple_icons` and `font_awesome_flutter` packages.

No CTA change beyond "Next" — no connectivity happens here.

---

#### Step 7 — Notifications

**Purpose:** Set up morning briefing and reminders.

**Layout:** List of `ListTile`-style toggle rows with `Switch` widgets (Sage Green themed):

- Morning Briefing toggle + time picker (visible when on)
- Smart Reminders toggle
- Wellness Check-in toggle + time picker (visible when on)

No visual redesign needed beyond the global switch theme. The layout is clean and functional.

---

#### Step 8 — Discovery

**Purpose:** Analytics — "Where did you hear about Zuralog?"

**Layout:** Single-select list of `RadioListTile`-style options:
- App Store
- Friend or Family
- Social Media
- Search Engine
- Other

Clean, minimal. Fast. No visual novelty needed here — the user is nearly done.

---

### Design Principles Summary for Auth & Onboarding

1. **Every screen earns its existence.** The slideshow earns its 3 slides by building genuine anticipation. Steps 2–8 each earn their position by collecting something that makes the product immediately better.
2. **Skippability is respect.** Every step from 2 onward is skippable. The skip link is always visible. Forcing data collection creates friction and resentment.
3. **Show, don't just tell.** The live preview name card in Step 2, the persona descriptions in Step 4, and the integration logos in Step 6 all make the product feel real and already built. Not a questionnaire — a configuration experience.
4. **Spring physics signal quality.** The chip selection bounce, the logo entrance overshoot, the dot morphing — none of these are decoration. They signal that this is a product that was built with care.
5. **Visual density increases over time.** Step 1 is nearly empty (brand moment). Each subsequent step adds more UI. By Step 6 the screen is full of integration tiles. This gradual density increase matches the user's growing comfort with the app.

---

## v3.1 — MVP Component Specifications

Added: 2026-03-03. These specifications cover all new MVP components introduced in the Phase 0 design system rebuild.

---

### Light Mode Color Tokens

Light mode is a first-class theme. It mirrors dark mode's information density but replaces black canvases with white and grey surfaces. Category colors are identical in both themes.

| Token | AppColors constant | Light Hex | Dark Hex | Usage |
|-------|--------------------|-----------|----------|-------|
| Scaffold background | `backgroundLight` / `backgroundDark` | `#FAFAF5` | `#2D2D2D` | App scaffold (`Scaffold.backgroundColor`) |
| Surface (colorScheme.surface) | `surfaceLight` / `surfaceDark` | `#F2F2F7` | `#3A3A3C` | Elevated surfaces |
| Card background | `cardBackgroundLight` / `cardBackgroundDark` | `#FFFFFF` | `#383838` | Standard cards |
| Elevated surface | `elevatedSurfaceLight` / `elevatedSurfaceDark` | `#FFFFFF` | `#444444` | Bottom sheets, drawers, modals |
| Input background | `inputBackgroundLight` / `inputBackgroundDark` | `#F2F2F7` | `#3A3A3C` | Text fields, search bars |
| Divider / border | `borderLight` / `borderDark` | `#E5E5EA` | `#4A4A4C` | Dividers, card separators |
| Text primary | `textPrimaryLight` / `textPrimaryDark` | `#000000` | `#FAFAF5` | Headlines, body text |
| Text secondary | `textSecondaryLight` / `textSecondaryDark` | `#636366` | `#A0A0A5` | Captions, labels, metadata |
| Text tertiary | `textTertiary` | `#ABABAB` | `#ABABAB` | Placeholders, disabled, timestamps |

**Rules:**
- Category colors are identical in both themes and require no `Light`/`Dark` suffix.
- `AppColors.primary` (Sage Green `#CFE1B9`) is the same in both modes. In light mode, `AppColors.primaryOnLight` (`#344E41`) is used instead for WCAG AA contrast.
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
