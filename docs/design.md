# Zuralog — Design System & Brand Guidelines

**Version:** 4.0
**Last Updated:** 2026-03-23
**Status:** Living Document

---

## Design Philosophy

Zuralog's visual identity is rooted in **organic, nature-inspired design**. A topographic contour-line pattern serves as the brand's signature texture — woven into buttons, cards, text fills, progress bars, and interactive surfaces. The result is a health app that feels alive, grounded, and unmistakably Zuralog.

**Design direction:** Organic / Nature-Inspired — topographic pattern as signature
**North star feeling:** Calm confidence. Like opening a journal in a forest.
**Design ambition:** Premium wellness design that people screenshot and share.

### Core Principles

1. **The pattern is the brand.** The topographic contour-line pattern is Zuralog's signature. It appears on primary buttons, hero text, card accents, progress bars, and interactive highlights — always via CSS/Flutter blend modes from a single source image.
2. **Two greens anchor everything.** Sage (#CFE1B9) and Deep Forest (#344E41) are the brand's fixed poles. All surfaces, text, and borders derive from these two colors.
3. **Dark mode is home.** Ink Green (#141E18) canvas is the primary environment. Light mode is a respectful inversion, not a different design.
4. **Depth through luminance, not shadow.** On dark backgrounds, elevation comes from progressively brighter surfaces and borders — not drop shadows.
5. **Motion is gentle.** Expo-out easing, staggered entrances, and shimmer loading. The pace matches a wellness app — calming, not urgent.

### What Stays Constant

- Brand pattern image and its blend-mode treatments
- Color palette (Sage, Deep Forest, Ink Green) and semantic tokens
- Typography (Outfit font family)
- Spacing scale (4px base grid)
- Border radius conventions
- Category color assignments

### What Should Always Be Explored

- New pattern applications and treatments
- Screen layouts and card arrangements
- Animation choreography details
- Component visual treatments for new features

---

## Brand Pattern

**Source:** `docs/brand/brand-pattern.png`
**Style:** Organic topographic contour lines, green-toned
**Format:** PNG (single source image, tinted via CSS/Flutter for variants)

### Pattern Application Methods

The pattern is applied through blend modes and opacity, never as a raw background fill.

| Treatment | Method | Use Case |
|-----------|--------|----------|
| **Sage + Pattern Overlay** | Pattern image on `#CFE1B9` base, `overlay` blend mode, 100% opacity | Primary buttons (signature treatment) |
| **Pattern Text** | `background-clip: text` / Flutter `ShaderMask` with pattern fill | Hero numbers, score displays, headlines, brand wordmark. Works on both dark AND light backgrounds. |
| **Pattern Card Accent** | 3px top-edge strip with pattern fill | Featured cards, elevated content |
| **Subtle Texture** | Pattern at 8–12% opacity on card surface | Texture hint on premium surfaces |
| **Pattern Overlay on Card** | Pattern with overlay blend on sage card | Highlighted/featured cards |
| **Pattern on Dark Forest** | Pattern at 15–20% opacity on `#344E41` | Deep forest card variant |

### Pattern on Components

| Component | Treatment |
|-----------|-----------|
| Progress bars | Pattern fill on completed portion |
| Dividers | Pattern-filled 2px lines (decorative sections only) |
| Avatar rings | Pattern ring border around profile images |
| Tab indicators | Pattern underline on active tab |
| Loading skeletons | Pattern shimmer sweep |
| Sheet handles | Pattern-filled drag handle |
| Chips (selected) | Sage + pattern overlay on active chip |

### Category Pattern Tinting

The single green pattern image can be tinted to any health category color using three CSS/Flutter methods. All three are retained for different contexts:

| Method | Technique | Best For |
|--------|-----------|----------|
| **Hue-rotate** | `filter: hue-rotate(Xdeg) saturate(1.2)` | Quick shifts, simple implementations |
| **Luminosity-on-color** | Pattern as luminosity source on category-color base | Rich, vibrant results |
| **Grayscale + color blend** | Desaturate pattern → color blend overlay | Most controllable, best fidelity |

**Hue rotation values from green base (120°):**

| Category | Color | Rotation |
|----------|-------|----------|
| Activity | #30D158 | 0° |
| Sleep | #5E5CE6 | +140° |
| Heart | #FF375F | −120° |
| Nutrition | #FF9F0A | −90° |
| Body | #64D2FF | +60° |
| Wellness | #BF5AF2 | +160° |
| Cycle | #FF6482 | −140° |
| Mobility | #FFD60A | −60° |
| Vitals | #6AC4DC | +45° |
| Environment | #63E6BE | +15° |

---

## Color Palette

### Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `sage` | `#CFE1B9` | Primary brand accent — buttons, active states, headings, interactive elements |
| `deep-forest` | `#344E41` | Secondary brand — button fills, text on light mode, strong accents |
| `ink-green` | `#141E18` | Canvas background (dark mode) |

Sage and Deep Forest are the two fixed brand colors. All other surface and text colors derive from them.

### Health Category Colors

| Category | Token | Hex |
|----------|-------|-----|
| Activity | `category-activity` | `#30D158` |
| Sleep | `category-sleep` | `#5E5CE6` |
| Heart | `category-heart` | `#FF375F` |
| Nutrition | `category-nutrition` | `#FF9F0A` |
| Body | `category-body` | `#64D2FF` |
| Vitals | `category-vitals` | `#6AC4DC` |
| Wellness | `category-wellness` | `#BF5AF2` |
| Cycle | `category-cycle` | `#FF6482` |
| Mobility | `category-mobility` | `#FFD60A` |
| Environment | `category-environment` | `#63E6BE` |

**Usage rules:**
- Full saturation on charts, progress rings, and active state icons
- 15–20% opacity as card tint backgrounds
- As text only for metric values and category labels, never body text
- Two category colors never appear adjacent at full saturation without a separator

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#34C759` | Connected, positive deltas, goal completion |
| `warning` | `#FF9500` | Caution, approaching limits |
| `error` | `#FF3B30` | Error, disconnected, destructive |
| `syncing` | `#007AFF` | Loading/syncing indicators |

---

## Surface & Elevation System

### Dark Mode (Primary)

Depth is achieved through progressively brighter surfaces and brighter borders. No drop shadows.

| Level | Token | Background | Border | Usage |
|-------|-------|-----------|--------|-------|
| 0 | `canvas` | `#141E18` | `rgba(207,225,185, 0.04)` | Screen background |
| 1 | `surface` | `#1E2E24` | `rgba(207,225,185, 0.06)` | Cards, content containers |
| 2 | `surface-raised` | `#253A2C` | `rgba(207,225,185, 0.08)` | Popovers, dropdowns, tooltips |
| 3 | `surface-overlay` | `#2C4534` | `rgba(207,225,185, 0.10)` | Modals, dialogs, bottom sheets |

### Light Mode

Light mode uses subtle shadows instead of border luminance for elevation.

| Level | Token | Background | Border | Shadow | Usage |
|-------|-------|-----------|--------|--------|-------|
| 0 | `canvas` | `#FAFAF5` | — | — | Screen background (warm white) |
| 1 | `surface` | `#FFFFFF` | `rgba(52,78,65, 0.08)` | `0 1px 3px rgba(52,78,65, 0.04)` | Cards |
| 2 | `surface-raised` | `#FFFFFF` | `rgba(52,78,65, 0.08)` | `0 4px 12px rgba(52,78,65, 0.06)` | Popovers |
| 3 | `surface-overlay` | `#FFFFFF` | `rgba(52,78,65, 0.10)` | `0 8px 24px rgba(52,78,65, 0.08)` | Modals |

### Text Colors

| Token | Dark Mode | Light Mode | Usage |
|-------|-----------|------------|-------|
| `text-primary` | `#E8EDE0` | `#1A2E22` | Headlines, metric values |
| `text-secondary` | `#CFE1B9` | `#344E41` | Headings, accents, sage highlights |
| `text-muted` | `rgba(207,225,185, 0.40)` | `rgba(52,78,65, 0.45)` | Labels, captions, timestamps |
| `text-on-sage` | `#344E41` | — | Text on sage-colored surfaces |
| `text-on-forest` | `#CFE1B9` | — | Text on forest-colored surfaces |

### Border Colors

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `border-default` | `rgba(207,225,185, 0.06)` | `rgba(52,78,65, 0.08)` |
| `border-strong` | `rgba(207,225,185, 0.12)` | `rgba(52,78,65, 0.15)` |

---

## Typography

**Font Family:** Outfit (all platforms)
**Weights:** Regular (400), Medium (500), SemiBold (600), Bold (700)

### Type Scale

| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| `displayLarge` | 34pt | Bold (700) | 1.1 | Hero numbers, health score, screen titles |
| `displayMedium` | 28pt | SemiBold (600) | 1.15 | Section headers, greeting text |
| `displaySmall` | 24pt | SemiBold (600) | 1.2 | Card headlines, modal titles |
| `titleLarge` | 20pt | Medium (500) | 1.25 | Card titles, dialog headers |
| `titleMedium` | 17pt | Medium (500) | 1.3 | List item titles, navigation headers |
| `bodyLarge` | 16pt | Regular (400) | 1.5 | Primary body text, AI chat messages |
| `bodyMedium` | 14pt | Regular (400) | 1.45 | Secondary body, descriptions |
| `bodySmall` | 12pt | Regular (400) | 1.4 | Captions, timestamps, metadata |
| `labelLarge` | 15pt | SemiBold (600) | 1.2 | Button text, action labels |
| `labelMedium` | 13pt | Medium (500) | 1.2 | Chip text, tab labels |
| `labelSmall` | 11pt | Medium (500) | 1.2 | Badge text, compact stats, unit labels |

### Font Assets

Font files in `zuralog/assets/fonts/`:
- `Outfit-Regular.ttf` (400)
- `Outfit-Medium.ttf` (500)
- `Outfit-SemiBold.ttf` (600)
- `Outfit-Bold.ttf` (700)

---

## Spacing & Shape

### Spacing Scale (4px Base Grid)

| Token | Value | Usage |
|-------|-------|-------|
| `2xs` | 2px | Hairline gaps, icon-to-text micro-spacing |
| `xs` | 4px | Tight gaps within components |
| `sm` | 8px | Default component internal padding |
| `md` | 12px | Gap between related elements |
| `base` | 16px | Standard padding, card internal padding |
| `lg` | 20px | Section gaps, generous card padding |
| `xl` | 24px | Screen horizontal margins, section separation |
| `2xl` | 32px | Major section breaks |
| `3xl` | 40px | Screen top padding (below status bar) |
| `4xl` | 48px | Hero spacing |
| `5xl` | 64px | Maximum breathing room |

### Border Radius (Soft & Rounded)

| Token | Value | Usage |
|-------|-------|-------|
| `none` | 0px | Flat edges (rare) |
| `sm` | 6px | Small inner elements, badges within cards |
| `md` | 12px | Inputs, inner containers, search bars |
| `lg` | 16px | Cards, content containers |
| `xl` | 20px | Large cards, feature panels |
| `2xl` | 24px | Bottom sheets, modals |
| `full` | 100px | Buttons, chips, badges, pills, avatars |

---

## Button System

All buttons use pill shape (`border-radius: 100px`).

### Button Hierarchy

| Variant | Background | Text | Border | Notes |
|---------|-----------|------|--------|-------|
| **Primary** | `#CFE1B9` + pattern overlay blend | `#344E41` | — | Signature treatment. Pattern image with `overlay` blend mode on sage base. |
| **Secondary** | `#344E41` solid | `#CFE1B9` | — | Deep forest fill. For secondary actions. |
| **Tertiary** | `rgba(207,225,185, 0.12)` | `#CFE1B9` | — | Sage tint fill. For lesser actions. |
| **Ghost** | transparent | `#CFE1B9` | 1.5px `rgba(207,225,185, 0.30)` | Outline only. For paired actions. |
| **Text** | transparent | `rgba(207,225,185, 0.60)` | — | No fill, no border. Inline actions. |
| **Destructive** | `rgba(255,59,48, 0.15)` | `#FF3B30` | — | Red tint fill. For delete/remove actions. |

### Light Mode Buttons

| Variant | Background | Text | Border |
|---------|-----------|------|--------|
| **Primary** | `#344E41` solid | `#CFE1B9` | — |
| **Secondary** | `rgba(52,78,65, 0.08)` | `#344E41` | — |
| **Ghost** | transparent | `#344E41` | 1.5px `rgba(52,78,65, 0.20)` |

### Button Sizes

| Size | Vertical Padding | Horizontal Padding | Font Size |
|------|-----------------|-------------------|-----------|
| Large | 18px | 28px | 16pt |
| Default | 14px | 24px | 15pt |
| Small | 10px | 18px | 13pt |

### Button States

- **Disabled:** 35% opacity on entire button
- **Pressed:** Slight scale-down (0.97) + darker shade
- **Loading:** Replace text with small spinner, maintain button width

---

## Icons

**Icon Set:** Lucide (1.5px stroke, round caps, round joins)
**Size:** 20–24px standard, 16px compact, 28px featured

### Active/Inactive Treatment

| State | Style | Details |
|-------|-------|---------|
| **Active** | Filled + sage pattern | Solid fill with `#CFE1B9`, pattern overlay blend. The signature brand treatment. |
| **Inactive** | Outlined thin | 1.5px stroke, `rgba(207,225,185, 0.35)` in dark mode, `rgba(52,78,65, 0.30)` in light mode |

This creates a clear, on-brand distinction between active and inactive states. The active icon gets the same sage + pattern signature as the primary button.

### Light Mode Icons

- **Active:** Filled solid `#344E41` (no pattern — too busy on light backgrounds)
- **Inactive:** Outlined thin `rgba(52,78,65, 0.30)`

---

## Navigation

### Bottom Tab Bar

**Style:** Always-visible labels — icon + text label on every tab
**Rationale:** A health app needs zero ambiguity. Users should never guess what a tab does.
**Anti-patterns:** No icon-only tabs, no floating pill indicators.

| Element | Dark Mode | Light Mode |
|---------|-----------|------------|
| Background | `#141E18` (canvas) | `#FAFAF5` (canvas) |
| Top border | `rgba(207,225,185, 0.06)` | `rgba(52,78,65, 0.08)` |
| Active icon | Filled + sage pattern | Filled `#344E41` |
| Active label | `#CFE1B9`, 600 weight, 10pt | `#344E41`, 600 weight, 10pt |
| Inactive icon | Outlined, 35% opacity | Outlined, 30% opacity |
| Inactive label | `rgba(207,225,185, 0.35)`, 400 weight | `rgba(52,78,65, 0.30)`, 400 weight |

### App Bar

- Large title style with greeting subtitle
- Right-side: notification bell (outlined icon), avatar button (opens profile side panel)
- Collapse to compact on scroll

### Tabs (5 main tabs)

1. **Today** — Clock icon
2. **Data** — Bar chart icon
3. **Log** — Plus icon (also global FAB)
4. **Coach** — Moon/AI icon
5. **Profile** — Person icon

---

## Motion & Animation

**Philosophy:** Gentle & Organic — calming, not urgent
**Easing:** `cubic-bezier(0.16, 1, 0.3, 1)` — expo-out for all entrances and transitions
**Reduced motion:** All animations respect `prefers-reduced-motion` / `MediaQuery.disableAnimations`

### Duration Scale

| Token | Duration | Usage |
|-------|----------|-------|
| `micro` | 200ms | Opacity toggles, color changes, icon state swaps |
| `standard` | 400ms | Standard transitions, component state changes |
| `entrance` | 600ms | Page/section entrance animations |

### Entrance Animations

- **Staggered fade-slide:** Cards appear with `opacity: 0 → 1` + `translateY(16px → 0)`, staggered 60–80ms per sibling
- **Properties:** Only `opacity` and `transform` (GPU composited, 60fps)
- **No bounce/elastic easing** — elements decelerate smoothly with expo-out

### Loading States

- **Skeleton shimmer:** Gradient sweep from left to right (`rgba(sage, 0.04)` → `rgba(sage, 0.08)` → `rgba(sage, 0.04)`), 2s duration, infinite loop
- **Progress fill:** Smooth fill with expo-out easing, 1200ms, delayed 400ms after card entrance

### Interaction Feedback

- **Button press:** Scale to 0.97, 100ms
- **Tab switch:** Cross-fade content, 200ms
- **Card tap:** Subtle scale to 0.98 + slight brightness increase
- **Swipe-to-dismiss:** Follow finger with resistance physics, snap to dismiss at 40% threshold

---

## Component Reference

### Cards (4 Tiers)

| Tier | Background | Border | Pattern | Use Case |
|------|-----------|--------|---------|----------|
| **Standard** | `surface` (#1E2E24) | `border-default` | None | Default content cards |
| **Accent** | `surface` | `border-default` + 3px pattern top-edge | Top accent strip | Featured cards, highlights |
| **Sage** | `#CFE1B9` | — | Overlay blend | Call-to-action cards, premium features |
| **Forest** | `#344E41` | — | 15–20% opacity texture | Deep accent cards |

### Inputs

| Property | Value |
|----------|-------|
| Background | `rgba(sage, 0.06)` dark / `rgba(forest, 0.04)` light |
| Border | `border-default`, focused: `border-strong` |
| Border radius | `md` (12px) |
| Padding | 12px vertical, 16px horizontal |
| Placeholder | `text-muted` color |
| Text | `text-primary` color |

### Chips

| State | Background | Text | Border |
|-------|-----------|------|--------|
| Default | transparent | `text-muted` | `border-default` |
| Selected | `rgba(sage, 0.12)` | `sage` | — |
| Category | `rgba(categoryColor, 0.15)` | category color | — |

Border radius: `full` (100px)

### Toasts / Snackbars

| Variant | Background | Icon | Text |
|---------|-----------|------|------|
| Success | `surface-raised` | ✓ in `success` | `text-primary` |
| Error | `surface-raised` | ✗ in `error` | `text-primary` |
| Info | `surface-raised` | ℹ in `sage` | `text-primary` |

Border radius: `lg` (16px). Centered at bottom with 20px margin. Entrance: slide up + fade.

### Badges

| Variant | Background | Text |
|---------|-----------|------|
| Sage | `rgba(sage, 0.15)` | `sage` |
| Category | `rgba(categoryColor, 0.15)` | category color |
| Positive delta | `rgba(success, 0.15)` | `success` |
| Negative delta | `rgba(error, 0.15)` | `error` |

Border radius: `full` (100px). Padding: 4px 10px.

### Empty States

- Centered layout
- Muted icon or illustration (outlined style, 48px)
- Headline in `text-secondary`
- Body in `text-muted`
- Primary CTA button below

### Lists

- Items separated by `border-default` hairline divider
- 16px vertical padding per item
- Leading: icon in circle badge or avatar
- Trailing: chevron, value text, or toggle

---

## Screen Background

**Dark mode:** Solid `#141E18` (Ink Green) — no pattern, no texture, no gradient
**Light mode:** Solid `#FAFAF5` (Warm White)

The pattern lives on components, not the background. The clean canvas lets pattern-treated elements stand out.

---

## Future Considerations

These areas are designed to follow the same token system and pattern treatments when implemented:

- **Coach Chat UI** — User bubbles (sage/forest), AI bubbles (surface), typing indicator, streaming text
- **Chart Palette** — Category colors on dark/light chart surfaces, reference lines, grid lines
- **Onboarding Flow** — Welcome screens, auth forms, questionnaire steps
- **Widget/Watch Complications** — Compact pattern usage on small surfaces
