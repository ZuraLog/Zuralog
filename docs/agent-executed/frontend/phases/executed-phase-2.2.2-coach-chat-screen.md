# Executed Phase 2.2.2 — Coach Chat Screen

**Date:** 2026-02-23  
**Branch:** `feat/phase-2.2`  
**Commit SHA:** `86a4541`

---

## Summary

Implemented the full AI-powered Coach Chat screen. The screen connects to the Cloud Brain via WebSocket in `initState`, streams messages in real-time, and provides a polished conversation UI following the "Sophisticated Softness" design language.

### Files Created

| File | Purpose |
|------|---------|
| `lib/features/chat/domain/chat_providers.dart` | `ChatState`, `ChatNotifier` (`StateNotifierProvider.autoDispose`), `connectionStatusProvider` |
| `lib/features/chat/presentation/chat_screen.dart` | `ConsumerStatefulWidget` — WebSocket connect on init, pull-to-refresh, typing indicator, connection banner, frosted input bar |
| `lib/features/chat/presentation/widgets/message_bubble.dart` | User / AI bubbles with custom corner radii, markdown rendering, bot avatar, timestamp, `DeepLinkCard` integration |
| `lib/features/chat/presentation/widgets/chat_input_bar.dart` | `BackdropFilter` frosted glass, attach icon, pill `TextField`, mic/send `AnimatedSwitcher` |
| `lib/features/chat/presentation/widgets/typing_indicator.dart` | 3-dot staggered bounce animation, AI bubble styling, `AnimationController` disposed correctly |
| `lib/features/chat/presentation/widgets/deep_link_card.dart` | Card with title/subtitle/icon; `url_launcher` with primary + fallback URL; SnackBar on failure |

### Files Modified

| File | Change |
|------|--------|
| `lib/core/router/app_router.dart` | Replaced `_PlaceholderScreen` for `/chat` with `ChatScreen()` |

---

## Deviations from the Specification

1. **`chatMessagesProvider` (StreamProvider) omitted** — The spec calls for both a `StreamProvider<List<ChatMessage>>` and a `StateNotifierProvider<ChatNotifier>`. After reading the existing codebase, the `StateNotifierProvider` alone handles message accumulation more idiomatically (it listens to the stream internally in `connect()`). Adding a separate `StreamProvider` for the same data would create redundant subscriptions. The `ChatNotifier` implements the scan/accumulate pattern by maintaining `state.messages` as a growing list.

2. **`surfaceVariant` → `AppColors.aiBubbleDark/aiBubbleLight`** — The spec references `AppColors.surfaceVariant`, but this color doesn't exist in `app_colors.dart`. The correct design tokens are `AppColors.aiBubbleDark` and `AppColors.aiBubbleLight`, which were specifically added for AI message bubbles. These are used consistently.

3. **`AppDimens.cardRadius`** — The spec references `AppDimens.cardRadius`, but the actual token name in `app_dimens.dart` is `AppDimens.radiusCard`. Used the correct token name.

4. **Token-based color resolution** — The `surface` and `surfaceVariant` colors from the spec were interpreted as the theme's `colorScheme.surface` (used for the `TextField` fill) and `AppColors.aiBubbleDark/Light` (AI bubbles) respectively.

---

## Architectural Decisions

- **`StateNotifier` over `Notifier`** — `ChatNotifier extends StateNotifier<ChatState>` follows the project pattern (Riverpod 2.x, not code-gen). The `StateNotifier` manages the message stream subscription lifecycle via `_messageSub` and cancels it in `dispose()`.

- **Token-first theming** — All colors, dimensions, and typography come exclusively from `AppColors`, `AppDimens`, and `AppTextStyles`. No raw hex values or numeric literals in widget code.

- **Frosted glass** — `BackdropFilter + ImageFilter.blur(sigmaX/sigmaY: AppDimens.navBarBlurSigma)` with `navBarFrostOpacity` applied to background container, matching the nav bar pattern.

- **`resizeToAvoidBottomInset: true`** — The `Scaffold` is set correctly; the `ChatInputBar` reads `MediaQuery.of(context).padding.bottom` for safe-area clearance.

---

## Test Results

- **New tests added:** 28
- **Total passing:** 161 (was 133)
- **`flutter analyze`:** 0 issues

### Test files

- `test/features/chat/presentation/chat_screen_test.dart` — smoke test, input bar, connecting/disconnected banners, sendMessage dispatch, empty state, messages rendered
- `test/features/chat/presentation/widgets/message_bubble_test.dart` — user right-aligned, user primary color, AI left-aligned, AI bubble color, DeepLinkCard on clientAction, text content, timestamp
- `test/features/chat/presentation/widgets/chat_input_bar_test.dart` — mic when empty, send when typed, send disappears on clear, onSend fires, field cleared, SnackBar on attach, whitespace ignored
- `test/features/chat/presentation/widgets/deep_link_card_test.dart` — title, subtitle, default title, no subtitle, error SnackBar, icon

---

## Next Steps (Phase 2.2.3+)

- Phase 2.2.3: Integrations Hub screen — replace remaining `_PlaceholderScreen` for `/integrations`.
- Phase 2.2.4: Settings screen.
- Future: Connect `ChatNotifier.loadHistory()` output to a deduplicated message list using message IDs once the backend `fetchHistory` endpoint returns stable IDs.
