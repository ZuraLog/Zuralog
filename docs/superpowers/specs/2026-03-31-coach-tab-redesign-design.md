# Coach Tab Redesign — Design Spec

**Date:** 2026-03-31
**Scope:** `zuralog/` Flutter app only — visual redesign, no backend or data-layer changes.

---

## Goal

Replace the two-screen Coach flow (`NewChatScreen` → `ChatThreadScreen`) with a single adaptive `CoachScreen` that feels like a living AI companion — a mascot-driven, Claude-inspired chat experience with inline conversations, ghost mode, and artifact cards.

---

## Inspiration & Direction

Researched: Claude, ChatGPT, Gemini, Perplexity.

**Key takeaways applied:**
- **Claude** — no chat bubbles for AI responses (full-width text blocks), animated star mascot, minimal chrome, collapsed thinking panel, hold-to-act on user messages, temporary chat (ghost mode)
- **ChatGPT** — expandable reasoning panel, right-aligned user bubbles, utility row under AI messages
- **Gemini** — time-adaptive greeting, model indicator in input row
- **Perplexity** — sources/artifact cards inline in the thread

**Our direction:** Claude-inspired minimal layout + living blob mascot unique to Zuralog. No generic AI aesthetic. The mascot is the personality anchor.

---

## Architecture

### Single Adaptive Screen

`CoachScreen` replaces both `NewChatScreen` and `ChatThreadScreen`. It renders three visual states based on conversation content and ghost mode flag — no route navigation between them.

```
CoachScreen
├── AppBar (hamburger, title, ghost mode button)
├── GhostModeBanner (conditional — slides in from top)
└── Body
    ├── IdleState      (empty conversation, not ghost)
    ├── ConversationState  (active conversation)
    └── [ghost mode = same ConversationState + tinted background]
```

**State transitions:**
- Empty conversation → **IdleState**
- User sends first message → animated transition to **ConversationState** (blob slides from center-top to bottom-left, suggestion cards fade out, message list fades in)
- Conversation exists + ghost mode → **ConversationState** with ghost visual layer
- Tapping a past conversation from the drawer → loads it into ConversationState
- Exiting ghost mode → clears ghost conversation, returns to IdleState

**No changes to:**
- Riverpod providers (`coachChatNotifierProvider`, `coachConversationsProvider`, etc.)
- Domain models (`Conversation`, `ChatMessage`, `MessageRole`, `PromptSuggestion`)
- `ConversationDrawer` (hamburger still works, loads past conversations)
- Backend / cloud-brain API

---

## Blob Mascot

The mascot is an abstract organic blob — not a character, not a face. Pure shape and motion. It serves as Zura's "presence" — alive when idle, urgent when thinking, smooth when speaking.

### Animation States

| State | Trigger | Speed | Feel |
|-------|---------|-------|------|
| **Idle** | Empty conversation, waiting | 6s morph cycle | Slow, breathing, calm |
| **Thinking** | AI is generating a response | 0.8s morph cycle | Fast, erratic, energetic |
| **Talking** | Response is streaming in | 1.2s morph cycle | Medium, smooth, flowing |

Implementation: Flutter `AnimationController` driving `BorderRadius` interpolation across 4–6 keyframe shapes. No external assets required.

### Placement

| Screen State | Position | Size |
|-------------|----------|------|
| Idle | Top-center, above greeting | 80×80 logical pixels |
| Conversation | Bottom-left, below last AI message footer | 28×28 logical pixels |

Transition: `AnimatedPositioned` + scale tween from idle → conversation state.

### Colors

- **Fill:** Sage (`#CFE1B9`) with 15% opacity tint
- **Border:** Sage (`#CFE1B9`) at full opacity, 1.5px
- **Shadow:** Sage glow, 12px blur, 20% opacity (idle only — removed in conversation to stay subtle)

---

## State 1 — Idle

Shown when conversation is empty.

### Layout (top to bottom)

