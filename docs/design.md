# Zuralog — Design System

Dark mode is the primary experience. Light mode will be designed separately as a respectful inversion.

---

## Brand Essence

Zuralog is a premium AI health assistant. The design should feel calm, confident, and organic — like a high-end wellness product, not a clinical dashboard. The topographic contour-line pattern is the brand's visual signature and appears throughout the interface on interactive and hero elements.

**North star feeling:** Premium wellness. Calm confidence. Nature meets technology.

---

## Foundations

### Canvas & Elevation

The app uses a neutral charcoal canvas with the faintest warm whisper. Surfaces are distinguished by brightness alone — no borders, no shadows. Each elevation step is exactly +8 brighter across all RGB channels.

| Token | Hex | Usage |
|-------|-----|-------|
| Canvas | `#161618` | Screen background |
| Surface | `#1E1E20` | Cards, content containers |
| Surface Raised | `#272729` | Popovers, dropdowns, tooltips |
| Surface Overlay | `#313133` | Modals, bottom sheets |

No borders between elevation levels. The brightness difference alone creates separation.

### Typography

**Font family:** Plus Jakarta Sans (all platforms).

Geometric, modern, and refined. Numbers render beautifully at every size — critical for a health app full of metrics. Feels both premium and approachable.

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Display Large | 34pt | Bold 700 | Hero numbers, screen titles |
| Display Medium | 28pt | SemiBold 600 | Section headers, greetings |
| Display Small | 24pt | SemiBold 600 | Card headlines, modal titles |
| Title Large | 20pt | Medium 500 | Card titles, dialog headers |
| Title Medium | 17pt | Medium 500 | List item titles, nav headers |
| Body Large | 16pt | Regular 400 | Primary body, chat messages |
| Body Medium | 14pt | Regular 400 | Descriptions, secondary body |
| Body Small | 12pt | Regular 400 | Captions, timestamps |
| Label Large | 15pt | SemiBold 600 | Button text, action labels |
| Label Medium | 13pt | Medium 500 | Chip text, tab labels |
| Label Small | 11pt | Medium 500 | Badge text, unit labels |

### Color — Accent System

Two accent roles, clearly separated:

**Sage (`#CFE1B9`)** — the brand color. Used for primary actions: filled buttons, active toggles, links, badges, and health-positive indicators. When a user sees Sage, it means "tap this" or "this is good."

**Warm White (`#F0EEE9`)** — the UI color. Used for navigation and secondary controls: active tab indicators, segmented control selection, outlined button text. When a user sees Warm White, it means "go here" or "this is selected."

### Color — Text

| Token | Hex | Usage |
|-------|-----|-------|
| Text Primary | `#F0EEE9` | Headlines, metric values, body text |
| Text Secondary | `#9B9894` | Labels, captions, muted descriptions |
| Text On Sage | `#1A2E22` | Text sitting on Sage-filled surfaces |
| Text On Warm White | `#161618` | Text sitting on Warm White surfaces (e.g., active segmented control) |

### Color — Health Categories

These are fixed across light and dark mode. They identify health domains throughout the app.

| Category | Hex |
|----------|-----|
| Activity | `#30D158` |
| Sleep | `#5E5CE6` |
| Heart | `#FF375F` |
| Nutrition | `#FF9F0A` |
| Body | `#64D2FF` |
| Vitals | `#6AC4DC` |
| Wellness | `#BF5AF2` |
| Cycle | `#FF6482` |
| Mobility | `#FFD60A` |
| Environment | `#63E6BE` |

### Color — Semantic / Status

| Name | Hex | Usage |
|------|-----|-------|
| Success | `#34C759` | Connected, positive deltas, goal done |
| Warning | `#FF9500` | Caution, approaching limits |
| Error / Destructive | `#FF3B30` | Errors, delete actions, destructive buttons |
| Syncing | `#007AFF` | Loading/sync indicators |
| Streak Warm | `#FF9500` | Streak flame accent |

### Spacing

Based on a 4px grid with a 2px fine-tuning step.

