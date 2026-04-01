"""
Zuralog Cloud Brain — Coach Skill MCP Server.

Exposes a get_skill tool so the LLM agent can load domain-specific
health and fitness reference documents before answering specialist
questions. Skills are loaded from markdown files on disk at startup.
"""

from __future__ import annotations

import logging
from pathlib import Path

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult

logger = logging.getLogger(__name__)


class CoachSkillMCPServer(BaseMCPServer):
    """MCP server exposing domain expertise documents to the LLM agent.

    Reads all ``*.md`` files from ``coach_skills/`` at construction time
    and indexes them by stem (filename without extension). The single
    ``get_skill`` tool lets the agent pull a full document into context
    before answering a specialist health or fitness question.

    Args:
        skills_dir: Directory containing the skill markdown files.
            Defaults to ``<package_root>/coach_skills/``.
    """

    def __init__(self, skills_dir: Path | None = None) -> None:
        """Load all skill files from *skills_dir* into memory.

        Iterates over every ``*.md`` file in the directory, stores the
        full content, and extracts a one-liner description from the
        ``## When to use this skill`` section to build a human-readable
        index. Files that cannot be read are skipped with a warning so
        a single bad file never prevents startup.

        Args:
            skills_dir: Path to the directory containing skill markdown
                files. Defaults to ``<package_root>/coach_skills/`` when
                ``None``.
        """
        if skills_dir is None:
            skills_dir = Path(__file__).parent.parent / "coach_skills"

        self._skills: dict[str, str] = {}
        self._index_text: str = ""

        if not skills_dir.exists() or not skills_dir.is_dir():
            logger.warning(
                "Coach skills directory not found or is not a directory: %s",
                skills_dir,
            )
            return

        descriptions: dict[str, str] = {}

        for file in skills_dir.glob("*.md"):
            try:
                content = file.read_text(encoding="utf-8")
            except Exception:
                logger.warning("Failed to read coach skill file: %s", file.name, exc_info=True)
                continue

            self._skills[file.stem] = content

            # Extract one-liner from the ## When to use this skill section.
            description = "(no description)"
            lines = content.splitlines()
            in_section = False
            for line in lines:
                if line.strip() == "## When to use this skill":
                    in_section = True
                    continue
                if in_section:
                    stripped = line.strip()
                    if not stripped:
                        continue
                    if stripped.startswith("#"):
                        break
                    description = stripped
                    break

            if description == "(no description)":
                logger.warning(
                    "Coach skill '%s' has no '## When to use this skill' section — index entry will be generic",
                    file.stem,
                )

            descriptions[file.stem] = description

        self._index_text = "\n".join(
            f"- {name} \u2014 {descriptions[name]}"
            for name in sorted(self._skills.keys())
        )

        logger.info(
            "Loaded %d coach skills: %s",
            len(self._skills),
            sorted(self._skills.keys()),
        )

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"coach_skills"``.
        """
        return "coach_skills"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of the domain expertise document retrieval capability.
        """
        return (
            "Expert health and fitness reference skills. Use get_skill to load "
            "domain knowledge before answering specialist questions."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the get_skill tool definition.

        Returns:
            A one-element list containing the get_skill tool definition.
        """
        return [
            ToolDefinition(
                name="get_coach_skill",
                description=(
                    "Load a domain expertise document before answering a specialist health or fitness question. "
                    "Only call this when the question genuinely requires expert knowledge beyond general coaching."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "The skill name to load. Must be one of the names listed in Available Expertise.",
                        }
                    },
                    "required": ["name"],
                },
            )
        ]

    # ------------------------------------------------------------------
    # Tool execution
    # ------------------------------------------------------------------

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Dispatch a tool call to the appropriate handler.

        Args:
            tool_name: Must be ``get_skill``.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: The authenticated user making the request (unused —
                skills are not user-scoped).

        Returns:
            A ``ToolResult`` with the skill content or an error message.
        """
        if tool_name == "get_coach_skill":
            name: str = params.get("name", "")
            content = self._skills.get(name)
            if content is not None:
                MAX_SKILL_BYTES = 6144
                if len(content.encode("utf-8")) > MAX_SKILL_BYTES:
                    content = content.encode("utf-8")[:MAX_SKILL_BYTES].decode("utf-8", errors="ignore")
                    content += "\n\n[Skill document truncated to fit context window.]"
                return ToolResult(success=True, data={"skill": content, "name": name})
            return ToolResult(
                success=False,
                error=f"Unknown skill '{name}'. Available: {sorted(self._skills.keys())}",
            )
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    # ------------------------------------------------------------------
    # Index
    # ------------------------------------------------------------------

    def get_index_text(self) -> str:
        """Return a formatted list of all available skills with one-liners.

        The index is built at construction time from the
        ``## When to use this skill`` section of each skill file.

        Returns:
            A newline-joined string of lines in the format
            ``"- {name} — {description}"``, sorted alphabetically.
        """
        return self._index_text

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        The coach skill server has no readable resources — skills are
        accessed exclusively through the get_skill tool.

        Args:
            user_id: The authenticated user (unused).

        Returns:
            An empty list.
        """
        return []
