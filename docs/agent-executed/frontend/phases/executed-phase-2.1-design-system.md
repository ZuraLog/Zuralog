# Executed Phase 2.1 — Design System Setup

**Branch:** `feat/phase-2.1`
**Completed:** 2026-02-23
**Commits:** 4 checkpoint commits (`9aa2480` → `3b77049`)

---

## Summary

Implemented the full Zuralog Flutter design system (Phase 2.1) covering theme tokens, Material 3 `ThemeData`, six reusable shared widgets, a live visual catalog screen, and 62 passing tests.

### Phase 2.1.1 — Theme Configuration

Established a complete token-based theming layer under `zuralog/lib/core/theme/`:

- **`app_colors.dart`** — All color constants for "Sophisticated Softness" palette (Sage Green primary, Muted Slate secondary, Soft Coral accent, OLED black dark background).
- **`app_text_styles.dart`** — Typography scale using Inter (Android) / SF Pro Display (iOS, via `null` fontFamily). Weights: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold.
- **`app_dimens.dart`** — Spacing scale (4/8/12/16/20/24/32/48/64), border radii, button heights, icon sizes, card shadow tokens.
- **`app_theme.dart`** — Factory producing `AppTheme.light` and `AppTheme.dark` `ThemeData` objects; Material 3 enabled; `ElevatedButtonThemeData`, `CardTheme`, `DividerThemeData`, `InputDecorationTheme` all wired from tokens.
- **`theme_provider.dart`** — Riverpod `StateProvider<ThemeMode>` defaulting to `ThemeMode.system`.
- **`theme.dart`** — Single barrel export.

Inter TTF static fonts (Regular/Medium/SemiBold/Bold) are bundled under `zuralog/assets/fonts/` and declared in `pubspec.yaml`.

`zuralog/lib/app.dart` was migrated from `StatelessWidget` to `ConsumerWidget` to watch `themeModeProvider` and pass `theme`/`darkTheme`/`themeMode` to `MaterialApp`.

### Phase 2.1.2 — Reusable Components

Six shared widgets created under `zuralog/lib/shared/widgets/`, all const-constructible, zero hard-coded hex values, full docstrings:

| Widget | Location | Purpose |
|--------|----------|---------|
| `PrimaryButton` | `buttons/primary_button.dart` | Sage Green filled CTA with loading state |
| `SecondaryButton` | `buttons/secondary_button.dart` | Outlined border button using secondary color |
| `ZuralogCard` | `cards/zuralog_card.dart` | Surface card — shadow in light mode, 1px border in dark mode |
| `AppTextField` | `inputs/app_text_field.dart` | Validated text field with prefix/suffix icons, Sage Green cursor |
| `SectionHeader` | `layout/section_header.dart` | Heading + optional action row for list sections |
| `StatusIndicator` | `indicators/status_indicator.dart` | Colored dot + label for connected/syncing/error/offline states |

`zuralog/lib/shared/widgets/widgets.dart` provides a single barrel export.

### CatalogScreen (Developer Tool)

`zuralog/lib/features/catalog/catalog_screen.dart` — a Storybook-lite screen accessible from the HarnessScreen. Renders theme toggle (System/Light/Dark), color swatches for every token, the full typography scale, and all six components live. Wired into `harness_screen.dart` via a "Design Catalog" chip.

---

## Deviations from Original Plan

| Item | Plan | Actual | Reason |
|------|------|--------|--------|
| Card visual style | Considered `BackdropFilter` glass effect | Shadow (light) / 1px border (dark) | Glass effect is over-engineered and absent from `view-design.md`; the spec calls for simple surface cards |
| Color source | `phase-2.1.1-theme-configuration.md` | `docs/plans/frontend/view-design.md` | The phase doc had outdated colors; `view-design.md` is the signed-off design source |
| `app.dart` widget type | Assumed `StatelessWidget` | Migrated to `ConsumerWidget` | Required to watch `themeModeProvider` from Riverpod |
| Test: `TextFormField.obscureText` | Direct property access | Accessed via `EditableText` child | `TextFormField` does not expose `obscureText` as a public getter |
| Test: `TextFormField.cursorColor` | Direct property access | Accessed via `EditableText` child | `TextFormField` does not expose `cursorColor` as a public getter |

---

## Test Results

- `flutter analyze` — **0 issues**
- `flutter test` — **62 / 62 passed**

Test files:
- `zuralog/test/core/theme/app_theme_test.dart` — 26 unit tests covering light/dark colors, brightness, font family, card radius, button color, divider
- `zuralog/test/shared/widgets/primary_button_test.dart` — widget tests for label, tap callback, disabled state, loading state
- `zuralog/test/shared/widgets/zuralog_card_test.dart` — widget tests for child render, tap/no-tap behavior, decoration modes
- `zuralog/test/shared/widgets/app_text_field_test.dart` — widget tests for rendering, text input, obscure text, validation, cursor color

---

## Next Steps (Phase 2.2 onwards)

The design system is complete and stable. The following are ready to build on top of it:

- **Phase 2.2** — Navigation shell (bottom nav bar, route structure) using the `ZuralogCard` and `AppColors` tokens already established.
- **Phase 2.3+** — Feature screens (Dashboard, Activity Log, Insights) consuming `PrimaryButton`, `ZuralogCard`, `AppTextField`, `SectionHeader`, `StatusIndicator` from the shared widget library.
- All screens can be iterated in the CatalogScreen before being wired into the full nav flow.