| Token | Value |
|-------|-------|
| XXS | 2px |
| XS | 4px |
| SM | 8px |
| MD | 16px |
| MD+ | 20px |
| LG | 24px |
| XL | 32px |
| XXL | 48px |

### Shape (Border Radius)

| Token | Value | Usage |
|-------|-------|-------|
| XS | 8px | Chips, tags, tooltips |
| SM | 12px | Inputs, snackbars |
| MD | 16px | Metric tiles, compact cards |
| LG | 20px | Feature cards, hero cards |
| XL | 28px | Bottom sheets, modals |
| Pill | 100px | All buttons, pills |

### Topographic Pattern

The contour-line pattern is the brand's visual signature. It does not appear as wallpaper. It is applied selectively to mark interactive and important elements.

**Pattern variants** are pre-colored PNG files stored in `assets/brand/pattern/`. Each variant matches a surface or category color:

| Variant File | Usage |
|-------------|-------|
| `Sage.PNG` | Primary buttons, toggles, checkboxes, sliders, chips, FAB — any Sage-filled surface |
| `Crimson.PNG` | Destructive buttons, error-related surfaces |
| `Green.PNG` | Success toasts, Activity category cards |
| `Periwinkle.PNG` | Sleep category cards |
| `Rose.PNG` | Heart category cards |
| `Amber.PNG` | Nutrition category cards, Warning states |
| `Sky Blue.PNG` | Body category cards |
| `Teal.PNG` | Vitals/Environment category cards |
| `Purple.PNG` | Wellness category cards |
| `Yellow.PNG` | Mobility category cards |
| `Original.PNG` | Dark surfaces — hero cards, feature cards, avatars, search bar, tab tracks, empty states, onboarding |

**Blend modes:**
- On **light/colored surfaces** (Sage buttons, destructive buttons, category cards): **color-burn** blend, 15% opacity. Color-burn deepens the dark contour lines while leaving light areas untouched, creating crisp etched lines.
- On **dark surfaces** (hero cards, feature cards, avatars, search bar, etc.): **screen** blend, opacity varies by component (4-15%). Screen lightens the pattern onto the dark canvas.

**Where the pattern appears:**
- **Hero cards** — Original.PNG, 10% opacity, screen blend
- **Feature cards** (AI insights, streaks, achievements) — Original.PNG, 7% opacity, screen blend
- **Category-specific feature cards** — matching color variant, 7% opacity, screen blend (e.g., a Sleep insight uses Periwinkle.PNG)
- **Primary buttons** — Sage.PNG, 15% opacity, color-burn blend
- **Destructive buttons** — Crimson.PNG, 15% opacity, color-burn blend
- **All Sage-filled inputs** (toggles, checkboxes, sliders) — Sage.PNG, 15% opacity, color-burn blend
- **FAB** — Sage.PNG, 18% opacity, color-burn blend (larger surface = slightly higher opacity)

**Where the pattern does NOT appear:**
- Screen canvas / background
- Data cards and metric tiles (raw numbers stay clean)
- Secondary (outlined) buttons
- Text buttons
- Text input fields
- Navigation bars

---

## Components

### Buttons

Buttons use pill radius (100px) at all sizes. The topographic pattern appears on all filled buttons to mark them as significant actions.

**Primary (Sage fill + pattern)**
- Background: Sage `#CFE1B9`
- Text: `#1A2E22` (Text On Sage), SemiBold 600
- Pattern: `brand_pattern.png`, 12% opacity, multiply blend
- Usage: The main action on a screen. "Log Activity", "Connect", "Save"

**Destructive (Red fill + pattern)**
- Background: Error `#FF3B30`
- Text: `#FFFFFF`, SemiBold 600
- Pattern: `brand_pattern.png`, 12% opacity, multiply blend
- Usage: Dangerous or irreversible actions. "Delete Account", "Disconnect"

**Secondary (Outlined, no pattern)**
- Background: transparent
- Border: `rgba(240, 238, 233, 0.2)` (1.5px)
- Text: Warm White `#F0EEE9`, SemiBold 600
- No pattern. This is the deliberately quiet option.
- Usage: Alternative actions. "View Details", "Skip", "Cancel"

