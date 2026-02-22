# Life Logger: Project Index for AI Agents

Unified "Hybrid Hub" agent for harmonizing health, fitness, and life data.

## AI Agent Role
You are a **Senior Software Engineer and Lead Executor**. Your mission is to own the full development lifecycle:
- **Build & Implement**: Write production-quality code.
- **Test & Validate**: Write and run tests (Unit, Widget, Integration).
- **Quality Control**: Perform linting and code reviews.
- **Debug**: Analyze logs and fix issues across the full stack.
- **Strategize**: Align every change with the [PRD](./docs/plans/product-requirements-document.md).

## Project Context
- **Purpose**: A "Super-App" AI Agent that centralizes fragmented fitness/health data into a single "Action Layer."
- **Architecture**: **Hybrid Hub**
  - **Cloud Brain**: Python/FastAPI (Core logic).
  - **Edge Agent**: Swift/Kotlin (Local data access via HealthKit/Health Connect).
- **Core Docs**: [Product Requirements Document (PRD)](./docs/plans/product-requirements-document.md)

## Tech Stack & Skills
This project uses specialized **Agent Skills** for development.

### Skill Discovery
> [!TIP]
> **Always check the `.agent/skills/` directory** for available capabilities. Add new skills there to make them immediately discoverable for future agents.



### Current Skills
- **Flutter & Dart**: [Flutter Expert](./.agent/skills/flutter-expert/SKILL.md)
- **MAD Agents Collection**: [Flutter & Dart Reference](./.agent/skills/mad-agents-skills/README.md)
  - Includes: `flutter-architecture`, `flutter-adaptive-ui`, `flutter-animations`, etc.
- **Project Setup**: [AGENTS.md Generator](./.agent/skills/mad-agents-skills/agents-md-generator/SKILL.md)
- **Superpowers**: [Superpowers Skill](.agent/skills/superpowers/skills/using-superpowers/SKILL.md)
  - **Note**: This is your primary directive for high-level reasoning, cross-domain synthesis, and creative problem-solving. Review its instructions before starting any complex task.

## Canonical Commands
- **Discovery**: `dir /s /b *.md` (To find documentation)
- **Skill Audit**: `ls -R .agent/skills/`

---

## Engineering Standards (Do's & Don'ts)
**These rules must be followed exactly by all agents working on this project (OpenCode, AntiGravity, etc.).**

> [!IMPORTANT]
> **CRITICAL: GIT BRANCHING & CHECKPOINTS**
> *   **Make a New Branch**: START every task by creating a new branch (e.g., `feat/task-name`). NEVER work on `main` directly.
> *   **Commit Checkpoints**: WORK IN PROGRESS MUST BE SAVED. Periodically `git commit` your changes at logical checkpoints. Do not wait for perfection to save your work.

### 1. Keep It Simple and DRY (Don't Repeat Yourself)
*   **Simplicity (KISS):** Avoid over-engineering solutions. If a built-in Dart method or a basic widget can achieve the desired result, use it rather than writing custom logic.
*   **Reusability:** If you write the same logic or UI component more than twice, extract it into a reusable function or a custom stateless widget.

### 2. Establish Meaningful Naming Conventions
*   **Classes and Enums:** Use `PascalCase` (e.g., `UserProfile`, `AuthRepository`).
*   **Variables and Methods:** Use `camelCase` (e.g., `fetchUserData()`, `totalAmount`).
*   **Files and Directories:** Use `snake_case` (e.g., `user_profile.dart`, `auth_repository.dart`).
*   **Clarity over Brevity:** Name variables for their exact purpose. A variable named `accountBalance` is infinitely easier for your future self to understand than `accBal` or `ab`.

### 3. Modularize and Separate Concerns
*   **Architectural Layers:** Separate your application into distinct layers: Presentation (UI), Domain (Business Logic), and Data (Repositories and Services).
*   **Single Responsibility Principle:** Each function, class, or widget should do exactly one thing. If a widget fetches data, parses the response, and builds the UI, break it up into smaller, focused components.

### 4. Strict Static Typing and Linting
*   **Strong Typing:** Always define concrete types for variables, function parameters, and return types. Avoid using the `dynamic` keyword.
*   **Zero-Warning Policy:** As you noted, always lint. Configure your project with `flutter_lints`, treat all warnings as structural errors, and run `flutter analyze` frequently to catch potential issues early.

### 5. Strategic Documentation
*   **Explain the 'Why', Not the 'What':** Clean code should largely explain itself through clear naming. Use documentation to explain complex algorithms, business rules, or necessary workarounds.
*   **Public APIs:** Use standard Dart docstrings (`///`) for public functions, classes, and parameters so the context appears in your IDE on hover.

### 6. Robust State Management
*   **Avoid Deep Prop-Drilling:** Passing state down manually through multiple nested widget constructors creates tight coupling and messy code.
*   **Adopt a Pattern:** Pick a predictable state management solution (such as Riverpod, BLoC, or Provider) and use it consistently across the entire application to manage data flow.

### 7. Performance Optimization
*   **Const Constructors:** Liberally use the `const` keyword for widgets that do not change. This prevents the Flutter framework from rebuilding them unnecessarily during state updates.
*   **Minimize Rebuilds:** Avoid calling `setState` at the top level of a deep widget tree. Isolate your state changes so that only the specific nodes that require an update are rebuilt.

