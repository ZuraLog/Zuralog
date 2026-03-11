# Component Audit

Generated: 2026-03-11  
Branch: `chore/shared-component-library`

---

## Context

- **ZButton.primary** wraps `ElevatedButton` and derives all colors from the theme's `ColorScheme`. It sets `minimumSize: Size(double.infinity, 56)` (or `Size(0, 56)` for non-full-width). The theme's `ElevatedButton` default is already styled; individual feature buttons that use `FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.primaryButtonText, ...)` are the primary migration targets.
- **ZuralogCard** renders `theme.colorScheme.surface` as its background with a 24 px corner radius, a 1 px border in dark mode, and a soft shadow in light mode. It accepts `padding`, `child`, and an optional `onTap`.

---

## Part 1: FilledButton.styleFrom() Sites

26 total occurrences found across 18 files.

### Safe to Migrate (18 sites)

These all use `backgroundColor: AppColors.primary` + `foregroundColor: AppColors.primaryButtonText` with a rounded-rect shape — the exact same intent as `ZButton.primary`. The main difference from `ZButton` is that these use `FilledButton` directly instead of going through the shared component. All are safe to replace with `ZButton(label: '...', onPressed: ...)`.

| File | Line | Context |
|------|------|---------|
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 587 | "Use Freeze" confirmation dialog CTA — primary colors, `radiusButton` radius |
| `zuralog/lib/features/trends/presentation/reports_screen.dart` | 750 | Error state retry button — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/trends/presentation/data_sources_screen.dart` | 285 | Connect / Reconnect button in data source card — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 1303 | Error state retry button (_CorrelationErrorState) — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 1341 | Error state retry button (_ExplorerErrorState) — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/settings/presentation/subscription_settings_screen.dart` | 339 | "Upgrade to Pro" CTA — primary colors, `radiusButtonMd` radius, extra vertical padding |
| `zuralog/lib/features/settings/presentation/integrations_screen.dart` | 590 | Compact "Connect" button in integration list row — primary colors, `radiusButtonMd` radius, small fixed size |
| `zuralog/lib/features/settings/presentation/integrations_screen.dart` | 639 | "OK" confirmation button inside connect dialog — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/settings/presentation/coach_settings_screen.dart` | 709 | "Save Preferences" full-width button — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 691 | "Save Goals" sheet CTA — primary colors, `radiusButtonMd` radius, extra vertical padding |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 769 | "Continue with Apple" link-Apple-ID sheet button — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 846 | Generic form-sheet action button (change email/password) — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/progress/presentation/journal_screen.dart` | 222 | "Log your first day" empty state CTA — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/profile/presentation/emergency_card_edit_screen.dart` | 217 | "Save Emergency Card" primary save button — primary colors, `radiusButtonMd` radius |
| `zuralog/lib/features/progress/presentation/goal_create_edit_sheet.dart` | 579 | "Save Goal" / "Update Goal" sheet button — primary colors, `radiusButtonMd` radius, loading state |
| `zuralog/lib/shared/widgets/quick_log_sheet.dart` | 506 | "Submit" quick-log sheet button — primary colors, radius 14, loading state |
| `zuralog/lib/features/progress/presentation/journal_entry_sheet.dart` | 559 | "Save" journal entry sheet button — primary colors, `radiusButtonMd` radius, loading state |
| `zuralog/lib/shared/widgets/confirmation_card.dart` | 179 | Confirm action button in reusable `ConfirmationCard` — primary colors, radius 14 |

---

### Needs Review (5 sites)

These use the primary color but include extra styling (non-standard size, radius, icon, `disabledBackgroundColor`, custom `textStyle`, or `StadiumBorder`) that goes beyond what `ZButton` currently exposes. They could potentially be migrated once `ZButton` grows new props, or may warrant a new variant.

| File | Line | Context | Difference from ZButton |
|------|------|---------|------------------------|
| `zuralog/lib/features/today/presentation/insight_detail_screen.dart` | 430 | "Discuss with Coach" button — uses `FilledButton.icon`, sets `minimumSize: Size(double.infinity, 52)`, explicit `disabledBackgroundColor` and `disabledForegroundColor` to keep full opacity when null-pressed | `ZButton` doesn't expose `disabledBackgroundColor`; uses `FilledButton.icon` (leading icon inline) rather than the `icon` prop pattern |
| `zuralog/lib/features/data/presentation/metric_detail_screen.dart` | 808 | "Ask Coach" metric-detail `FilledButton.icon` — uses `minimumSize: Size.fromHeight(touchTargetMin)` and radius 14 | `FilledButton.icon` constructor; `Size.fromHeight` min-size constraint is different from `ZButton`'s full-width pattern |
| `zuralog/lib/features/settings/presentation/integrations_screen.dart` | 590 | Compact "Connect" chip-size button — `minimumSize: Size(72, 32)`, small vertical padding, custom `textStyle` | Fixed small size (72×32) would conflict with `ZButton`'s 56 px height minimum; needs a compact variant |
| `zuralog/lib/features/integrations/presentation/widgets/compatible_app_info_sheet.dart` | 152 | "Open App" deep-link launch button — uses `StadiumBorder()` (fully pill shape), no `foregroundColor` set, custom `textStyle` via child `Text.style` | `StadiumBorder` (100% pill) vs `ZButton`'s rounded rect; no `foregroundColor` in `styleFrom` call |
| `zuralog/lib/core/theme/app_theme.dart` | 161 | Global `FilledButtonThemeData` default in `app_theme.dart` — sets defaults for the entire app: `shapePill` radius (100 px), `labelLarge` text style, zero elevation, separate light/dark `primaryOnLight` colors | This IS the global theme default — not a feature button; governs all `FilledButton` widgets that don't override style. Must not be migrated to `ZButton`. |

---

### Keep As-Is (3 sites)

These are intentionally different from `ZButton.primary` — different brand color, dynamic per-slide accent, or pill-shaped Apple SSO button.

| File | Line | Context | Reason |
|------|------|---------|--------|
| `zuralog/lib/features/auth/presentation/onboarding/welcome_screen.dart` | 291 | "Continue with Apple" Sign-In with Apple button — `backgroundColor: AppColors.black`, `foregroundColor: Colors.white`, `shapePill` radius | Apple HIG requires a black pill button for Sign in with Apple; this must remain visually distinct |
| `zuralog/lib/features/auth/presentation/onboarding/onboarding_page_view.dart` | 349 | Onboarding slide CTA — `backgroundColor: currentSlide.accentColor` (dynamic per slide), pill shape, fixed 140 px width | Background color is driven by slide data, not a fixed brand color; intentionally varies per onboarding screen |
| `zuralog/lib/core/theme/app_theme.dart` | 161 | (Same entry as "Needs Review" above — listed here for completeness) Global `FilledButtonThemeData` — this is not a button instance, it's the theme definition itself | This must stay as raw `FilledButton.styleFrom`; it configures the fallback style for the entire app |

> Note: `app_theme.dart:161` appears in both "Needs Review" and "Keep As-Is" tables because it is both the global default (keep as-is from a migration standpoint) and worth reviewing to ensure it aligns with the `ZButton` design spec.

---

## Part 2: Raw Card Container Sites

121 total `AppColors.cardBackground*` / `AppColors.elevatedSurface` occurrences found. After filtering out non-card usages (scaffold `backgroundColor`, `RefreshIndicator` background, shimmer/loading color interpolation, `AlertDialog` background, `Material` color, and `AppColors.elevatedSurfaceDark` used as dialog background), the card-container sites break down as follows.

### Non-Card Uses (excluded from migration)

The following uses of `AppColors.cardBackgroundDark` are **not** card containers and are excluded:

| Pattern | Files / Context |
|---------|-----------------|
| `RefreshIndicator(backgroundColor: ...)` | `progress_home_screen.dart:74`, `journal_screen.dart:145,190,243`, `weekly_report_screen.dart:142,187,230`, `achievements_screen.dart:50`, `goals_screen.dart:102` — sets the pull-to-refresh spinner background, not a card |
| Shimmer color lerp | `progress_home_screen.dart:146` — used as `Color.lerp` target for loading skeleton animation |
| `AlertDialog(backgroundColor: ...)` | `progress_home_screen.dart:563`, `goals_screen.dart:212`, `goal_detail_screen.dart:79`, `account_settings_screen.dart:876` — dialog background, not a card component |
| `AppColors.elevatedSurfaceDark` as dialog bg | `goals_screen.dart:212`, `goal_detail_screen.dart:79` — same exclusion as above |
| `Material(color: ...)` | `integrations_screen.dart:281` — used as `Material` color under an `InkWell`; the `Material` + `InkWell` pattern is already effectively a tappable card but structured differently |
| Score ring track color (`withValues(alpha: 0.3)`) | `health_score_widget.dart:219` — a faint track color inside a `CustomPaint`, not a card |
| `AppColors.elevatedSurfaceDark` as chip badge | `achievements_screen.dart:182` — small chip/pill badge, not a card |

---

### Safe to Migrate (43 sites)

Plain card-shaped containers: `BoxDecoration(color: cardBackground, borderRadius: radiusCard)` with standard padding and no extra decoration. These match `ZuralogCard` directly.

| File | Line | Context |
|------|------|---------|
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 359 | Goal mini-card (160 px wide, progress ring + label) |
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 654 | Streak mini-card (128 px wide, streak count + freeze info) |
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 884 | Week-over-week metrics list card |
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 1043 | Quick-nav row card (horizontal nav items) |
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 1171 | Achievement mini-card (100 px wide) |
| `zuralog/lib/features/trends/presentation/trends_home_screen.dart` | 311 | Historical period summary card (160 px wide) |
| `zuralog/lib/features/trends/presentation/trends_home_screen.dart` | 430 | Correlation highlight card (tappable, plain decoration) |
| `zuralog/lib/features/trends/presentation/trends_home_screen.dart` | 642 | Trends quick-nav item card |
| `zuralog/lib/features/trends/presentation/trends_home_screen.dart` | 680 | "Connect more data" upsell card |
| `zuralog/lib/features/trends/presentation/trends_home_screen.dart` | 843 | Dismissible banner/tip card |
| `zuralog/lib/features/trends/presentation/reports_screen.dart` | 142 | Report type selector tile card |
| `zuralog/lib/features/trends/presentation/reports_screen.dart` | 447 | Insight card inside report detail |
| `zuralog/lib/features/trends/presentation/reports_screen.dart` | 564 | Goal progress card inside report |
| `zuralog/lib/features/trends/presentation/reports_screen.dart` | 624 | Category score summary card inside report |
| `zuralog/lib/features/trends/presentation/data_sources_screen.dart` | 168 | Data source detail card (integration name, freshness, sync info) |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 271 | Correlation picker card (optional primary border when selected) |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 725 | "Not enough data" empty state card |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 774 | Correlation result card (coefficient + description) |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 899 | Scatter chart card |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 1071 | Dual time-series chart card |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 1202 | AI annotation card (primary border at 20% opacity) |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 1238 | Picker prompt card ("select two metrics") |
| `zuralog/lib/features/today/presentation/insight_detail_screen.dart` | 309 | AI reasoning mini-card inside insight detail |
| `zuralog/lib/features/today/presentation/insight_detail_screen.dart` | 505 | Data chart card inside insight detail |
| `zuralog/lib/features/settings/presentation/subscription_settings_screen.dart` | 121 | Current plan card |
| `zuralog/lib/features/settings/presentation/subscription_settings_screen.dart` | 259 | Upgrade benefits card |
| `zuralog/lib/features/settings/presentation/subscription_settings_screen.dart` | 387 | Settings group tile container |
| `zuralog/lib/features/settings/presentation/settings_hub_screen.dart` | 220 | Settings group tile container |
| `zuralog/lib/features/settings/presentation/privacy_data_screen.dart` | 111 | Memory items list container |
| `zuralog/lib/features/settings/presentation/privacy_data_screen.dart` | 298 | Privacy settings group tile container |
| `zuralog/lib/features/settings/presentation/privacy_data_screen.dart` | 435 | Danger-zone action row (tappable row, card-shaped) |
| `zuralog/lib/features/settings/presentation/notification_settings_screen.dart` | 550 | Notification settings group tile container |
| `zuralog/lib/features/settings/presentation/coach_settings_screen.dart` | 374 | Coach settings group tile container |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 112 | Account preferences single-tile container |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 176 | Profile summary card (avatar + name) |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 239 | Account settings group tile container |
| `zuralog/lib/features/settings/presentation/about_screen.dart` | 304 | About screen settings group tile container |
| `zuralog/lib/features/progress\presentation\goal_detail_screen.dart` | 322 | Goal hero section card (ring + stats) |
| `zuralog/lib/features/progress/presentation/goal_detail_screen.dart` | 418 | Progress history sparkline card |
| `zuralog/lib/features/progress/presentation/goal_detail_screen.dart` | 453 | Goal details card |
| `zuralog/lib/features/progress/presentation/goal_detail_screen.dart` | 500 | Goal details continuation |
| `zuralog/lib/features/progress/presentation/goals_screen.dart` | 288 | Goal list item card (ring + details, tappable) |
| `zuralog/lib/features/progress/presentation/journal_screen.dart` | 345 | Journal entry list item card |

---

### Needs Review (26 sites)

These have additional decoration (colored border, box shadow, gradient overlay, asymmetric border radius, left accent stripe, or are inside a `ClipRRect`/`Material`/`AnimatedContainer` wrapper) that goes beyond what `ZuralogCard` provides. Migration may require adding props to `ZuralogCard` or keeping a custom `Container`.

| File | Line | Context | Difference from ZuralogCard |
|------|------|---------|------------------------------|
| `zuralog/lib/features/today/presentation/today_feed_screen.dart` | 327 | Health score panel — has `border: Border.all(color: AppColors.borderDark)` on top of card background | Extra explicit border regardless of theme mode |
| `zuralog/lib/features/today/presentation/today_feed_screen.dart` | 473 | Insight card in feed — border color is dynamic: `isUnread ? categoryColor.withValues(alpha: 0.20) : AppColors.borderDark` | Conditional colored border based on read state |
| `zuralog/lib/features/today/presentation/today_feed_screen.dart` | 638 | Quick-log CTA card — `border: Border.all(color: AppColors.borderDark)` | Extra explicit border |
| `zuralog/lib/features/today/presentation/today_feed_screen.dart` | 745 | Coach chat card — `border: Border.all(color: AppColors.categoryWellness.withValues(alpha: 0.15))` | Semantic category-tinted border |
| `zuralog/lib/features/today/presentation/today_feed_screen.dart` | 817 | "Connect data sources" upsell card — `border: Border.all(color: AppColors.borderDark)` | Extra explicit border |
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 800 | Week-of-week content card — `ClipRRect` wrapper + inner gradient overlay (`LinearGradient` at 8% category color) on top of card color | Contains a `Positioned.fill` gradient — `ZuralogCard` cannot accommodate nested gradient layers |
| `zuralog/lib/features/coach/presentation/new_chat_screen.dart` | 544 | Coach suggestion card — `border: Border.all(color: AppColors.borderDark, width: 1)`, `clipBehavior: Clip.hardEdge`, IntrinsicHeight row with left 4 px colored accent stripe | Explicit clip + hard border + left-stripe layout pattern |
| `zuralog/lib/features/coach/presentation/new_chat_screen.dart` | 978 | Coach context picker bottom sheet — `BorderRadius.vertical(top: radiusCard)` (top-only rounding) | Asymmetric border radius (sheet shape, not a card) — keep as-is pattern |
| `zuralog/lib/features/coach/presentation/new_chat_screen.dart` | 1224 | Coach actions bottom sheet — `BorderRadius.vertical(top: Radius.circular(28))` | Asymmetric radius sheet container |
| `zuralog/lib/features/coach/presentation/new_chat_screen.dart` | 1442 | Coach export/share bottom sheet — `BorderRadius.vertical(top: radiusCard)` | Asymmetric radius sheet container |
| `zuralog/lib/features/settings/presentation/integrations_screen.dart` | 377 | Disconnected integration tile — plain card but wrapped in `Padding` without tap; sibling of `_ConnectedTile` which uses `Material + InkWell` pattern | Mixed tap patterns in the same list; one uses Material, the other Container |
| `zuralog/lib/features/settings/presentation/integrations_screen.dart` | 441 | "Coming soon" grayed-out integration tile — `Opacity(0.5)` wrapper | Wrapped in `Opacity` — `ZuralogCard` doesn't have a disabled/opacity prop |
| `zuralog/lib/features/settings/presentation/integrations_screen.dart` | 748 | Sync details info card — plain card but inside a bottom-sheet that already has its own background | Context is a sub-card inside a modal sheet |
| `zuralog/lib/features/settings/presentation/coach_settings_screen.dart` | 507 | Coach persona option card — `AnimatedContainer` with conditional `Border.all(color: AppColors.primary, width: 1.5)` when active | `AnimatedContainer` with animated border — `ZuralogCard` is not animated |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 575 | "Set goals" bottom sheet — `BorderRadius.vertical(top: Radius.circular(28))` | Asymmetric radius (modal sheet shape) |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 746 | "Link Apple ID" bottom sheet — `BorderRadius.circular(28)`, margin `all(16)`, inside `showModalBottomSheet` | Inside modal bottom sheet with custom margin; not a screen card |
| `zuralog/lib/features/settings/presentation/account_settings_screen.dart` | 810 | Generic form bottom sheet — same `borderRadius: 28` inside modal | Inside modal bottom sheet |
| `zuralog/lib/features/profile/presentation/emergency_card_screen.dart` | 275 | Blood type card — plain card but `borderRadius: radiusCard` and `BoxShape` circle inner element | Plain card body; safe, but child `BoxShape.circle` is intrinsic |
| `zuralog/lib/features/profile/presentation/emergency_card_screen.dart` | 346 | Medical section card (allergies/medications) — plain card | Safe; no extra decoration |
| `zuralog/lib/features/profile/presentation/emergency_card_screen.dart` | 423 | Emergency contacts card — plain card, column of contacts with dividers | Safe; no extra decoration |
| `zuralog/lib/features/profile/presentation/emergency_card_edit_screen.dart` | 273 | Blood type chip selector — `AnimatedContainer`, color is `isSelected ? AppColors.categoryHeart : AppColors.cardBackgroundDark`, `border: Border.all(...)` | Animated selection chip — not a card; wrong component type |
| `zuralog/lib/features/profile/presentation/emergency_card_edit_screen.dart` | 322 | Tag input card — plain card | Safe |
| `zuralog/lib/features/profile/presentation/emergency_card_edit_screen.dart` | 499 | Emergency contact editor card — plain card | Safe |
| `zuralog/lib/features/today/presentation/notification_history_screen.dart` | 215 | Notification item body — `borderRadius` is conditional: full-radius if read, right-only if unread (left side has an accent stripe) | Conditional border radius based on read state |
| `zuralog/lib/features/achievements_screen.dart` | 433 | Achievement card — `boxShadow` with category glow at `glowOpacity > 0`, border radius = `radiusCard` | Conditional `boxShadow` glow effect — `ZuralogCard` supports only a fixed light-mode shadow |
| `zuralog/lib/features/profile/presentation/profile_screen.dart` | 218 | Profile header card — avatar, name, and camera-badge overlay | Inner `Stack` with avatar + camera badge — review before migrating |

---

### Keep As-Is (18 sites)

These are intentionally different from `ZuralogCard`: they are not stand-alone cards (they are chip containers, skeleton shimmer widgets, score hero widgets, `Color.lerp` interpolation targets, or shared widgets that already abstract the card pattern internally).

| File | Line | Context | Reason |
|------|------|---------|--------|
| `zuralog/lib/shared/widgets/score_trend_hero.dart` | 39 | `ScoreTrendHero` main container — uses adaptive `bg` (dark/light), radius 20, width `double.infinity` | Already a specialized shared widget; ZuralogCard would introduce double-wrapping |
| `zuralog/lib/shared/widgets/score_trend_hero.dart` | 455 | Inner "insight" stripe inside ScoreTrendHero — `color: bg`, no `borderRadius`, sits inside a `Row` with a 3 px primary accent stripe | Not a card; it's an inner content row with flat background — no border radius |
| `zuralog/lib/shared/widgets/category_card.dart` | 94 | `CategoryCard` shared widget — adaptive `bg`, radius 20, left accent stripe using `IntrinsicHeight + Row` pattern | Already a dedicated shared widget; card pattern is intentional with the accent stripe |
| `zuralog/lib/shared/widgets/confirmation_card.dart` | 94 | `ConfirmationCard` shared widget — adaptive `bg`, radius 20, header + divider + action row layout | Already a dedicated shared widget with its own button layout |
| `zuralog/lib/shared/widgets/data_maturity_banner.dart` | 64 | `DataMaturityBanner` — adaptive `bg` using `surfaceLight` in light mode (not `cardBackgroundLight`) | Uses `surfaceLight` in light mode — intentionally different surface for banner context |
| `zuralog/lib/shared/widgets/health_score_widget.dart` | 219 | Score ring track color at 30% opacity — `cardBackgroundDark.withValues(alpha: 0.3)` passed to `CustomPaint` painter | Not a card container; it's a `Color` value used for a ring track inside `CustomPaint` |
| `zuralog/lib/features/data/presentation/score_breakdown_screen.dart` | 141 | `_InputRow` — adaptive `bg`, radius 20 (not `radiusCard` = 20, same value but hardcoded int) | Adaptive light/dark logic already built in; also uses `cardBackgroundLight` for light mode |
| `zuralog/lib/features/data/presentation/score_breakdown_screen.dart` | 249 | `_EmptyInputsCard` — same adaptive `bg` pattern | Same as above |
| `zuralog/lib/features/data/presentation/health_dashboard_screen.dart` | 806 | Locked metric row — wrapped in `Opacity(0.45)`, `IntrinsicHeight`, left accent stripe | Not a card; it's a row with an opacity wrapper and structural left stripe — same `CategoryCard`-like pattern |
| `zuralog/lib/features/data/presentation/health_dashboard_screen.dart` | 875 | `_CardSkeleton` loading skeleton — adaptive `bg`, fixed height 72, no content | Loading skeleton placeholder — intentional; should not be `ZuralogCard` |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 529 | Chip selector — `color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBackgroundDark`, `radiusChip` | A chip, not a card; uses `radiusChip`, not `radiusCard` |
| `zuralog/lib/features/trends/presentation/correlations_screen.dart` | 648 | Animated filter chip — `color: selected ? AppColors.primary : AppColors.cardBackgroundDark`, `AnimatedContainer`, `radiusChip` | A chip with selection state animation — not a card component |
| `zuralog/lib/features/progress/presentation/achievements_screen.dart` | 50 | `RefreshIndicator(backgroundColor: ...)` | Pull-to-refresh spinner background, not a card |
| `zuralog/lib/features/progress/presentation/achievements_screen.dart` | 182 | Count badge chip — `color: AppColors.elevatedSurfaceDark`, `radiusChip` | Small chip/badge, not a card |
| `zuralog/lib/features/progress/presentation/progress_home_screen.dart` | 74 | `RefreshIndicator(backgroundColor: ...)` | Pull-to-refresh spinner background |
| `zuralog/lib/features/progress/presentation/goals_screen.dart` | 102 | `RefreshIndicator(backgroundColor: ...)` | Pull-to-refresh spinner background |
| `zuralog/lib/features/progress/presentation/goals_screen.dart` | 212 | `AlertDialog(backgroundColor: ...)` — delete goal confirmation dialog | Dialog background, not a card component |
| `zuralog/lib/features/progress/presentation/goal_detail_screen.dart` | 79 | `AlertDialog(backgroundColor: AppColors.elevatedSurfaceDark)` — delete goal dialog | Dialog background using elevated surface color; keep as-is |

---

## Summary

**Total FilledButton.styleFrom() sites: 26**
- Safe to migrate: 18
- Needs review: 5
- Keep as-is: 3

**Total raw card Container sites (AppColors.cardBackground\* / elevatedSurface in BoxDecoration): 88 card-context occurrences**  
(33 occurrences excluded as non-card uses: RefreshIndicator backgrounds, dialog backgrounds, shimmer lerp, chip badges, CustomPaint color values)

- Safe to migrate: 43
- Needs review: 26
- Keep as-is: 18

### Key Findings

1. **FilledButton migration is highly uniform.** 18 of 26 sites are identical in intent and can be replaced with `ZButton(label: ..., onPressed: ...)` in a single pass. The 5 "needs review" sites only need minor `ZButton` API additions (compact size prop, `disabledBackgroundColor` override, or icon support via `FilledButton.icon`).

2. **The Apple SSO button and per-slide onboarding button must not be migrated** — they have intentional brand/design requirements that differ from the primary CTA style.

3. **Card migration is more complex.** Many "card" containers have extra decoration (borders, gradients, accent stripes, `AnimatedContainer`) that `ZuralogCard` doesn't yet support. Before running a mass migration, consider adding a `border` prop and a `borderColor` prop to `ZuralogCard`, which would move the majority of "needs review" sites into "safe to migrate."

4. **Bottom-sheet root containers** (asymmetric border radius, `top: Radius.circular(28)`) should never be migrated to `ZuralogCard` — they are sheet chrome, not cards.

5. **Chips and refresh indicator backgrounds** are frequently mistaken for cards in a text search but are entirely different use cases.