**Text (no pattern, no background)**
- Text: Sage `#CFE1B9`, SemiBold 600
- No background, no border, no pattern.
- Lowest visual emphasis. Used for tertiary actions.
- Usage: "See all →", "Learn more", inline actions

**Button sizes:**

| Size | Height | Horizontal Padding | Text Style |
|------|--------|-------------------|------------|
| Large | 52px | 28px | Label Large (15pt, SemiBold 600) |
| Medium | 44px | 24px | Label Large (15pt, SemiBold 600) |
| Small | 32px | 18px | Label Medium (13pt, Medium 500) |

**Button states:**
- **Pressed/Active:** opacity drops to 85%, slight scale-down (0.97)
- **Disabled:** opacity 40%, no pattern visible, no interaction
- **Loading:** text replaced with Sage spinner (primary) or white spinner (destructive), button stays same size

**Visual hierarchy:**
Pattern + fill = primary emphasis → Plain outline = secondary → Bare text = tertiary

### Cards & Containers

Cards use soft, rounded corners with generous padding. The goal is a calm, breathing layout where each card feels like its own space.

**Standard card**
- Background: Surface `#1E1E20`
- Border radius: LG (20px) for feature cards, MD (16px) for metric tiles
- Padding: MD+ (20px) for feature cards, MD (16px) for metric tiles
- No border. Elevation is communicated through brightness alone.
- No pattern on standard cards.

**Hero card (pattern — 10%)**
- Same as standard card, plus the topographic pattern at 10% opacity, screen blend
- Used for: Health score card, the single most important card on a screen
- Only one hero card per screen.

**Feature card (pattern — 7%)**
- Same as standard card, plus the topographic pattern at 7% opacity, screen blend (slightly softer than hero)
- Used for: AI-generated insight cards, streak cards, achievement cards, trend/correlation cards
- The rule: **AI-generated or celebratory content gets the pattern. Raw numbers don't.**

**Data card (no pattern)**
- Standard card with no pattern treatment
- Used for: Metric tiles (steps, sleep, calories), settings groups, list containers, any card that displays raw data without interpretation
- These stay clean so the numbers are the focus

**The pattern rule for cards:** If the card is telling you something smart (an AI insight, a discovered pattern, a celebration), it gets the pattern. If the card is just showing a number, it stays plain.

**Card grid spacing**
- Gap between cards: 12px
- Gap between metric tiles: 12px
- Section spacing: 24px (LG)

### Navigation

**Top App Bar**
- Background: transparent (canvas shows through)
- Title: Text Primary `#F0EEE9`, Display Medium (28pt, SemiBold)
- Right action: avatar circle in Surface Raised `#272729`
- No border, no shadow. The top bar is part of the canvas, not a separate element.
- On scroll: stays transparent. Content scrolls underneath.

**Bottom Navigation Bar**
- Style: floating pill bar
- Background: Surface `#1E1E20`, pill radius (100px)
- Horizontal margin: MD+ (20px) from screen edges
- Bottom padding: safe area + 18px
- Each tab: icon + label pair
- Active tab: Sage tint pill background `rgba(207, 225, 185, 0.12)`, Sage text `#CFE1B9` — the bottom nav is the only navigation element that uses Sage instead of Warm White, because it is the app's primary branded surface and should feel like part of the Zuralog identity, not generic chrome
- Inactive tabs: Text Secondary `#9B9894`
- Tab icons: Material Symbols (or custom set), 20-22px

**Tab icons:**
- Today: sun/sunrise
- Data: grid/chart bars
- Coach: chat bubble or sparkle
- Progress: target or trophy
- Trends: trending line

### Inputs & Selection

All inputs use the filled style — Surface fill with no border. Consistent with the elevation system where surfaces are distinguished by brightness alone.

**The Sage pattern rule for inputs:** Any Sage-filled interactive surface gets the topographic pattern at 12% opacity, multiply blend. This includes checkboxes, toggle tracks, and slider thumbs.