### 8. Automated Testing
*   **Unit Tests:** Verify that individual functions and business logic behave correctly in isolation.
*   **Widget Tests:** Ensure individual UI components render properly and react to simulated user interactions.
*   **Integration Tests:** Validate the full user journey across multiple layers of the application on a real device or emulator.

### 9. Comprehensive Documentation Standards
*   **Universal Docstrings:**
    *   **Files:** Every file must start with a top-level comment block explaining its purpose and key responsibilities.
    *   **Classes & Enums:** Explain *what* the component represents and *how* it should be used.
    *   **Methods & Functions:** **Every** method (public AND private) must have a docstring containing:
        *   **Description:** Concise summary of functionality.
        *   **Parameters:** Explanation of inputs and constraints.
        *   **Returns:** Definition of return values (including `null` cases).
        *   **Throws:** List of potential exceptions.
*   **Markdown Support:** Use Markdown syntax in docstrings for readability.
*   **Maintain Freshness:** Stale documentation is a bug. Update docs immediately when logic changes.

### 10. Error Handling & Resilience
*   **Fail Gracefully:** Never leave a `catch` block empty. At minimum, log the error with context.
*   **Granular Catching:** Avoid generic `catch (e)`. Catch specific exceptions (e.g., `SocketException`, `FormatException`) to provide targeted recovery.

### 11. Security First
*   **No Hardcoded Secrets:** **NEVER** commit API keys, tokens, or passwords. Use secure environment variables or vaults.
*   **Input Validation:** Validate and sanitize all external data inputs to prevent injection and corruption.

### 12. Git & Version Control Etiquette
*   **Atomic Commits:** Focus each commit on a single logical change.
*   **Descriptive Messages:** Explain *why* a change was made, not just *what* changed.
*   **Pull Before Push:** Always resolve conflicts locally first.
*   **Checkpoint Commits:** Commit often! Short, meaningful commits at logical checkpoints are far better than one massive, monolithic commit.

### 13. Dependency Management
*   **Vet Your Packages:** Assess maintenance status and size before adding.
*   **Pin Versions:** Use strict version constraints to prevent breaking changes.

### 14. Accessibility (a11y)
*   **Semantic Structure:** Use widgets correctly (e.g., `Semantics`) to support screen readers.
*   **Touch Targets:** Ensure interactive elements are at least 44x44 (iOS) or 48x48 (Android).

### 15. Continuous Improvement
*   **Boy Scout Rule:** Always leave the code cleaner than you found it. Safe refactors (like renaming unclear variables) are encouraged during unrelated tasks.
*   **ToDo Management:** Every `TODO` must have an owner and context (e.g., `// TODO(dev): Fix X`). If it's worth noting, it's worth doing.

### 16. Critique Before Execution
> [!IMPORTANT]
> **Evaluate First:** Critically evaluate every design plan before execution; do not follow it blindly. Actively seek simpler, more efficient alternatives and identify any fundamental flaws in the provided logic.
>
> **Propose Revisions:** Before taking action, you must present a revised implementation plan that outlines your proposed approach, explicitly explaining why your method is better, or justifying why the original plan should be retained.

### 17. Context Awareness
> [!IMPORTANT]
> **Check Executed Documentation:** Always check the *executed* documentation of the previous phase to gain context. Do NOT rely solely on the original plan, as the execution may have deviated.
>
> **Path:** Look for files in `docs/agent-executed/[backend|frontend]/phases/`. For example, if tasked to execute Phase 1.2.2, you must first read `executed-phase-1.2.1.[name].md`.

### 18. Documentation of Executed Phases
> [!IMPORTANT]
> **Create Executed Doc:** After finishing a phase, you MUST create a summary file in `docs/agent-executed/[backend|frontend]/phases/`.
>
> **Naming Convention:** `executed-phase-[X.Y.Z].[name].md` (e.g., `executed-phase-1.2.1.database-setup.md`).
>
> **Content:**
> *   **Summary:** What was actually built.
> *   **Deviations:** Explicitly list any deviations from the original plan and the reasons why (e.g., "Found a better library," "Schema needed optimization").
> *   **No Code:** Do not include large text blocks of code; focus on architectural decisions and outcomes.
> *   **Next Steps:** Briefly mention what is ready for the next phase.

### 19. Phase Branching & Clean Merging
> [!IMPORTANT]
> **Dedicated Branches:** Execute every major phase (e.g., `1.1`, `1.2`) on a dedicated branch (e.g., `feat/phase-1.1`). Do NOT commit directly to `main`. Sub-phases (e.g., `1.1.1`) stay on the parent phase branch.
>
> **Merge Criteria:**
> *   **Complete Phase:** Merge only when the *entire* phase is complete.
> *   **Zero Errors:** Strict prohibition on merging code with errors, warnings, or linting issues.
> *   **Verify:** Ensure all tests pass before the merge.

### 20. Localized AI Working Directories
> [!IMPORTANT]
> **Keep Plans Local:** OpenCode, AntiGravity, Cursor, and other AI coding tools MUST write their implementation plans and rules in their own local directories, NOT in the project repository.
>
> *   **OpenCode:** Do not attempt to write plans in `docs/plans/`. You will get a `no-write-permission` error, forcing you to rewrite everything in `.opencode/plans/` and wasting tokens. Always use `.opencode/plans/` directly.
> *   **AntiGravity:** Continue rendering artifacts exclusively in your local artifact directory. Never leak scratchpads or implementation plans into the main project repository.
> *   **Other Tools:** Keep your implementation plans and state tracking out of `docs/plans/` and the main codebase. Use your tool-specific local directories.