1. **Blob mascot** — top-center, idle animation
2. **Time-adaptive greeting** — e.g. "Good morning.", "How can I help you this evening?" — uses device clock hour. Text style: `displayMedium`, Warm White.
3. **Suggestion cards** — 3 cards in a vertical list, each with a title and a subtitle that gives context on why it's relevant
4. **Input bar** — pinned to bottom

### Suggestion Cards

Each card is a `ZuralogSpringButton` wrapping a Surface-elevated container. No horizontal scrolling — 3 cards stacked vertically. Tapping a card populates the input and sends immediately.

Card anatomy:
```
┌─────────────────────────────────────┐
│  Icon   Title text                  │
│         Subtitle — why this matters │
└─────────────────────────────────────┘
```

Card background: `Surface` (`#1E1E20`). Icon color: Sage. Title: `bodyMedium` Warm White. Subtitle: `bodySmall` Text Secondary.

---

## State 2 — Conversation

Shown when a conversation has at least one message. Blob is small, bottom-left.

### User Messages

- Right-aligned bubble
- Background: `SurfaceRaised` (`#272729`)
- Text: Warm White, `bodyMedium`
- **No action row under user messages**
- **Long-press** shows a context menu: Copy, Select Text, Edit (edit re-opens the input bar pre-filled)
- No timestamp shown inline (clean, like Claude)

### AI Response Anatomy — 4 Layers

Every AI response is a full-width block with up to 4 layers rendered top-to-bottom:

**Layer 0 — Thinking (conditional)**
- Shown only when `isStreaming` and reasoning steps exist
- Collapsed by default: a single-line strip reading "Zura is thinking..." with the blob in `thinking` animation state on the left and a chevron-down on the right
- Tap to expand: shows the full reasoning step list in a scrollable sub-container
- Background: `Surface` with a left border in Sage (4px)
- Hidden entirely once response is complete (collapses away)

**Layer 1 — Response Text**
- Full-width, no bubble
- Markdown rendered (bold, italic, lists, code blocks)
- Text: Warm White, `bodyMedium`
- Streams in token by token

**Layer 2 — Action Row** (appears after streaming ends)
- Horizontal row of icon buttons: Copy · 👍 · 👎 · Share · Redo
- Style: ghost icon buttons, Text Secondary color, no background
- Spacing: tight, left-aligned under the message text

**Layer 3 — Footer**
- Small blob (28px, `talking` → `idle` animation) on the left
- "AI can make mistakes. Please double-check responses." on the right
- Text: `bodySmall`, Text Secondary

### Message List

- `ListView` with `reverse: false`, auto-scrolls to bottom on new tokens
- Scroll-to-bottom FAB appears when user has scrolled up
- No date separators (clean)
- Artifact cards rendered inline between messages (see State 3)

---

## State 3 — Artifacts

Artifact cards appear inline in the message thread when Zura performs an action (saves a memory, logs a journal entry, runs a data check). They are not separate messages — they appear as a section within or immediately after the relevant AI response.

### "Zura did this" Divider

A subtle full-width divider with the text "Zura did this" centered. Style: `bodySmall`, Text Secondary, with a 1px line on each side. Appears above a group of artifact cards.

### Artifact Card Types

| Type | Left border color | Icon | Label |
|------|------------------|------|-------|
| Memory saved | Sage `#CFE1B9` | `memory_rounded` | Memory saved |
| Journal logged | `#4CAF50` (green) | `edit_note_rounded` | Journal entry logged |
| Data check | `#2196F3` (blue) | `analytics_rounded` | Health data checked |

Card anatomy:
```
┌──────────────────────────────────────┐
│ │ [icon]  Label              [▶ tap] │
│ │         Short description          │
└──────────────────────────────────────┘
```

Background: `Surface`. Left border: 3px solid type color. Tap to expand/navigate (stub for now — shows a snackbar).

---

## Ghost Mode

### App Bar Button

- Icon: `visibility_off_rounded` (or a ghost icon if available in project assets)
- Placement: right side of app bar, before the overflow menu
- State: inactive = Text Secondary; active = Sage with subtle glow

