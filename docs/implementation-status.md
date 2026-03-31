# Implementation Status

A running record of completed work — what was built, when, and at what scope.

---

## 2026-03-31 — Coach Tab Redesign

**Branch:** `feat/coach-tab-redesign`

Completed full redesign of the Coach Tab with a single adaptive screen replacing the previous two-screen flow.

**What was built:**

- **Single adaptive CoachScreen** replaces `NewChatScreen` and `ChatThreadScreen`. The screen manages three inline visual states: idle (greeting + suggestions), conversation (active message thread), and ghost mode (data not being saved).

- **Animated blob mascot** (`coach_blob.dart`) with three states (idle, thinking, talking) and two sizes (80px for idle UI, 28px embedded in messages).

- **10 supporting widgets** for a complete chat UX:
  - `coach_thinking_layer.dart` — collapsible "Zura is thinking..." strip
  - `coach_ai_response.dart` — 4-layer AI response (thinking + markdown text + actions + footer blob)
  - `coach_user_message.dart` — right-aligned bubble with long-press context menu
  - `coach_artifact_card.dart` — inline cards for memory/journal/data system actions
  - `coach_suggestion_card.dart` — suggestion cards with spring-press animation
  - `coach_idle_state.dart` — idle UI with blob + time-adaptive greeting + 3 hardcoded suggestions
  - `coach_message_list.dart` — scrollable message thread + scroll-to-bottom FAB
  - `coach_ghost_banner.dart` — persistent ghost mode banner with exit button

- **Ghost mode** state provider added to allow users to test features without data persistence.

- **CoachInputBar improvements** — added optional `placeholder` parameter (defaults to "Message Zura…").

- **Router refactored** — removed nested `/coach/thread/:id` route, replaced with single `CoachScreen` route. Removed `coachThread` and `coachThreadPath` constants.

**Files created:** 10 (coach_screen.dart + 9 widgets)
**Files modified:** 3 (providers, input bar, router)
**Files deleted:** 2 (new_chat_screen.dart, chat_thread_screen.dart)

---

## 2026-03-31 — Coach Thinking Display

**Branch:** `feat/coach-thinking-display` (not yet merged)

Added live "thinking" feedback to the Coach screen — while Zura reasons through a question, the UI shows what it is doing in real time rather than a blank loading state.

**What was built:**

- **Backend reasoning token extraction** (`cloud-brain/orchestrator.py`) — when the AI model returns reasoning tokens (the internal "thinking" text before its final answer), the server captures them from `delta.reasoning` (with a `model_extra` fallback for models that expose it differently) and forwards them to the client as `thinking_token` WebSocket events. These tokens are display-only and never written to the database.

- **Flutter data layer** (`coach_repository.dart`, `api_coach_repository.dart`) — a new `ThinkingToken` sealed subclass was added to the repository's event model. The API repository parses incoming `thinking_token` events into this type using its own `thinkingAccumulated` variable, separate from the regular streaming content accumulator.

- **Flutter state** (`coach_providers.dart`) — a `thinkingContent: String?` field was added to `CoachChatState`. It is populated as thinking tokens arrive and cleared on the first real content token so it disappears the moment Zura starts responding. It is also cleared on all exit paths: stream complete, error, cancel, timeout, `onError`, and tool start.

- **Flutter UI** (`coach_thinking_layer.dart`) — rewritten as a `StatelessWidget`. Displays a centered `CoachBlob(size: 48, BlobState.thinking)` with italic status text beneath it. The status text follows a priority order: "Checking [friendly tool name]…" during tool calls, the last 160 characters of the accumulated reasoning text when thinking tokens are arriving, or "Thinking…" as a fallback. The `isThinking` condition in `coach_screen.dart` was corrected to `chatState.isSending && chatState.streamingContent == null` so the thinking layer only appears before real content begins streaming.

**Files changed:** `orchestrator.py`, `chat.py`, `coach_repository.dart`, `api_coach_repository.dart`, `coach_providers.dart`, `coach_thinking_layer.dart`, `coach_ai_response.dart`, `coach_message_list.dart`, `coach_screen.dart`, `component_showcase_screen.dart`, `coach_thinking_layer_test.dart`

---

## 2026-03-30 — Settings Brand Bible Pass

**Branch:** `fix/settings-brand-bible`

Completed a full brand bible alignment pass across all settings screens.

**What was done:**

- **Design Catalog removed.** `catalog_screen.dart` deleted. The debug catalog route and route name constants were removed from the router. The harness screen no longer references it.

- **SliverAppBar replaced on every settings screen.** All settings screens that used `SliverAppBar` + `FlexibleSpaceBar` inside a `CustomScrollView` were converted to `ZuralogAppBar(showProfileAvatar: false)` on the scaffold. This fixes the app bar overlap bug and makes every screen consistent.

  Screens converted: Settings Hub, Subscription, About, Appearance, Coach, Journal, Integrations, Privacy & Data (plus Account, Edit Profile, Notification, Privacy Policy, Terms of Service were already using `ZuralogAppBar` or confirmed correct).

- **ZuraLog casing standardised.** Every displayed string that said "Zuralog" was updated to "ZuraLog" — including screen titles, hero widgets, legal body copy in the Privacy Policy and Terms of Service, share sheet text, and footer copyright lines. Code identifiers (class names, import paths) were left unchanged.

- **Surface tokens standardised.** All card/container backgrounds using `colors.cardBackground` in settings screens were changed to `colors.surface`.

- **Snackbars branded.** Plain `SnackBar` calls in the Privacy & Data screen were updated to use `colors.surface` background, floating behavior, and `AppTextStyles` body text — matching the design system.

- **Section labels standardised.** Inline `Text` section headers using ad-hoc style in Coach and other screens were replaced with the shared `SettingsSectionLabel` widget.

**Files changed:** All files in `lib/features/settings/presentation/`, plus `lib/core/router/app_router.dart`, `lib/core/router/route_names.dart`, `lib/features/harness/harness_screen.dart`.

**Analyze result:** Zero errors. Two pre-existing `info`-level lint hints in `edit_profile_screen.dart` (unnecessary braces in string interpolation) — unrelated to this pass.