**Text Field**
- Background: Surface `#1E1E20`, border radius SM (12px)
- Label: Text Secondary `#9B9894`, Label Small (11pt, Medium 500)
- Value text: Text Primary `#F0EEE9`, Body Large (16pt, Regular 400)
- Placeholder: Text Secondary `#9B9894`, Body Large (16pt, Regular 400)
- Focus state: Sage border `rgba(207, 225, 185, 0.3)` appears on focus
- Error state: Error red border `rgba(255, 59, 48, 0.5)`, error message below in Error red, Body Small (12pt)
- Disabled state: opacity 40%, no interaction
- No pattern (Surface fill, not Sage fill)

**Text Area**
- Same as text field but taller, min-height 120px
- Resize handle in Text Secondary

**Password Field**
- Same as text field with obscured characters and a show/hide toggle icon

**Toggle Switch**
- On: Sage `#CFE1B9` track with pattern (12%, multiply), white thumb
- Off: Surface Raised `#272729` track, Text Secondary `#9B9894` thumb
- Size: 44×26px

**Slider**
- Active track: Sage `#CFE1B9` with pattern (10%, multiply)
- Inactive track: Surface Raised `#272729`
- Thumb: Sage `#CFE1B9` with pattern (12%, multiply), 18px diameter
- Track height: 6px

**Checkbox**
- Checked: Sage `#CFE1B9` fill with pattern (12%, multiply), dark checkmark `#1A2E22`
- Unchecked: Text Secondary `#9B9894` border (2px), transparent fill
- Size: 20×20px, border radius 4px

**Radio Button**
- Selected: Sage `#CFE1B9` border with solid Sage inner dot (dot too small for pattern)
- Unselected: Text Secondary `#9B9894` border, transparent fill
- Size: 20×20px

**Dropdown**
- Same as text field with a chevron icon on the right
- Opens a bottom sheet or popup menu on the Surface Raised level

**Date Picker / Time Picker**
- Presented as a bottom sheet (Surface Overlay level)
- Selected values highlighted with Sage tint background
- Confirm button: Primary (Sage + pattern)

**Stepper**
- Plus/minus buttons: Surface Raised `#272729` fill, 32px circles
- Value: Text Primary, centered between buttons

**Rating Bar**
- Filled stars: Sage `#CFE1B9`
- Empty stars: Surface Raised `#272729`

**Segmented Control**
- Background: Surface `#1E1E20`, pill radius
- Active segment: Warm White `#F0EEE9` fill, Text On Warm White `#161618`
- Inactive segments: Text Secondary `#9B9894`
- This uses Warm White (not Sage) because it's a navigation/selection control, not an action

### Feedback & Communication

All feedback components follow the elevation system. Higher urgency = higher elevation level.

**Icons & Emojis:** Always flat — no gradients, no 3D effects. Use simple line icons or flat filled icons. This keeps the visual language clean and allows the pattern to be applied on filled icon surfaces.

**Toast / Snackbar**
- Background: Surface Raised `#272729`, pill radius (100px)
- Text: Text Primary `#F0EEE9`, Body Medium (14pt)
- Status dot: 8px circle, color matches status (Success green, Error red, etc.) with pattern (12%, multiply) on Sage/green dots
- Action text (optional): Sage `#CFE1B9`, SemiBold — acts as a text button ("Retry", "Undo")
- Auto-dismisses after 3-4 seconds. Snackbar stays until action is taken or manually dismissed.
- Position: centered horizontally, near top of screen (below safe area)

**Alert Dialog**
- Background: Surface Overlay `#313133`, XL radius (28px)
- Title: Text Primary, Title Medium (17pt, Medium)
- Body: Text Secondary `#9B9894`, Body Medium (14pt)
- Buttons: Primary (Sage + pattern) or Destructive (Red + pattern) for confirm, Secondary (outlined) for cancel
- Scrim: black at 50% opacity behind the dialog

**Bottom Sheet**
- Background: Surface Overlay `#313133`, rounded top corners XL (28px)
- Drag handle: 36×4px, Text Secondary at 40% opacity, centered
- Content follows standard card/list patterns inside
- Scrim: black at 40% opacity