### Activation

Tapping the button shows a bottom sheet confirmation:
> **Ghost Mode**
> "Nothing you say here will be saved or remembered by Zura. This conversation disappears when you leave."
> [Cancel] [Start Ghost Session]

### Active State Visual Treatment

- Persistent banner below app bar:
  - Left: ghost icon (Sage)
  - Center: "Ghost Mode — nothing is being saved"
  - Right: "Exit" text button (Sage)
- Screen background shifts from Canvas `#161618` to a slightly cooler/darker tint (`#111113`) to signal the mode visually
- Input bar placeholder text changes to "Ask anything — this stays private"

### Deactivation

Tapping "Exit" in the banner shows a confirmation: "End ghost session? This conversation will be cleared." → [Cancel] [End Session]. On confirm: conversation cleared, banner dismissed, background returns to normal, screen returns to IdleState.

---

## Input Bar

No functional changes. Visual updates only:

- Ghost mode: placeholder text changes (see above)
- Idle state: placeholder "Ask Zura anything…"
- Conversation state: placeholder "Message Zura…"
- Send button uses existing `ZButton` primary variant (Sage + pattern)

---

## Navigation & History

No changes to the `ConversationDrawer`. Hamburger icon in app bar opens it exactly as today. Loading a past conversation from the drawer sets it as the active conversation on `CoachScreen` and shows ConversationState. Ghost mode conversations are never added to the drawer.

---

## Files Changed

| File | Action | Notes |
|------|--------|-------|
| `zuralog/lib/features/coach/presentation/coach_screen.dart` | **Create** | Replaces NewChatScreen as the root Coach tab widget |
| `zuralog/lib/features/coach/presentation/new_chat_screen.dart` | **Delete** | Replaced by CoachScreen |
| `zuralog/lib/features/coach/presentation/chat_thread_screen.dart` | **Delete** | Merged into CoachScreen |
| `zuralog/lib/features/coach/presentation/widgets/coach_blob.dart` | **Create** | Animated blob mascot widget (3 states, 2 sizes) |
| `zuralog/lib/features/coach/presentation/widgets/coach_idle_state.dart` | **Create** | Idle layout: blob + greeting + suggestion cards |
| `zuralog/lib/features/coach/presentation/widgets/coach_suggestion_card.dart` | **Create** | Single suggestion card with icon + title + subtitle |
| `zuralog/lib/features/coach/presentation/widgets/coach_message_list.dart` | **Create** | Message list + artifact card rendering |
| `zuralog/lib/features/coach/presentation/widgets/coach_ai_response.dart` | **Create** | 4-layer AI response anatomy (thinking + text + actions + footer) |
| `zuralog/lib/features/coach/presentation/widgets/coach_user_message.dart` | **Create** | Right-aligned user bubble with long-press context menu |
| `zuralog/lib/features/coach/presentation/widgets/coach_artifact_card.dart` | **Create** | Inline artifact card (memory / journal / data types) |
| `zuralog/lib/features/coach/presentation/widgets/coach_ghost_banner.dart` | **Create** | Persistent ghost mode banner |
| `zuralog/lib/features/coach/presentation/widgets/coach_thinking_layer.dart` | **Create** | Collapsible Layer 0 thinking strip |
| `zuralog/lib/core/navigation/app_router.dart` | **Modify** | Update Coach tab route to point to CoachScreen |
| `zuralog/lib/features/coach/presentation/widgets/conversation_drawer.dart` | **No change** | Drawer works as-is |
| `zuralog/lib/features/coach/presentation/widgets/coach_input_bar.dart` | **Modify** | Placeholder text changes for ghost mode / idle / conversation |

---

## Out of Scope

- No changes to providers, domain models, or the cloud-brain API
- No light mode (dark mode only per design system)
- No accessibility audit (separate task)
- Artifact card navigation (tap shows snackbar stub — real navigation in a future task)
- Onboarding / first-run flow
- Push notification integration
