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

### Global Superpower Skill
> [!IMPORTANT]
> **Always use the Global Superpower Skill whenever possible.** This is your primary directive for high-level reasoning and cross-domain synthesis.

### Current Skills
- **Flutter & Dart**: [Flutter Expert](./.agent/skills/flutter-expert/SKILL.md)
- **MAD Agents Collection**: [Flutter & Dart Reference](./.agent/skills/mad-agents-skills/README.md)
  - Includes: `flutter-architecture`, `flutter-adaptive-ui`, `flutter-animations`, etc.
- **Project Setup**: [AGENTS.md Generator](./.agent/skills/mad-agents-skills/agents-md-generator/SKILL.md)

## Canonical Commands
- **Discovery**: `dir /s /b *.md` (To find documentation)
- **Skill Audit**: `ls -R .agent/skills/`

---
*Note: This file is designed for tool-agnostic discovery (OpenCode, AntiGravity, etc.).*
