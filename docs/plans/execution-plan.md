# Master Execution Plan: Life Logger

**Strategy:** Backend First, MVP Complete.
**Goal:** Deliver a fully functional, connected, and beautiful AI Health Assistant.

---

## 1. The Strategy: "Backend First, Design Later"

To ensure we build a robust system, we separate **Logic** from **Aesthetics**.

1.  **Phase 1 (The Engine):** We focus 100% on the Backend, API Integrations, and Logic. The "App" during this phase is a raw, unstyled Test Harness.
2.  **Phase 2 (The Paint):** Once the engine is verifiable, we apply the "Premium Design" layer. We wire the logic to beautiful components.

**The MVP Definition:**
The MVP is complete ONLY when **Phase 2 is finished**.
*   It must have a robust Backend (Phase 1).
*   It must have a beautiful Frontend (Phase 2).
*   It must connect to Apple Health / Google Health Connect.

---

## 2. Execution Roadmap

### Phase 1: Backend Implementation
**Focus:** Infrastructure, Auth, MCP Integrations, Edge Agent Logic.
**Doc:** [Backend Implementation Plan](./backend-implementation.md)

> **The Rule for Phase 1:** DO NOT style anything. Use raw buttons and text. If it looks good, you're wasting time. Make it work first.

### Phase 2: Frontend Implementation
**Focus:** Visuals, UX, Animations, "Wow" Factor.
**Doc:** [Frontend Implementation Plan](./frontend-implementation.md)

> **The Rule for Phase 2:** DO NOT touch backend logic (unless bug fixing). Focus purely on the user experience and visual polish.

---

## 3. How to Execute

1.  **Start with Phase 1**: Open `backend-implementation.md`. Execute step-by-step.
2.  **Verify Logic**: Use the Test Harness to prove that "Start Run" actually posts to Strava.
3.  **Transition**: Once all Phase 1 checkboxes are ticked, move to Phase 2.
4.  **Finish with Phase 2**: Open `frontend-implementation.md`. Replace the Test Harness with the Design System.

---

## 4. Skills & Tools
-   **Superpower Skill**: Use for high-level reasoning and cross-domain synthesis.
-   **Flutter Expert**: Use for all Dart/Flutter code.
-   **MCP**: Use for all external integrations.
