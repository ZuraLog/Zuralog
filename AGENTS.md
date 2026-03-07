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

## Git

CRITICAL: Follow this workflow exactly — no exceptions.

1. **Always create a branch first.** Never commit directly to `main`. Use `feat/`, `fix/`, or `chore/` prefixes (e.g. `feat/auth-flow`).
2. **Use a subagent for all git operations** to keep the primary context clean.
3. **Commit and push at every logical checkpoint.** Do not batch work into one large commit at the end.
4. **Merge only after all builds and tests pass** with zero errors or warnings. Use a regular merge — no squash — to preserve full history.
5. **Delete the branch after merging.**

## Scale

CRITICAL: We are building for 1 million users from day one. Every decision — schema design, API design, caching, queuing, indexing — must be made with that scale in mind. Never write code that is "good enough for now." There is no "we'll optimize later."

## Security

CRITICAL: Before writing any code, ask: "Can someone abuse this?" Apply this to every endpoint, every input, every auth check, every database query. Enforce rate limiting, validate all inputs, never expose secrets, use least-privilege access everywhere, and assume all external data is hostile.
