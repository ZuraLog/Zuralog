# Zuralog

Hybrid Hub app — centralizes health/fitness data into a single Action Layer.
- **Cloud Brain:** Python/FastAPI | **Edge Agent:** Flutter (HealthKit/Health Connect)

## Project Structure

| Folder | Purpose | Deployed To |
|--------|---------|-------------|
| `zuralog/` | Mobile app (Flutter) | Apple App Store & Google Play |
| `cloud-brain/` | Backend server (Python/FastAPI) | Railway |
| `website/` | Marketing website (Next.js) | Vercel |
| `docs/` | Documentation for developers & agents | — |

## Documentation

All project documentation lives in `docs/`. Read the relevant doc before starting any task. Do not assume — verify against the actual codebase.

| Document | Purpose |
|----------|---------|
| `docs/PRD.md` | Product vision, user scenarios, AI decisions, business model |
| `docs/architecture.md` | Technical architecture, all ADRs, data flows, security model |
| `docs/infrastructure.md` | All services, deployment, costs, environment variables |
| `docs/roadmap.md` | Living checklist — update status as work completes |
| `docs/implementation-status.md` | Historical record of what was built and how |
| `docs/design.md` | Brand colors, typography, design philosophy |
| `docs/screens.md` | Mobile screen inventory, navigation structure, UI rebuild directive |
| `docs/mvp-features.md` | MVP feature specification, settings reference |
| `docs/integrations/` | Per-integration reference (Strava, Fitbit, Apple Health, Health Connect) |

## Skills

CRITICAL: This project has **local project skills** stored in `.agent/skills/`. These are NOT global skills — they exist only in this repository. Before every task, check whether a skill applies and load it using the `skill` tool.

| Skill | Path |
|-------|------|
| Flutter & Dart | `.agent/skills/flutter-expert/SKILL.md` |
| Frontend Design | `.agent/skills/frontend-design/SKILL.md` |
| FastAPI Templates | `.agent/skills/fastapi-templates/SKILL.md` |
| MCP Builder | `.agent/skills/mcp-builder/SKILL.md` |
| Doc Co-Authoring | `.agent/skills/doc-coauthoring/SKILL.md` |
| Supabase / Postgres | `.agent/skills/supabase-postgres-best-practices/SKILL.md` |

## Subagents

CRITICAL: Specialized subagents are always available globally. You must route work to the correct subagent — never do the work yourself when a subagent owns it. Every subagent is purpose-built and model-optimized for its role.

| Subagent | Model | Invoke when |
|----------|-------|-------------|
| `git` | Haiku 4.5 | Any git operation — branching, staging, committing, pushing, merging, history |
| `plan` | Opus 4.6 | Architecture decisions, implementation planning, any non-trivial feature design |
| `review` | Sonnet 4.6 | Code review after implementation — quality, security baseline, correctness |
| `test` | Sonnet 4.6 | Writing and running tests after implementation completes |
| `docs` | Haiku 4.5 | Updating any documentation file anywhere in the project |
| `db` | Opus 4.6 | Any schema design, migration, RLS policy, index, or query pattern decision |

## Execution

CRITICAL: All implementation work must follow the `subagent-driven-development` skill. No exceptions.

1. Load `.agent/skills/superpowers/subagent-driven-development/SKILL.md` before executing any plan.
2. The skill's implementer subagent must invoke the `git` subagent for all commits — never commit directly.
3. The skill's implementer subagent must invoke the `db` subagent before any schema change or new query pattern.
4. Use your `review` subagent as both the spec compliance reviewer and code quality reviewer in the skill's two-stage review loop.
5. After all tasks are complete, invoke `docs` to update relevant documentation, then `git` to commit those changes.

## Git

CRITICAL: Follow this workflow exactly — no exceptions.

1. **Always create a branch first.** Never commit directly to `main`. Use `feat/`, `fix/`, or `chore/` prefixes (e.g. `feat/auth-flow`).
2. **Always use the `git` subagent for all git operations.** Never run git commands yourself.
3. **Commit and push at every logical checkpoint.** Do not batch work into one large commit at the end.
4. **Merge only after all builds and tests pass** with zero errors or warnings. Use a regular merge — no squash — to preserve full history.
5. **Delete the branch after merging.**

## Scale

CRITICAL: We are building for 1 million users from day one. Every decision — schema design, API design, caching, queuing, indexing — must be made with that scale in mind. Never write code that is "good enough for now." There is no "we'll optimize later."

## Security

CRITICAL: Before writing any code, ask: "Can someone abuse this?" Apply this to every endpoint, every input, every auth check, every database query. Enforce rate limiting, validate all inputs, never expose secrets, use least-privilege access everywhere, and assume all external data is hostile.
