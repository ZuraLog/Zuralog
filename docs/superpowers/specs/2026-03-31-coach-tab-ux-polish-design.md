# Coach Tab UX Polish — Design Spec
**Date:** 2026-03-31
**Status:** Approved
**Scope:** Four targeted improvements to the Coach Tab experience

---

## Overview

Four focused changes to the Coach Tab. Each is independent and can be built and shipped separately. None require backend changes.

---

## Change 1 — Floating Pill Input Bar

### What it is
The text input bar (with the attachment and microphone buttons) moves from being fixed at the bottom of the screen to floating above the nav bar as a second pill — matching the nav bar's exact visual style.

### Visual spec
- Same recipe as `_FrostedNavigationBar`: `BackdropFilter` blur, `colors.surface.withValues(alpha: 0.92)`, `BorderRadius.circular(AppDimens.shapePill)`
- Same horizontal margins: `AppDimens.spaceMdPlus` on each side
- Floats 8px above the nav bar (i.e. `bottom: navBarHeight + 8`)
- No border needed — shadow + blur provide sufficient separation

### Layout approach
`CoachScreen`'s body becomes a `Stack`. The chat area (idle state or message list) fills the full stack height. The input pill is a `Positioned` child anchored to the bottom, accounting for the nav bar height and safe area.

The message list receives bottom padding equal to `inputPillHeight + navBarHeight + safeAreaBottom + 16px` so no message is ever obscured by the floating pills.

### Keyboard behaviour
`Scaffold(resizeToAvoidBottomInset: true)` is already active. When the keyboard opens, the `Scaffold` pushes everything up. The pill rises with the content automatically — no manual `viewInsets` handling needed.

### Ghost mode
The ghost banner stays pinned below the app bar (above the message area), unchanged.

### Error banner
The `_ErrorBanner` moves inside the `Stack` as a `Positioned` element just above the input pill.

---

## Change 2 — Fullscreen Conversation History

### What it is
Tapping the hamburger icon replaces the current bottom sheet with a full-screen page that slides in from the left, like Claude's conversation list. A back arrow dismisses it.

### Navigation
`_openDrawer()` in `CoachScreen` is replaced with a `Navigator.push()` call using a custom `PageRouteBuilder` that slides in from the left (opposite direction to the standard right-to-left push). This keeps the pattern modal (no named route, no deep-link requirement) while feeling like a full page takeover.

### New widget: `CoachHistoryScreen`
The content of `_CoachConversationDrawer` is extracted into a standalone `ConsumerStatefulWidget` called `CoachHistoryScreen`. It takes the same two callbacks:
- `onConversationTap(String conversationId)` — loads the conversation and pops
- `onNewConversation()` — starts a new conversation and pops

### Layout
- Standard scaffold with a `ZuralogAppBar` (title: "Conversations", leading: back arrow)
- Search bar below the app bar (same search UI as the current drawer)
- Full-height `ListView` of conversation tiles
- "New conversation" button as an action in the app bar (the `+` icon)

### Transition
Slides in from the left edge (x: -1.0 → 0.0) with a `Curves.easeInOut` curve over 280ms. Matches the feel of Claude's history panel without a native drawer (which would be architecturally messier with the existing shell).

---

## Change 3 — Single Disclaimer Footer (Layer 3)

### What it is
The "AI can make mistakes" disclaimer (the small blob + text) currently appears on every AI response. It will appear only on the **most recent** AI response in the conversation. All earlier responses omit it entirely.

### Implementation
`CoachAiResponse` gains one new parameter:
```
final bool showFooter; // defaults to false
```

Layer 3 (the blob + disclaimer row) is gated on `showFooter: true`.

In `CoachMessageList._buildItem`, the widget finds the index of the **last assistant-role message** in the list (not simply the last message overall — the last message could be a user message waiting for a reply). Only that specific assistant message receives `showFooter: true`; all other assistant messages receive `showFooter: false`.

