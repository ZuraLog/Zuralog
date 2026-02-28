# Zuralog — Design System & Brand Guidelines

**Version:** 2.0  
**Last Updated:** 2026-03-01  
**Status:** Living Document

---

## Design Philosophy

Zuralog's design follows an **exploration-first** approach: the brand constants (color palette, typography, spacing) stay fixed and create consistency, while the UI/UX layout is always open to improvement and exploration. Agents and designers should never feel locked into a specific screen layout — always seek the best experience for the user.

**What stays constant:**
- Color palette and semantic tokens
- Typography (Inter font family)
- Spacing and border radius conventions

**What should always be explored:**
- Screen layouts, card arrangements, navigation patterns
- Animation styles and motion design
- User flows and information hierarchy
- Component visual treatments

> Never lock into a specific design direction in documentation. Encourage better solutions when they exist.

---

## Color Palette

### Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `sage-green` | `#CFE1B9` | Primary brand accent — buttons, highlights, active states |
| `sage-dark` | `#A8C68A` | Pressed states, secondary accent |
| `sage-light` | `#E8F3D6` | Subtle backgrounds, badge fills |

### Surface Colors (Dark Theme — Primary)

| Token | Hex | Usage |
|-------|-----|-------|
| `surface-900` | `#0A0A0A` | Primary background (near-black) |
| `surface-800` | `#121212` | Card backgrounds |
| `surface-700` | `#1C1C1E` | Elevated cards, bottom sheets |
| `surface-600` | `#2C2C2E` | Dividers, disabled states |
| `surface-500` | `#3A3A3C` | Input backgrounds, chips |

### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | `#FFFFFF` | Primary text |
| `text-secondary` | `#ABABAB` | Secondary text, captions, hints |
| `text-tertiary` | `#636366` | Placeholder text, disabled |
| `text-inverse` | `#0A0A0A` | Text on sage-green buttons |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#34C759` | Connected states, positive metrics |
| `warning` | `#FF9500` | Caution states, approaching limits |
| `error` | `#FF3B30` | Error states, disconnected |
| `syncing` | `#007AFF` | Loading/syncing indicators |

---

## Typography

**Font Family:** Inter (all platforms — loaded as a custom font in Flutter, imported from Google Fonts on the website)

### Flutter (AppTextStyles)

| Style | Font Size | Weight | Usage |
|-------|-----------|--------|-------|
| `displayLarge` | 32pt | SemiBold (600) | Hero text, screen titles |
| `displayMedium` | 24pt | SemiBold (600) | Section headers |
| `titleLarge` | 20pt | Medium (500) | Card titles, dialog headers |
| `titleMedium` | 17pt | Medium (500) | List item titles |
| `bodyLarge` | 16pt | Regular (400) | Primary body text |
| `bodyMedium` | 14pt | Regular (400) | Secondary body, descriptions |
| `bodySmall` | 12pt | Regular (400) | Captions, timestamps, metadata |
| `labelLarge` | 15pt | SemiBold (600) | Button text |
| `labelMedium` | 13pt | Medium (500) | Chip text, tab labels |
| `labelSmall` | 11pt | Medium (500) | Badge text, stats |

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
| `md` | 16px | Standard element padding |
| `lg` | 24px | Section spacing |
| `xl` | 32px | Screen-level padding |
| `xxl` | 48px | Major section breaks |

### Border Radius

| Context | Radius |
|---------|--------|
| Cards | 16px |
| Buttons | 12px |
| Chips / Tags | 8px |
| Bottom sheets | 24px (top corners only) |
| Avatars / Icons | 50% (circular) |

---

## Component Conventions

### Buttons

- **Primary action:** Filled sage-green background, black text — `#CFE1B9` fill, `#0A0A0A` text
- **Secondary action:** Outlined (1px sage-green border), sage-green text on transparent
- **Destructive action:** Outlined red border, red text
- **Ghost:** No border, secondary text color — for low-emphasis actions

### Cards

- Background: `surface-800` (`#121212`)
- Border: 1px `surface-600` (`#2C2C2E`) — subtle definition
- Radius: 16px
- Padding: 16px (`md`)
- Elevation: none (flat design; rely on color contrast)

### Integration Tiles

- Connected state: sage-green dot + "Connected" label
- Available state: standard styling
- Coming Soon: 50% opacity, no interactive affordance
- Platform badge (iOS only / Android only): small pill in top corner

### Chat Bubbles

- User messages: sage-green background, right-aligned
- AI messages: `surface-700` background, left-aligned, markdown-rendered
- Streaming: animated typing indicator

---

## Navigation Structure

**Bottom tab bar (5 tabs):**

| Tab | Icon | Screen |
|-----|------|--------|
| Chat | chat bubble | AI Chat (primary) |
| Dashboard | grid/chart | Health Dashboard |
| Integrations | plug/link | Integrations Hub |
| Analytics | bar chart | Correlations + Trends |
| Settings | gear | Settings |

---

## Dark Theme First

Zuralog is **dark-only** — no light mode. This is a deliberate product decision:
- Health data dashboards are easier to read on dark backgrounds
- Premium aesthetic aligned with the "high-performance athlete" target user
- Consistent experience across all screens without theme-switching complexity

---

## Motion & Animation

### Principles

- **Purposeful:** Animations communicate state changes, not just decoration
- **Fast:** Keep durations short (150–300ms) to feel responsive
- **Natural:** Ease curves that feel physical, not robotic

### Flutter Durations

| Context | Duration |
|---------|----------|
| Button press | 100ms |
| Tab switch | 200ms |
| Card expansion | 250ms |
| Screen transition | 300ms |
| Loading skeleton | 1200ms (loop) |

### Website

The website uses GSAP + Framer Motion for more expressive marketing animations (hero text reveals, scroll-triggered effects). These are intentionally more theatrical than the mobile app animations.

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