**Linear Progress Bar**
- Active track: Sage `#CFE1B9` with pattern (10%, multiply)
- Inactive track: Surface Raised `#272729`
- Height: 4px, border radius 2px
- Label above: Text Secondary for context ("Syncing Fitbit..."), Sage for value ("65%")

**Circular Progress Spinner**
- Sage `#CFE1B9` spinning arc
- Track: Surface Raised `#272729`

**Pull-to-Refresh**
- Sage spinner appears on pull-down
- Canvas background — no separate refresh container

**Skeleton Loader**
- Container: Surface `#1E1E20`, standard card radius
- Shimmer blocks: Surface Raised `#272729`, small radius (6px)
- Animate with a subtle left-to-right shimmer (Sage tint at very low opacity)

**Tooltip**
- Background: Surface Raised `#272729`, XS radius (8px)
- Text: Text Primary `#F0EEE9`, Body Small (12pt)
- Pointer triangle in matching Surface Raised color
- Appears on long-press, dismisses on tap elsewhere

**Badge**
- Background: Error `#FF3B30` (for notifications) or Sage (for positive counts)
- Text: white, Label Small (11pt, Bold 700)
- Size: 16px min diameter, pill-shaped for multi-digit numbers
- Border: 2px Canvas `#161618` to lift off the parent icon

### Display Components

**Chip / Filter Tag**
- Shape: pill radius (100px)
- Active: Sage tint background `rgba(207, 225, 185, 0.15)` with pattern (8%, screen), Sage text
- Inactive: Surface `#1E1E20`, Text Secondary
- Size: padding 8px 16px (SM vertical, MD horizontal), Label Medium text (13pt)

**List Item**
- Container: Surface `#1E1E20` card, grouped with dividers between rows
- Icon: 32px Surface Raised square, radius 8px, with pattern (12%, screen) — adds texture to icon containers
- Title: Text Primary, Body Medium (14pt, Regular 400)
- Subtitle: Text Secondary, Label Small (11pt, Medium 500)
- Trailing: chevron arrow or value text in Text Secondary
- Row padding: 12px 16px (SM vertical, MD horizontal)
- Dividers between rows: 1px `rgba(240, 238, 233, 0.04)`

**Avatar**
- Shape: circle
- Sizes: 48px (large), 36px (medium), 24px (small)
- Photo: circular crop, no border
- Default (no photo): Surface Raised `#272729` with pattern (15%, screen), Sage initials centered — a branded placeholder that's distinctly Zuralog
- The pattern on default avatars is an intentional exception to the "Sage fill = pattern" rule

**Divider**
- 1px solid `rgba(240, 238, 233, 0.06)`
- Used between list items and between content sections
- Full-bleed within cards, inset (16px margin) between standalone sections

**Accordion**
- Container: Surface `#1E1E20` card, LG radius
- Header: Title text + Sage chevron arrow, 12px 16px padding (SM vertical, MD horizontal)
- Expanded content: below a divider, same padding
- Chevron rotates 180° on expand with gentle animation

**Carousel**
- Horizontal scroll of standard Surface cards
- 12px gap between cards
- Right edge: next card peeks in (20-30px visible) to hint scrollability
- No pagination dots — the peek is the affordance

**Grid Tile**
- Same as data card: Surface `#1E1E20`, MD radius (16px), 16px padding
- Used in 2-column metric grids on Today and Data tabs

**Image View**
- Border radius: MD (16px) to match card system
- Loading state: Surface `#1E1E20` placeholder with skeleton shimmer

**Hero Image / Banner**
- Full-width, top of screen
- Pattern overlay (10%, screen) when used as a branded header
- Content overlaid with gradient scrim from bottom if text sits on image

### Action Components (continued)

**Floating Action Button (FAB)**
- Shape: 56px circle
- Background: Sage `#CFE1B9` with pattern (15%, multiply)
- Icon: `#1A2E22`, 24px
- Shadow: `0 4px 12px rgba(0, 0, 0, 0.3)` — the only component with a shadow, needed to lift it off scrolling content
- Position: bottom-right, above the floating nav pill
- The FAB is a primary action — same pattern rule as buttons. The larger surface makes contour lines more visible.