```dart
// Example logic inside _buildItem or precomputed before itemBuilder:
final lastAssistantIndex = List.generate(widget.messages.length, (i) => i)
    .lastWhere((i) => widget.messages[i].role == MessageRole.assistant, orElse: () => -1);
// Pass showFooter: index == lastAssistantIndex to CoachAiResponse
```

### Streaming behaviour
While Zura is streaming a response, the disclaimer is shown on the actively-streaming message (which is always the last one). Once streaming ends and a new user message arrives, the footer disappears from the previous response and will reappear on the next AI response.

### Blob behaviour
The blob in Layer 3 still reflects the live state (`idle` / `thinking` / `talking`) when `showFooter` is true. When `showFooter` is false, the blob is simply not rendered.

---

## Change 4 — Markdown Style System

### What it is
The `MarkdownStyleSheet` in `CoachAiResponse` is expanded to cover all elements that `flutter_markdown_plus` renders. All colours are resolved through `AppColorsOf(context)` — no hardcoded hex values.

### Covered elements

| Element | Style |
|---|---|
| `h1` | `AppTextStyles.displaySmall`, `colors.primary` |
| `h2` | `AppTextStyles.titleLarge`, `colors.primary` |
| `h3` | `AppTextStyles.titleMedium`, `colors.textPrimary` |
| `p` | `AppTextStyles.bodyMedium`, `colors.textPrimary` (already set, kept) |
| `strong` | `FontWeight.w600`, `colors.textPrimary` |
| `em` | `FontStyle.italic`, `colors.textSecondary` |
| `a` (links) | `colors.primary`, `FontWeight.w500`, no underline by default |
| `code` (inline) | `AppTextStyles.bodySmall`, `colors.primary`, background `colors.surfaceRaised` |
| `codeblockDecoration` | `colors.surfaceRaised` background, `AppDimens.radiusSm`, left border `colors.primary.withValues(alpha: 0.5)` at 3px |
| `codeblockPadding` | `EdgeInsets.all(AppDimens.spaceMd)` |
| `blockquote` | `colors.textSecondary`, italic (already set, kept) |
| `blockquoteDecoration` | left border `colors.primary.withValues(alpha: 0.4)` at 3px, no background fill |
| `listBullet` | `AppTextStyles.bodyMedium`, `colors.primary` |
| `listIndent` | `24.0` |
| `blockSpacing` | `8.0` (gap between paragraphs and blocks) |
| `h1Padding`, `h2Padding`, `h3Padding` | `EdgeInsets.only(top: 12, bottom: 4)` for h1/h2; `EdgeInsets.only(top: 8, bottom: 4)` for h3 |
| `pPadding` | `EdgeInsets.only(bottom: 4)` |

### Tables
`flutter_markdown_plus` supports tables. Styling:
- `tableBorder`: `TableBorder.all(color: colors.border, width: 1)`
- `tableHead`: `AppTextStyles.labelMedium`, `colors.textPrimary`, `FontWeight.w600`
- `tableBody`: `AppTextStyles.bodySmall`, `colors.textPrimary`
- `tableCellsPadding`: `EdgeInsets.symmetric(horizontal: 8, vertical: 6)`
- `tableColumnWidth`: default (flex)

### `selectable`
Keep `selectable: true` for all responses so users can copy text.

---

## Files Changed

| File | Change |
|---|---|
| `coach_screen.dart` | Body → Stack; input pill positioned; `_openDrawer` → `Navigator.push`; `_ErrorBanner` repositioned |
| `coach_ai_response.dart` | Add `showFooter` param; expand `MarkdownStyleSheet` |
| `coach_message_list.dart` | Pass `showFooter: isLastAssistantMessage` to `CoachAiResponse` |
| `coach_input_bar.dart` | No structural change — styling adapts automatically from parent |
| `coach_history_screen.dart` | **New file** — extracted from `_CoachConversationDrawer` |

---

## Out of Scope

- No backend changes
- No changes to attachment picker or attachment preview bar
- No changes to ghost mode logic (only the input pill and banner positioning shifts)
- No changes to the conversation tile data model
- No changes to any other tab
