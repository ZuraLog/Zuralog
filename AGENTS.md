# Zuralog

Hybrid Hub app — centralizes health/fitness data into a single Action Layer.
- **Cloud Brain:** Python/FastAPI | **Edge Agent:** Flutter (HealthKit/Health Connect)
- **PRD:** [Product Requirements Document](./docs/PRD.md)

### Project Structure
| Folder | Purpose | Deployed To |
|--------|---------|-------------|
| `zuralog/` | Mobile app (Flutter) | Apple App Store & Google Play |
| `cloud-brain/` | Backend server (Python/FastAPI) | Railway |
| `website/` | Marketing website (Next.js) | Vercel |
| `docs/` | Documentation for developers & agents | — |

## Documentation

All project documentation lives in `docs/`. Read the relevant doc before starting any task.

| Document | Purpose |
|----------|---------| 
| [`docs/PRD.md`](./docs/PRD.md) | Product vision, user scenarios, AI decisions, business model |
| [`docs/architecture.md`](./docs/architecture.md) | Technical architecture, all ADRs, data flows, security model |
| [`docs/infrastructure.md`](./docs/infrastructure.md) | All services, deployment, costs, environment variables |
| [`docs/roadmap.md`](./docs/roadmap.md) | Living checklist — update status as work completes |
| [`docs/implementation-status.md`](./docs/implementation-status.md) | Historical record of what was built and how |
| [`docs/design.md`](./docs/design.md) | Brand colors, typography, design philosophy (exploration-first) |
| [`docs/screens.md`](./docs/screens.md) | Mobile screen inventory, navigation structure, user intent model, full UI rebuild directive |
| [`docs/mvp-features.md`](./docs/mvp-features.md) | MVP feature specification, post-MVP features, design impact, settings reference, GitHub issues |
| [`docs/integrations/`](./docs/integrations/) | Per-integration reference (Strava, Fitbit, Apple Health, Health Connect, planned) |

## Skills

Check `.agent/skills/` before every task. If a skill applies, **use it**. These are **local project skills** stored in this repository — not global skills.

| Skill | Path |
|-------|------|
| Flutter & Dart | [.agent/skills/flutter-expert/SKILL.md](./.agent/skills/flutter-expert/SKILL.md) |
| Frontend Design | [.agent/skills/frontend-design/SKILL.md](./.agent/skills/frontend-design/SKILL.md) |
| FastAPI Templates | [.agent/skills/fastapi-templates/SKILL.md](./.agent/skills/fastapi-templates/SKILL.md) |
| MCP Builder | [.agent/skills/mcp-builder/SKILL.md](./.agent/skills/mcp-builder/SKILL.md) |
| Doc Co-Authoring | [.agent/skills/doc-coauthoring/SKILL.md](./.agent/skills/doc-coauthoring/SKILL.md) |
| Supabase / Postgres | [.agent/skills/supabase-postgres-best-practices/SKILL.md](./.agent/skills/supabase-postgres-best-practices/SKILL.md) |

## Rules

### 1. Git Discipline
- Create a new branch (e.g., `feat/task-name`) before executing any plan. **Never work on `main`.**
- Commit and push at every logical checkpoint. Do not wait for perfection.
- Merge only when the entire phase is complete with zero errors/warnings. **Squash merge** to keep `main` history clean.

### 2. Context Awareness
Before starting work, read the relevant docs in `docs/` for context — `architecture.md` for backend tasks, `design.md` for UI tasks, the relevant file in `docs/integrations/` for integration work. Do not assume — verify against the actual codebase.

### 3. Post-Execution Documentation
After completing a significant phase or feature:
- Update the relevant status column in [`docs/roadmap.md`](./docs/roadmap.md)
- Add a brief summary to [`docs/implementation-status.md`](./docs/implementation-status.md) if the work is substantial
- Do not create one-off plan files or task-specific markdown files in `docs/`

### 4. Final Review Only
Do not perform visual QA or detailed review after every sub-task. Perform a single comprehensive review (including Playwright screenshots for UI work) at the end of the last task in a sequence.

### 5. Cleanup Before Push
At final review, delete all temporary artifacts (screenshots, scratch files, test outputs) from the working tree. Nothing generated during the session should be pushed to the remote repository.

### 6. AI Working Directories
Each tool writes plans to its own **gitignored** directory. Never use another tool's directory.
- Claude Code → `.Claude/plans/` | Cursor → `.cursor/` | AntiGravity → its artifact directory

### 7. Design System Tokens (Flutter)
Use the **Frontend Design skill** for all UI/UX decisions — aim for award-winning, premium designs. No hardcoded hex in widget files.
- **Brand color:** Sage Green `#CFE1B9` (`AppColors.primary`)
- **Dark-first.** Dark mode is the priority and default. Light mode is supported.
- **Design direction:** Editorial / typographic, Apple Fitness+ caliber. See [`docs/design.md`](./docs/design.md)
- **Screen inventory:** See [`docs/screens.md`](./docs/screens.md) for all screens, navigation, and the full UI rebuild directive.

| Token | Value |
|-------|-------|
| `scaffoldBackgroundColor` | `#000000` (OLED true black) |
| `colorScheme.surface` | `#1C1C1E` (elevated surfaces) |
| `cardBackground` | `#121212` (standard cards) |

- Typography: `AppTextStyles` only — no ad-hoc `TextStyle(...)`.
- Primary actions: `FilledButton` with `AppColors.primary` (Sage Green), `borderRadius: 14`.
- Cards: `borderRadius: 20`, **no border, no shadow** — defined by background color contrast only.
- Health categories: each has a dedicated color (see `design.md`). Use `AppColors.category*` tokens.

### 8. Security First
- Heavily reinforce security: never expose API Keys, implement strict API limits, and proactively prevent abuse.

### 9. Scalability & Longevity
- Think about scale from day one. We are building a production-grade system that lasts, not a demo or MVP. Focus on robust architecture and performance.
