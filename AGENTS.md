# Zuralog

Hybrid Hub app — centralizes health/fitness data into a single Action Layer.
- **Cloud Brain:** Python/FastAPI | **Edge Agent:** Swift/Kotlin (HealthKit/Health Connect)
- **PRD:** [Product Requirements Document](./docs/plans/product-requirements-document.md)

### Project Structure
| Folder | Purpose | Deployed To |
|--------|---------|-------------|
| `zuralog/` | Mobile app (Flutter) | Apple App Store & Google Play |
| `cloud-brain/` | Backend server (Python/FastAPI) | Railway |
| `website/` | Marketing website (Next.js) | Vercel |
| `docs/` | Documentation for developers & agents | — |

## Skills

Check `.agent/skills/` before every task. If a skill applies, **use it**.

| Skill | Path |
|-------|------|
| Flutter & Dart | [.agent/skills/flutter-expert/SKILL.md](./.agent/skills/flutter-expert/SKILL.md) |
| Superpowers | [.agent/skills/superpowers/skills/using-superpowers/SKILL.md](.agent/skills/superpowers/skills/using-superpowers/SKILL.md) |
| Frontend Design | [.agent/skills/frontend-design/SKILL.md](./.agent/skills/frontend-design/SKILL.md) |
| MAD Agents | [.agent/skills/mad-agents-skills/README.md](./.agent/skills/mad-agents-skills/README.md) |

---

## Rules

### 1. Git Discipline
- Create a new branch (e.g., `feat/task-name`) before executing any plan. **Never work on `main`.**
- Commit and push at every logical checkpoint. Do not wait for perfection.
- Merge only when the entire phase is complete with zero errors/warnings. **Squash merge** to keep `main` history clean.

### 2. Context Awareness
Before starting work, read relevant files for context (e.g., existing implementations, related docs in `docs/`, or prior executed summaries in `docs/agent-executed/`). Do not assume — verify.

### 3. Post-Execution Documentation
After completing a phase, create `docs/agent-executed/[backend|frontend]/phases/executed-phase-[X.Y.Z].[name].md`:
- What was built, deviations from plan (with reasons), and next steps. No code blocks.

### 4. Final Review Only
Do not perform visual QA or detailed review after every sub-task. Perform a single comprehensive review (including Playwright screenshots for UI work) at the end of the last task in a sequence.

### 5. Cleanup Before Push
At final review, delete all temporary artifacts (screenshots, scratch files, test outputs) from the working tree. Nothing generated during the session should be pushed to the remote repository.

### 6. AI Working Directories
Each tool writes plans to its own **gitignored** directory. Never use another tool's directory.
- OpenCode → `.opencode/plans/` | Cursor → `.cursor/` | AntiGravity → its artifact directory

### 7. Design System Tokens (Flutter)
Use the **Frontend Design skill** for all UI/UX decisions — aim for bold, premium designs. No hardcoded hex in widget files.
- **Brand color:** Sage Green `#CFE1B9` (`AppColors.primary`)

| Token | Light | Dark |
|-------|-------|------|
| `scaffoldBackgroundColor` | `#FAFAFA` | `#000000` (OLED) |
| `colorScheme.surface` | `#FFFFFF` | `#1C1C1E` |

- Typography: `AppTextStyles` only — no ad-hoc `TextStyle(...)`.
- Primary actions: pill `FilledButton` with `AppColors.primary` (Sage Green).
- Cards: `borderRadius: 24`, soft shadow (light) / 1px border (dark).
