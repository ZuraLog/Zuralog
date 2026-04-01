# Implementation Status

A running record of completed work — what was built, when, and at what scope.

---

## 2026-04-01 — App MCP Servers (Progress, Wellbeing, Notifications)

**Branch:** `feat/app-mcp-servers`

Added three new MCP servers to the Coach AI so it can read and manage the user's goals, streaks, achievements, journal, supplements, wellbeing insights, and push notifications — all without requiring any third-party OAuth connection.

**What was built:**

- **UserProgressServer** (`user_progress_server.py`, server name `user_progress`): Gives the Coach full read/write access to the user's goals and read-only access to streaks and achievements. Goals support create, read, update, complete, and delete. Streaks and achievements are intentionally read-only — the AI observes them, it does not manufacture them. Achievements are sourced through `AchievementTracker.get_all()`. Queries the `user_goals`, `user_streaks`, and `achievements` tables.

- **UserWellbeingServer** (`user_wellbeing_server.py`, server name `user_wellbeing`): Gives the Coach access to the user's journal entries, supplement log, and AI-generated insights. Journal entries and insights are read-only by design — the Coach reads what the user wrote, it does not write journal entries on their behalf. Supplements support add and remove (soft delete). Queries the `journal_entries`, `user_supplements`, and `insights` tables.

- **NotificationServer** (`notification_server.py`, server name `notification`): Gives the Coach the ability to send a push notification to all of the user's registered devices. Uses `PushService.send_and_persist`, which delivers the message and writes a record to `notification_logs` in one step. The `notification_type` is hardcoded to `"coach"` so these messages are always identifiable as AI-initiated. The tool takes a `title` and `body` — nothing else.

- **Registration**: All three servers are started in the `main.py` lifespan block and listed in `ALWAYS_ON_SERVERS` in `user_tool_resolver.py`. No user action or OAuth flow is needed — they are available in every Coach session automatically.

- **System prompt updated**: The `_CAPABILITIES_BLOCK` in `agent/prompts/system.py` was extended with tool documentation for items 6–9 covering goals, streaks/achievements, wellbeing, and notifications.

**Files created:**
- `cloud-brain/app/mcp_servers/user_progress_server.py`
- `cloud-brain/app/mcp_servers/user_wellbeing_server.py`
- `cloud-brain/app/mcp_servers/notification_server.py`

**Files modified:** `main.py`, `user_tool_resolver.py`, `agent/prompts/system.py`

---

## 2026-04-01 — Coach Context Management (Three-Layer Memory)

**Branch:** `feat/context-management`

Added a full three-layer memory system to the Coach AI so it knows who the user is, remembers past conversations, and retains long-term facts across sessions.

**What was built:**

- **Layer 1 — Working memory** (`token_counter.py`): History is now trimmed by real token counts using `tiktoken` (`cl100k_base`). Budget is 8,192 tokens per request, with a 2,048-token cap per message. Replaced the old `MAX_HISTORY_CHARS = 40_000` character estimate.

- **Layer 2 — Episodic memory** (`summarization_service.py`): When a conversation exceeds 30 messages, the oldest messages are summarized by the LLM and stored in `conversations.summary`. The summary is prepended on future requests. Summarized messages are flagged `is_summarized = TRUE` and excluded from history loads. Runs fire-and-forget — no added latency.

- **Layer 3 — Semantic memory** (`pgvector_memory_store.py`, `memory_extraction_service.py`): User facts are stored as vector embeddings in the `user_memories` table in Supabase. After each session, up to five facts are extracted by the LLM, deduplicated at 0.92 cosine similarity, and stored. The top-5 most relevant facts (score ≥ 0.70) are injected into every system prompt. Uses OpenAI `text-embedding-3-small` (1536 dims) with an HNSW index.

- **User profile injection**: Every system prompt now includes a `## About This User` block — display name, goals, fitness level, units, timezone, computed age, and height. Sourced from a JOIN of `users` and `user_preferences` at request time.

- **Tool result truncation**: If accumulated tool messages in a single turn exceed 4,096 tokens, the oldest is truncated to a 150-token summary. Prevents a large health data dump from consuming the full context window.

- **Pinecone retired**: `PineconeMemoryStore` and its tests deleted. `PgVectorMemoryStore` now implements the `MemoryStore` protocol. `pinecone_api_key` removed from config. Long-term memory now runs entirely inside the existing Supabase instance.