**Icon Button**
- Shape: 40px circle or 40px rounded square (radius 10px)
- Background: Surface Raised `#272729` or transparent
- Icon: Text Primary or Sage depending on context
- No pattern (too small and not Sage-filled)

**Split Button**
- Primary section: Sage fill + pattern (same as primary button)
- Dropdown trigger: Surface Raised, separated by a 1px Sage divider
- Pill radius on the combined shape

### Navigation Components (continued)

**Search Bar**
- Background: Surface `#1E1E20` with pattern (5%, screen), radius SM (12px)
- Placeholder: Text Secondary `#9B9894`, search icon left-aligned
- Active/typing: Sage border appears `rgba(207, 225, 185, 0.3)`
- The faint pattern makes the search bar feel branded rather than generic

**Tabs (horizontal row)**
- Used for switching views within a screen (e.g., Day/Week/Month)
- Background track: Surface `#1E1E20` with pattern (4%, screen), radius 12px, padding 4px
- Active tab: Warm White `#F0EEE9` fill, dark text, radius 9px — no pattern (navigation element)
- Inactive tabs: Text Secondary, transparent background
- The pattern peeks through the inactive track areas, creating a layered effect

**Breadcrumbs**
- Text Secondary for ancestor links, Text Primary for current
- Separator: `/` or `›` in Text Secondary
- Sage on hover/tap for ancestor links

**Pagination**
- Active dot: Sage `#CFE1B9` fill, 8px
- Inactive dots: Surface Raised `#272729`, 6px
- Used sparingly — prefer carousel peek or infinite scroll

### Special Surfaces

**Empty State**
- Container: Feature card treatment — Surface `#1E1E20`, LG radius (20px), with pattern (6%, screen)
- Flat icon: centered, 36px
- Title: Text Primary, Title Medium
- Description: Text Secondary, Body Medium, centered
- CTA button: Primary (Sage + pattern)
- Empty states are "feature cards" — they communicate and invite action. The pattern makes them feel intentional and branded, not like error pages.

**Onboarding / Welcome Screens**
- Full branded hero surface: Surface `#1E1E20`, LG radius (20px), with pattern (10%, screen)
- The richest pattern treatment in the app — this is the user's first impression
- Title in Sage, body in Text Secondary
- Primary CTA button at bottom

**Error State**
- Same layout as empty state but without pattern
- Icon in Error red, description explains what went wrong
- Retry button: Primary (Sage + pattern)

**Scroll View**
- Standard scrollable container on Canvas background
- No pattern on the scroll surface itself — content provides the visual interest
- Pull-to-refresh: Sage spinner

---

## Pattern Reference Table

A complete summary of every surface that gets the topographic pattern treatment.

| Component | Pattern Variant | Opacity | Blend Mode | Notes |
|-----------|----------------|---------|------------|-------|
| Primary button | Sage.PNG | 15% | Color-burn | All sizes |
| Destructive button | Crimson.PNG | 15% | Color-burn | |
| FAB | Sage.PNG | 18% | Color-burn | Larger surface = higher opacity |
| Hero card | Original.PNG | 10% | Screen | One per screen max |
| Feature card (generic) | Original.PNG | 7% | Screen | AI or celebratory content |
| Feature card (Sleep) | Periwinkle.PNG | 7% | Screen | Category-colored |
| Feature card (Activity) | Green.PNG | 7% | Screen | Category-colored |
| Feature card (Heart) | Rose.PNG | 7% | Screen | Category-colored |
| Feature card (Nutrition) | Amber.PNG | 7% | Screen | Category-colored |
| Feature card (Body) | Sky Blue.PNG | 7% | Screen | Category-colored |
| Feature card (Wellness) | Purple.PNG | 7% | Screen | Category-colored |
| Feature card (Vitals) | Teal.PNG | 7% | Screen | Category-colored |
| Feature card (Mobility) | Yellow.PNG | 7% | Screen | Category-colored |
| Empty state card | Original.PNG | 6% | Screen | Branded empty states |
| Onboarding / welcome | Original.PNG | 10% | Screen | Richest treatment |
| Toggle track (on) | Sage.PNG | 15% | Color-burn | |
| Slider thumb + track | Sage.PNG | 15% / 12% | Color-burn | |
| Checkbox (checked) | Sage.PNG | 15% | Color-burn | |
| Progress bar (active) | Sage.PNG | 12% | Color-burn | |
| Active chip | Original.PNG | 8% | Screen | Sage-tinted dark surface |
| Default avatar | Original.PNG | 15% | Screen | Branded placeholder |
| List icon squares | Original.PNG | 12% | Screen | Settings icon containers |
| Search bar | Original.PNG | 5% | Screen | Very subtle |
| Tab track (inactive) | Original.PNG | 4% | Screen | Behind active segment |
| Toast dot (success) | Green.PNG | 15% | Color-burn | Light fill |
| Hero image/banner | Original.PNG | 10% | Screen | Branded headers |

