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
**Location:** `docs/plans/backend/phases/`

| Phase | Description | Status |
| :--- | :--- | :--- |
| **1.1** | [Foundation & Infrastructure](backend/phases/phase-1.1-foundation-and-infrastructure/phase-1.1-goal-and-checklist.md) | Ready |
| **1.2** | [Auth & User Management](backend/phases/phase-1.2-authentication-and-user-management/phase-1.2-goal-and-checklist.md) | Ready |
| **1.3** | [MCP Base Framework](backend/phases/phase-1.3-mcp-base-framework/phase-1.3-goal-and-checklist.md) | Ready |
| **1.4** | [Apple HealthKit](backend/phases/phase-1.4-apple-healthkit-integration/phase-1.4-goal-and-checklist.md) | Ready |
| **1.5** | [Google Health Connect](backend/phases/phase-1.5-google-health-connect-integration/phase-1.5-goal-and-checklist.md) | Ready |
| **1.6** | [Strava Integration](backend/phases/phase-1.6-strava-integration/phase-1.6-goal-and-checklist.md) | Ready |
| **1.7** | [CalAI Integration](backend/phases/phase-1.7-calai-integration/phase-1.7-goal-and-checklist.md) | Ready |
| **1.8** | [The AI Brain](backend/phases/phase-1.8-ai-brain/phase-1.8-goal-and-checklist.md) | Ready |
| **1.9** | [Chat & Communication](backend/phases/phase-1.9-chat-and-communication/phase-1.9-goal-and-checklist.md) | Ready |
| **1.10** | [Background Services](backend/phases/phase-1.10-background-services/phase-1.10-goal-and-checklist.md) | Ready |
| **1.11** | [Analytics](backend/phases/phase-1.11-analytics/phase-1.11-goal-and-checklist.md) | Ready |
| **1.12** | [Autonomous Actions](backend/phases/phase-1.12-autonomous-actions/phase-1.12-goal-and-checklist.md) | Ready |
| **1.13** | [Subscription](backend/phases/phase-1.13-subscription/phase-1.13-goal-and-checklist.md) | Ready |
| **1.14** | [E2E Testing](backend/phases/phase-1.14-e2e-testing/phase-1.14-goal-and-checklist.md) | Ready |

> **The Rule for Phase 1:** DO NOT style anything. Use raw buttons and text. If it looks good, you're wasting time. Make it work first.

### Phase 2: Frontend Implementation
**Focus:** Visuals, UX, Animations, "Wow" Factor.
**Location:** `docs/plans/frontend/phases/`

| Phase | Description | Status |
| :--- | :--- | :--- |
| **2.1** | [Design System](frontend/phases/phase-2.1-design-system/phase-2.1-goal-and-checklist.md) | Ready |
| **2.2** | [Screen Implementation](frontend/phases/phase-2.2-screen-implementation/phase-2.2-goal-and-checklist.md) | Ready |
| **2.3** | [Navigation & Polish](frontend/phases/phase-2.3-navigation-and-polish/phase-2.3-goal-and-checklist.md) | Ready |
| **2.4** | [Verification](frontend/phases/phase-2.4-verification/phase-2.4-goal-and-checklist.md) | Ready |

> **The Rule for Phase 2:** DO NOT touch backend logic (unless bug fixing). Focus purely on the user experience and visual polish.

---

## 3. How to Execute

1.  **Start with Phase 1.1**: Open the Goal/Checklist file. Execute step-by-step.
2.  **Verify Logic**: Use the Test Harness to prove functionality.
3.  **Transition**: Once Phase 1.14 is done, move to Phase 2.
4.  **Finish with Phase 2.4**: Verify the final product.

---

## 4. Skills & Tools
-   **Superpower Skill**: Use for high-level reasoning and cross-domain synthesis.
-   **Flutter Expert**: Use for all Dart/Flutter code.
-   **MCP**: Use for all external integrations.