**Files created:**
- `cloud-brain/app/agent/context_manager/token_counter.py`
- `cloud-brain/app/agent/context_manager/summarization_service.py`
- `cloud-brain/app/agent/context_manager/pgvector_memory_store.py`
- `cloud-brain/app/agent/context_manager/memory_extraction_service.py`
- `supabase/migrations/20260401000001_add_context_management.sql`
- `supabase/migrations/20260401000002_add_pgvector_memories.sql`

**Files modified:** `chat.py`, `orchestrator.py`, `system.py`, `memory_store.py`, `conversation.py`, `main.py`, `config.py`, `memory_routes.py`, `pyproject.toml`

**Files deleted:** `pinecone_memory_store.py`, `test_pinecone_memory_store.py`

---

## 2026-04-01 — Coach Ghost Mode Rework

**Files changed:** `coach_screen.dart`, `coach_ghost_banner.dart`, `coach_repository.dart`, `api_coach_repository.dart`, `coach_providers.dart`

- **Soft-brick bug fixed:** `_showActivateGhostSheet` and `_showExitGhostSheet` now `await` the modal sheet so state updates only fire after the dismiss animation fully completes. Previously, synchronous rebuilds during the pop animation left the Coach tab's modal barrier mounted and the whole tab unresponsive.
- **Vignette replaced:** `_GhostVignette` swapped from a full-screen radial gradient dim to a 2.5dp colored border using `AppColorsOf(context).primary` at 60% opacity. The center of the screen is now fully unobstructed.
- **Banner copy updated:** `CoachGhostBanner` text changed from "Ghost Mode — nothing is being saved" to "Ghost Mode — your conversation won't be saved or logged."
- **`ghost_mode` flag propagated through the full send chain:** `bool isGhost = false` added to `CoachRepository`, `ApiCoachRepository`, providers, and screen. When active, `ghost_mode: true` is included in the WebSocket payload.
- **Write-type tool indicators suppressed in ghost mode:** Tool call UI items whose names contain save, store, write, memory, log, create, update, delete, or archive are hidden from the chat while ghost mode is on.
- **Conversation refresh skipped in ghost mode:** `coachConversationsProvider.notifier.refresh()` is not called after ghost mode sends. `regenerate()` also forwards `isGhost`.

---

## 2026-03-31 — Coach Ghost Mode Redesign + Attachment Panel

### Ghost Mode
- **Soft-brick bug fixed:** `_showActivateGhostSheet` and `_showExitGhostSheet` in `coach_screen.dart` now wrap state changes in `WidgetsBinding.addPostFrameCallback` so the modal barrier clears before the screen rebuilds. Root cause was the branch navigator's `ModalBarrier` staying mounted due to synchronous rebuilds during the pop animation.
- **Icon:** Ghost mode button changed to `Icons.sentiment_very_dissatisfied_rounded`
- **App bar title:** Switches to 'Ghost Mode' when active, 'Coach' otherwise
- **Vignette overlay:** Background color swap removed. `_GhostVignette` widget added as last Stack child — `IgnorePointer`-wrapped `DecoratedBox` with `RadialGradient` (transparent center → `0x55000000` at edges, radius 1.2). Self-wraps `IgnorePointer` internally.
- **`canvasGhost` token:** Annotated as superseded by vignette in `app_colors.dart`

### Attachment Panel (`CoachAttachmentPanel`)
- New file: `zuralog/lib/features/coach/presentation/widgets/coach_attachment_panel.dart`
- Full-screen scrollable bottom sheet replacing `AttachmentPickerSheet`
- Sections: **Attach From** (Camera / Photos / Files — 10 MB guard, double-tap guard, `InkWell` ripple) + **Session Settings** (AI Persona cards, Proactivity `ZSegmentedControl`, Response Length `ZSegmentedControl`, Suggested Prompts + Voice Input `ZSettingsTile`/`ZToggle`)
- All settings read/write `userPreferencesProvider` — changes sync with Settings tab automatically
- Ghost mode: attachment section disabled with explanatory banner when `isGhost: true`
- `isGhost` parameter propagated through `CoachInputBar` → `CoachAttachmentPanel`
- Call site: `coach_input_bar.dart` — import and widget name updated; all other logic unchanged

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