**The blend mode rule:**
- **Light/colored surfaces** → color-burn blend (etches the contour lines into the surface)
- **Dark surfaces** → screen blend (lightens the pattern onto the surface)
- Tinted surfaces (low-opacity Sage over dark) count as dark surfaces and use screen blend

**Category-colored pattern:** When a feature card belongs to a specific health category (e.g., a Sleep insight), use the matching color variant instead of Original.PNG. This makes each health domain feel visually distinct.

**Split button dropdown trigger:** No pattern. Only the primary action section gets the pattern.

---

## Motion & Animation

Motion is gentle and intentional. Nothing snaps or bounces aggressively.

| Duration | Usage |
|----------|-------|
| 150ms | Micro-interactions: button press, toggle flip, checkbox check |
| 250ms | Standard transitions: card expand, chip select, dropdown open |
| 350ms | Major transitions: screen push, bottom sheet slide, modal appear |
| 600ms | Staggered entrances: card feed loading, list population |

**Easing:** `Curves.easeOut` (fast start, gentle stop) for entrances. `Curves.easeIn` for exits. `Curves.easeInOut` for transitions that both enter and leave.

**Staggered animations:** When multiple cards appear at once (e.g., the Today tab loading), each card delays 60ms after the previous one. This creates a cascading "waterfall" effect.

**Reduced motion:** Respect the system accessibility setting. When reduced motion is enabled, all animations resolve instantly (duration 0) except essential feedback like pull-to-refresh.

---

## Interaction & Accessibility

### Touch Targets

All interactive elements must have a minimum touch target of 44×44pt, even if the visual element is smaller. For components like checkboxes (20×20px) and radio buttons (20×20px), the hit area extends invisibly to meet the 44pt minimum.

### Contrast Ratios

- Text Primary `#F0EEE9` on Canvas `#161618`: 13.5:1 (exceeds AAA)
- Text Secondary `#9B9894` on Canvas `#161618`: 5.8:1 (exceeds AA)
- Text On Sage `#1A2E22` on Sage `#CFE1B9`: 9.2:1 (exceeds AAA)
- Sage `#CFE1B9` on Canvas `#161618`: 10.4:1 (exceeds AAA)

### Focus Indicators

When navigating with keyboard or assistive technology, focused elements show a 2px Sage outline offset by 2px from the element edge.

### Screen Readers

All interactive elements must have descriptive labels. Icons used as buttons must have `semanticLabel` set. Decorative elements (pattern overlays, dividers) are marked as non-accessible.

---

## Hero vs Feature Card Assignments

To remove ambiguity, here are the specific hero and feature card assignments per screen:

**Today tab:**
- Hero: Health Score card
- Feature: AI insight cards, streak card

**Data tab:**
- Hero: Health Score summary (if shown at top)
- Feature: Category summary cards with interpretive text

**Coach tab:**
- No hero card — the chat interface is the primary surface

**Progress tab:**
- Hero: Active goal spotlight or streak hero
- Feature: Achievement cards, journal prompt card

**Trends tab:**
- Hero: Top correlation card (highest confidence)
- Feature: All other correlation cards

**Settings:**
- No hero or feature cards — settings uses data cards and list items only
