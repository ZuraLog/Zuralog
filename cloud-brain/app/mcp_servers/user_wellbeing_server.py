"""
Zuralog Cloud Brain — User Wellbeing MCP Server.

Groups journal entries, supplements, and insight cards into a single
always-on server. No OAuth is required — all data is read from and
written to the database directly via SQLAlchemy.

This server exposes two journal tools (read-only), three supplement
tools (read/write), and one insight tool (read-only) to the LLM agent.
The AI must never write journal entries or dismiss insight cards.
"""

from __future__ import annotations

import uuid
from collections.abc import Callable
from datetime import date
from typing import Any

from sqlalchemy import select

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.models.insight import Insight
from app.models.journal_entry import JournalEntry
from app.models.user_supplement import UserSupplement


class UserWellbeingServer(BaseMCPServer):
    """MCP server for journal entries, supplements, and insight cards.

    Exposes six tools to the LLM agent:

    Journal (read-only — the AI must never write to the journal):
    - ``get_journal_entries``: Fetch entries within a date range.

    Supplements (read/write):
    - ``get_supplements``: List all active supplements.
    - ``add_supplement``: Add a new supplement.
    - ``remove_supplement``: Soft-delete a supplement (sets ``is_active=False``).

    Insights (read-only — the AI must never dismiss insight cards):
    - ``get_insights``: Return current non-dismissed insight cards.

    Args:
        db_factory: A callable that returns an async context manager
            yielding an ``AsyncSession`` (e.g. ``async_session`` from
            ``app.database``).
    """

    def __init__(self, db_factory: Callable[[], Any]) -> None:
        """Initialise the server with a database session factory.

        Args:
            db_factory: Callable returning an async context manager that
                yields an ``AsyncSession``.
        """
        self._db_factory = db_factory

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"user_wellbeing"``.
        """
        return "user_wellbeing"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of journal, supplement, and insight capabilities.
        """
        return (
            "Read the user's personal journal entries (read-only), manage their supplement "
            "stack (add or remove supplements), and surface AI-generated insight cards. "
            "This server requires no external service connection — all data lives in the "
            "Zuralog database."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the journal, supplement, and insight tools the LLM may invoke.

        Returns:
            A list of five ``ToolDefinition`` models.
        """
        return [
            # ── Journal (read-only) ────────────────────────────────────
            ToolDefinition(
                name="get_journal_entries",
                description=(
                    "Return journal entries the user wrote within a date range. "
                    "This tool is read-only — the AI must never create or modify journal entries."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "start_date": {
                            "type": "string",
                            "description": "Start of the date range in YYYY-MM-DD format (inclusive).",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "End of the date range in YYYY-MM-DD format (inclusive).",
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Maximum number of entries to return (default 10, max 30).",
                            "default": 10,
                        },
                    },
                    "required": ["start_date", "end_date"],
                },
            ),
            # ── Supplements ────────────────────────────────────────────
            ToolDefinition(
                name="get_supplements",
                description="Return the user's full list of active supplements ordered by sort position.",
                input_schema={
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            ),
            ToolDefinition(
                name="add_supplement",
                description="Add a new supplement to the user's stack.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Supplement name (max 200 characters, e.g. 'Vitamin D3').",
                        },
                        "dose": {
                            "type": "string",
                            "description": "Optional dose amount and unit (max 100 characters, e.g. '2000 IU').",
                        },
                        "timing": {
                            "type": "string",
                            "description": "Optional timing note (max 50 characters, e.g. 'With breakfast').",
                        },
                    },
                    "required": ["name"],
                },
            ),
            ToolDefinition(
                name="remove_supplement",
                description=(
                    "Remove a supplement from the user's stack. "
                    "This performs a soft delete — the record is kept but hidden."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "supplement_id": {
                            "type": "string",
                            "description": "UUID of the supplement to remove.",
                        },
                    },
                    "required": ["supplement_id"],
                },
            ),
            # ── Insights (read-only) ───────────────────────────────────
            ToolDefinition(
                name="get_insights",
                description=(
                    "Return the user's current AI-generated insight cards, ordered by priority. "
                    "This tool is read-only — the AI must never dismiss insight cards."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "limit": {
                            "type": "integer",
                            "description": "Maximum number of insights to return (default 5, max 20).",
                            "default": 5,
                        },
                    },
                    "required": [],
                },
            ),
        ]

    # ------------------------------------------------------------------
    # Tool execution dispatcher
    # ------------------------------------------------------------------

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a named tool on behalf of the authenticated user.

        Args:
            tool_name: One of the tools returned by ``get_tools()``.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: The authenticated user requesting the action.

        Returns:
            A ``ToolResult`` indicating success or failure.
        """
        if tool_name == "get_journal_entries":
            return await self._get_journal_entries(user_id, params)
        if tool_name == "get_supplements":
            return await self._get_supplements(user_id)
        if tool_name == "add_supplement":
            return await self._add_supplement(user_id, params)
        if tool_name == "remove_supplement":
            return await self._remove_supplement(user_id, params)
        if tool_name == "get_insights":
            return await self._get_insights(user_id, params)

        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    # ------------------------------------------------------------------
    # Journal tool implementation
    # ------------------------------------------------------------------

    async def _get_journal_entries(self, user_id: str, params: dict) -> ToolResult:
        """Fetch journal entries within a date range for the user.

        The ``limit`` parameter is clamped between 1 and 30 to prevent
        excessively large result sets. Results are ordered newest-first.

        Args:
            user_id: The authenticated user.
            params: Must contain ``start_date`` and ``end_date`` in
                YYYY-MM-DD format. Optionally ``limit`` (default 10).

        Returns:
            ``ToolResult`` containing a list of entry dicts with ``date``,
            ``content``, and ``tags`` fields, or an error if required
            parameters are missing.
        """
        start_date = params.get("start_date")
        end_date = params.get("end_date")

        if not start_date:
            return ToolResult(success=False, error="start_date is required (YYYY-MM-DD).")
        if not end_date:
            return ToolResult(success=False, error="end_date is required (YYYY-MM-DD).")

        try:
            start_date = date.fromisoformat(str(start_date)).isoformat()
            end_date = date.fromisoformat(str(end_date)).isoformat()
        except ValueError:
            return ToolResult(
                success=False,
                error="start_date and end_date must be in YYYY-MM-DD format.",
            )

        limit = int(params.get("limit", 10))
        limit = max(1, min(limit, 30))

        async with self._db_factory() as db:
            result = await db.execute(
                select(JournalEntry)
                .where(
                    JournalEntry.user_id == user_id,
                    JournalEntry.date >= start_date,
                    JournalEntry.date <= end_date,
                )
                .order_by(JournalEntry.date.desc())
                .limit(limit)
            )
            entries = result.scalars().all()

        return ToolResult(
            success=True,
            data=[
                {
                    "date": entry.date,
                    "content": entry.notes,
                    "tags": entry.tags,
                }
                for entry in entries
            ],
        )

    # ------------------------------------------------------------------
    # Supplement tool implementations
    # ------------------------------------------------------------------

    async def _get_supplements(self, user_id: str) -> ToolResult:
        """Fetch all active supplements for the user ordered by sort position.

        Args:
            user_id: The authenticated user.

        Returns:
            ``ToolResult`` containing a list of supplement dicts with
            ``id``, ``name``, ``dose``, and ``timing`` fields.
        """
        async with self._db_factory() as db:
            result = await db.execute(
                select(UserSupplement)
                .where(
                    UserSupplement.user_id == user_id,
                    UserSupplement.is_active.is_(True),
                )
                .order_by(UserSupplement.sort_order.asc())
            )
            supplements = result.scalars().all()

        return ToolResult(
            success=True,
            data=[
                {
                    "id": s.id,
                    "name": s.name,
                    "dose": s.dose,
                    "timing": s.timing,
                }
                for s in supplements
            ],
        )

    async def _add_supplement(self, user_id: str, params: dict) -> ToolResult:
        """Add a new supplement to the user's stack.

        Validates all inputs before writing to the database. The new
        supplement is placed at ``sort_order=0`` so it appears first
        in display lists until the user reorders it.

        Args:
            user_id: The authenticated user.
            params: Tool call parameters (see ``add_supplement`` schema).

        Returns:
            ``ToolResult`` containing the created supplement's ``id`` and
            fields, or a descriptive error on validation failure.
        """
        name = (params.get("name") or "").strip()
        dose_raw = params.get("dose")
        timing_raw = params.get("timing")
        dose = (dose_raw or "").strip() if dose_raw is not None else None
        timing = (timing_raw or "").strip() if timing_raw is not None else None

        # ── Input validation ──────────────────────────────────────────
        if not name:
            return ToolResult(success=False, error="Supplement name must not be empty.")
        if len(name) > 200:
            return ToolResult(success=False, error="Supplement name must be 200 characters or fewer.")
        if dose and len(dose) > 100:
            return ToolResult(success=False, error="Dose must be 100 characters or fewer.")
        if timing and len(timing) > 50:
            return ToolResult(success=False, error="Timing must be 50 characters or fewer.")

        supplement = UserSupplement(
            id=str(uuid.uuid4()),
            user_id=user_id,
            name=name,
            dose=dose or None,
            timing=timing or None,
            sort_order=0,
            is_active=True,
        )

        async with self._db_factory() as db:
            db.add(supplement)
            await db.commit()
            await db.refresh(supplement)

        return ToolResult(
            success=True,
            data={
                "id": supplement.id,
                "name": supplement.name,
                "dose": supplement.dose,
                "timing": supplement.timing,
            },
        )

    async def _remove_supplement(self, user_id: str, params: dict) -> ToolResult:
        """Soft-delete an active supplement by setting ``is_active=False``.

        Ownership is verified by filtering on both ``id`` and ``user_id``
        so one user cannot remove another user's supplements.

        Args:
            user_id: The authenticated user.
            params: Must contain ``supplement_id``.

        Returns:
            ``ToolResult`` with a success message, or an error if the
            supplement was not found.
        """
        supplement_id = params.get("supplement_id", "")

        async with self._db_factory() as db:
            result = await db.execute(
                select(UserSupplement).where(
                    UserSupplement.id == supplement_id,
                    UserSupplement.user_id == user_id,
                    UserSupplement.is_active.is_(True),
                )
            )
            supplement = result.scalar_one_or_none()

            if supplement is None:
                return ToolResult(success=False, error="Supplement not found.")

            supplement.is_active = False
            await db.commit()

        return ToolResult(success=True, data={"message": "Supplement removed successfully."})

    # ------------------------------------------------------------------
    # Insight tool implementation
    # ------------------------------------------------------------------

    async def _get_insights(self, user_id: str, params: dict) -> ToolResult:
        """Fetch non-dismissed insight cards for the user ordered by priority.

        Priority 1 is highest urgency; cards are returned lowest number
        first. Within the same priority level, newer cards appear first.
        The ``limit`` parameter is clamped between 1 and 20.

        Args:
            user_id: The authenticated user.
            params: Optionally contains ``limit`` (default 5).

        Returns:
            ``ToolResult`` containing a list of insight dicts with ``id``,
            ``type``, ``title``, ``summary``, and ``generated_date`` fields.
        """
        limit = int(params.get("limit", 5))
        limit = max(1, min(limit, 20))

        async with self._db_factory() as db:
            result = await db.execute(
                select(Insight)
                .where(
                    Insight.user_id == user_id,
                    Insight.dismissed_at.is_(None),
                )
                .order_by(Insight.priority.asc(), Insight.created_at.desc())
                .limit(limit)
            )
            insights = result.scalars().all()

        return ToolResult(
            success=True,
            data=[
                {
                    "id": insight.id,
                    "type": insight.type,
                    "title": insight.title,
                    "summary": insight.body,
                    "generated_date": (
                        insight.created_at.strftime("%Y-%m-%d")
                        if hasattr(insight.created_at, "strftime")
                        else str(insight.created_at)[:10]
                    ),
                }
                for insight in insights
            ],
        )

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return a description of resources available for the LLM's context.

        Args:
            user_id: The authenticated user (unused — resources are
                user-agnostic descriptors).

        Returns:
            A list of ``Resource`` models describing journal entries,
            supplements, and insight cards.
        """
        return [
            Resource(
                uri="user_wellbeing://journal/recent",
                name="Journal Entries",
                description=(
                    "The user's personal journal entries. "
                    "Read-only — the AI must never create or modify entries."
                ),
            ),
            Resource(
                uri="user_wellbeing://supplements/active",
                name="Active Supplements",
                description="The user's current supplement stack with dose and timing notes.",
            ),
            Resource(
                uri="user_wellbeing://insights/current",
                name="Insight Cards",
                description=(
                    "AI-generated insight cards ranked by priority. "
                    "Read-only — the AI must never dismiss cards on the user's behalf."
                ),
            ),
        ]
