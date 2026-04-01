# Coach Tab

The Coach tab is a conversational AI assistant that knows your health data.

Its job is to answer: **"What should I do about my health?"**

Unlike the other tabs which show numbers and charts, the Coach tab is a chat interface. Users can ask questions in plain language — "Why have I been sleeping poorly this week?", "Should I take a rest day?", "Help me plan my meals for tomorrow" — and get answers that are grounded in their actual health data, not generic advice.

The coach has access to everything the user has logged and synced. It can reference specific days, spot patterns, and connect dots across different metrics. When it says "your sleep has been worse on days you skip your evening walk," it is drawing from real data, not guessing.

The coach's personality is configurable. Users can choose how it talks to them — tough and direct, balanced and honest, or warm and gentle. They can also control how chatty it is (whether it volunteers observations or waits to be asked) and whether it gives short or detailed responses.

The Coach tab is the intelligence layer of Zuralog. The other tabs show you what happened. The Coach tab helps you understand why it happened and what to do next.

Conversations are stored so users can pick up where they left off. The coach builds up a memory of the user's goals, preferences, and context over time, getting more useful the longer someone uses it. Users can control this memory from Settings → Coach → Memory: toggle it on or off, view stored facts, and delete anything they want.

---

## UI Structure (as of 2026-03-31)

The Coach tab now uses a **single adaptive screen** (`CoachScreen`) that manages all visual states inline:

### Visual States

- **Idle State** — User opens the tab with no active conversation. Shows the animated blob mascot (80px), a time-adaptive greeting ("Good morning, afternoon, evening"), and three hardcoded suggestion cards for quick-start interactions.

- **Conversation State** — User has sent messages or is in an active thread. Shows a scrollable message list with user bubbles (right-aligned, long-press menu for copy/edit), AI responses (markdown text + thinking indicator + action row), and optional artifact cards (memory/journal/data actions). A scroll-to-bottom FAB appears when scrolled up.

- **Ghost Mode** — Optional state (toggled via settings) where nothing is saved. A persistent banner appears at the top saying "Nothing is being saved. Exit Ghost Mode?" The conversation works normally but won't persist.

### Key Components

- **CoachBlob** — Animated mascot with 3 states (idle/thinking/talking) and 2 sizes (80px in idle UI, 28px embedded in message footers). Spring-based physics for character feel.

- **Coach Thinking Layer** — Collapsible strip that shows "Zura is thinking..." while the AI generates a response.

- **AI Response Block** — 4-layer structure: thinking indicator + markdown text body + action row (links, buttons) + footer blob.

- **Artifact Cards** — Inline cards that appear when the AI suggests a memory save, journal entry, or data visualization. Can be dismissed or acted upon without leaving the chat.

- **Message List** — Scrollable thread of user messages and AI responses, with proper padding and alignment.

### Input

The chat input bar (reusable `CoachInputBar` widget) has a customizable placeholder, defaulting to "Message Zura…".
