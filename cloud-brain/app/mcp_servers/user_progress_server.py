"""
Zuralog Cloud Brain — User Progress MCP Server.

Groups goals, streaks, and achievements into a single always-on server.
No OAuth is required — all data is read from and written to the database
directly via SQLAlchemy.

This server exposes five goal tools (CRUD + complete), one streak tool,
and one achievement tool to the LLM agent.
"""

from __future__ import annotations

import uuid
from collections.abc import Callable
from datetime import date
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.models.user_goal import GoalPeriod, UserGoal
from app.models.user_streak import UserStreak
from app.services.achievement_tracker import AchievementTracker

# ---------------------------------------------------------------------------
# Validation constants
# ---------------------------------------------------------------------------

_VALID_GOAL_TYPES: frozenset[str] = frozenset(
    {
        "weight_target",
        "weekly_run_count",
        "daily_calorie_limit",
        "sleep_duration",
        "step_count",
        "water_intake",
        "custom",
    }
)

_VALID_PERIODS: frozenset[str] = frozenset({"daily", "weekly", "long_term"})


class UserProgressServer(BaseMCPServer):
    """MCP server for user goals, streaks, and achievements.

    Exposes seven tools to the LLM agent:

    Goals (read/write):
    - ``get_goals``: List all active goals.
    - ``create_goal``: Create a new goal.
    - ``update_goal``: Update title, target, unit, or deadline.
    - ``complete_goal``: Mark a goal as completed.
    - ``delete_goal``: Soft-delete a goal (sets ``is_active=False``).

    Streaks (read-only):
    - ``get_streaks``: List all streak counters.

    Achievements (read-only):
    - ``get_achievements``: List all achievements with locked/unlocked state.

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
            The string ``"user_progress"``.
        """
        return "user_progress"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of goals, streaks, and achievement capabilities.
        """
        return (
            "Manage the user's health and fitness goals (create, update, complete, delete), "
            "read their activity streaks (engagement, steps, workouts, check-in), "
            "and browse their achievement progress. "
            "This server requires no external service connection — all data lives in the Zuralog database."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the goal, streak, and achievement tools the LLM may invoke.

        Returns:
            A list of seven ``ToolDefinition`` models.
        """
        return [
            # ── Goals ──────────────────────────────────────────────────
            ToolDefinition(
                name="get_goals",
                description="Return all active health and fitness goals for the user.",
                input_schema={
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            ),
            ToolDefinition(
                name="create_goal",
                description=(
                    "Create a new health or fitness goal for the user. "
                    "Each goal type can only have one active entry at a time."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": sorted(_VALID_GOAL_TYPES),
                            "description": "Goal category (e.g. 'step_count', 'weight_target').",
                        },
                        "period": {
                            "type": "string",
                            "enum": sorted(_VALID_PERIODS),
                            "description": "How often the goal resets: 'daily', 'weekly', or 'long_term'.",
                        },
                        "title": {
                            "type": "string",
                            "description": "Short user-facing title for the goal (max 200 characters).",
                        },
                        "target_value": {
                            "type": "number",
                            "description": "The numeric target the user wants to reach (must be > 0).",
                        },
                        "unit": {
                            "type": "string",
                            "description": "Measurement unit label (e.g. 'steps', 'kg', 'hrs'). Defaults to empty string.",
                        },
                        "deadline": {
                            "type": "string",
                            "description": "Optional deadline date in YYYY-MM-DD format.",
                        },
                    },
                    "required": ["type", "period", "title", "target_value"],
                },
            ),
            ToolDefinition(
                name="update_goal",
                description=(
                    "Update one or more fields on an existing active goal. "
                    "Only the fields you supply are changed; omitted fields are left as-is. "
                    "Pass deadline as null (or the string 'null') to clear it."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "goal_id": {
                            "type": "string",
                            "description": "UUID of the goal to update.",
                        },
                        "title": {
                            "type": "string",
                            "description": "New title for the goal.",
                        },
                        "target_value": {
                            "type": "number",
                            "description": "New target value (must be > 0).",
                        },
                        "unit": {
                            "type": "string",
                            "description": "New measurement unit label.",
                        },
                        "deadline": {
                            "type": ["string", "null"],
                            "description": "New deadline in YYYY-MM-DD format, or null to clear it.",
                        },
                    },
                    "required": ["goal_id"],
                },
            ),
            ToolDefinition(
                name="complete_goal",
                description="Mark an active goal as completed.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "goal_id": {
                            "type": "string",
                            "description": "UUID of the goal to mark as completed.",
                        },
                    },
                    "required": ["goal_id"],
                },
            ),
            ToolDefinition(
                name="delete_goal",
                description="Remove an active goal (soft delete — the record is kept but hidden).",
                input_schema={
                    "type": "object",
                    "properties": {
                        "goal_id": {
                            "type": "string",
                            "description": "UUID of the goal to delete.",
                        },
                    },
                    "required": ["goal_id"],
                },
            ),
            # ── Streaks ────────────────────────────────────────────────
            ToolDefinition(
                name="get_streaks",
                description="Return all streak counters for the user (engagement, steps, workouts, check-in).",
                input_schema={
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            ),
            # ── Achievements ───────────────────────────────────────────
            ToolDefinition(
                name="get_achievements",
                description=(
                    "Return all achievements with their locked or unlocked status. "
                    "Locked achievements show what the user still needs to earn."
                ),
                input_schema={
                    "type": "object",
                    "properties": {},
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
        if tool_name == "get_goals":
            return await self._get_goals(user_id)
        if tool_name == "create_goal":
            return await self._create_goal(user_id, params)
        if tool_name == "update_goal":
            return await self._update_goal(user_id, params)
        if tool_name == "complete_goal":
            return await self._complete_goal(user_id, params)
        if tool_name == "delete_goal":
            return await self._delete_goal(user_id, params)
        if tool_name == "get_streaks":
            return await self._get_streaks(user_id)
        if tool_name == "get_achievements":
            return await self._get_achievements(user_id)

        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    # ------------------------------------------------------------------
    # Goal tool implementations
    # ------------------------------------------------------------------

    async def _get_goals(self, user_id: str) -> ToolResult:
        """Fetch all active goals for the user.

        Args:
            user_id: The authenticated user.

        Returns:
            ``ToolResult`` containing a list of goal dicts.
        """
        async with self._db_factory() as db:
            result = await db.execute(
                select(UserGoal).where(
                    UserGoal.user_id == user_id,
                    UserGoal.is_active.is_(True),
                )
            )
            goals = result.scalars().all()

        return ToolResult(
            success=True,
            data=[_serialize_goal(g) for g in goals],
        )

    async def _create_goal(self, user_id: str, params: dict) -> ToolResult:
        """Create a new goal for the user.

        Validates all inputs before writing to the database. The
        ``metric`` column is set to the same value as ``type`` so both
        the analytics engine and the Flutter client agree on the key.

        Args:
            user_id: The authenticated user.
            params: Tool call parameters (see ``create_goal`` schema).

        Returns:
            ``ToolResult`` containing the created goal's id and fields,
            or a descriptive error on validation / constraint failure.
        """
        goal_type = params.get("type", "")
        period = params.get("period", "")
        title = (params.get("title") or "").strip()
        target_value = params.get("target_value")
        unit = (params.get("unit") or "").strip()
        deadline_str: str | None = params.get("deadline")

        # ── Input validation ──────────────────────────────────────────
        if goal_type not in _VALID_GOAL_TYPES:
            return ToolResult(
                success=False,
                error=f"Invalid goal type '{goal_type}'. Must be one of: {', '.join(sorted(_VALID_GOAL_TYPES))}.",
            )
        if period not in _VALID_PERIODS:
            return ToolResult(
                success=False,
                error=f"Invalid period '{period}'. Must be one of: {', '.join(sorted(_VALID_PERIODS))}.",
            )
        if not title:
            return ToolResult(success=False, error="Title must not be empty.")
        if len(title) > 200:
            return ToolResult(success=False, error="Title must be 200 characters or fewer.")
        if len(unit) > 50:
            return ToolResult(success=False, error="Unit must be 50 characters or fewer.")
        if target_value is None or float(target_value) <= 0:
            return ToolResult(success=False, error="target_value must be greater than 0.")

        deadline: date | None = None
        if deadline_str:
            try:
                deadline = date.fromisoformat(deadline_str)
            except ValueError:
                return ToolResult(
                    success=False,
                    error=f"deadline must be in YYYY-MM-DD format, got '{deadline_str}'.",
                )

        goal = UserGoal(
            id=str(uuid.uuid4()),
            user_id=user_id,
            type=goal_type,
            metric=goal_type,
            period=GoalPeriod(period),
            title=title,
            target_value=float(target_value),
            current_value=0.0,
            unit=unit,
            deadline=deadline,
            is_active=True,
            is_completed=False,
        )

        async with self._db_factory() as db:
            db.add(goal)
            try:
                await db.commit()
                await db.refresh(goal)
            except IntegrityError:
                await db.rollback()
                return ToolResult(
                    success=False,
                    error="A goal for this type already exists.",
                )

        return ToolResult(success=True, data=_serialize_goal(goal))

    async def _update_goal(self, user_id: str, params: dict) -> ToolResult:
        """Update fields on an existing active goal.

        Only fields explicitly supplied in ``params`` are changed.
        Passing ``deadline`` as ``None`` or the string ``"null"`` clears
        the deadline.

        Args:
            user_id: The authenticated user.
            params: Must contain ``goal_id``; optionally ``title``,
                ``target_value``, ``unit``, ``deadline``.

        Returns:
            ``ToolResult`` containing the updated goal fields, or an
            error if the goal was not found.
        """
        goal_id = params.get("goal_id", "")

        async with self._db_factory() as db:
            result = await db.execute(
                select(UserGoal).where(
                    UserGoal.id == goal_id,
                    UserGoal.user_id == user_id,
                    UserGoal.is_active.is_(True),
                )
            )
            goal = result.scalar_one_or_none()

            if goal is None:
                return ToolResult(success=False, error="Goal not found.")

            if "title" in params:
                new_title = (params["title"] or "").strip()
                if not new_title:
                    return ToolResult(success=False, error="Title must not be empty.")
                if len(new_title) > 200:
                    return ToolResult(success=False, error="Title must be 200 characters or fewer.")
                goal.title = new_title

            if "target_value" in params:
                new_target = float(params["target_value"])
                if new_target <= 0:
                    return ToolResult(success=False, error="target_value must be greater than 0.")
                goal.target_value = new_target

            if "unit" in params:
                new_unit = (params["unit"] or "").strip()
                if len(new_unit) > 50:
                    return ToolResult(success=False, error="Unit must be 50 characters or fewer.")
                goal.unit = new_unit

            if "deadline" in params:
                raw = params["deadline"]
                if raw is None or str(raw).lower() == "null":
                    goal.deadline = None
                else:
                    try:
                        goal.deadline = date.fromisoformat(str(raw))
                    except ValueError:
                        return ToolResult(
                            success=False,
                            error=f"deadline must be in YYYY-MM-DD format, got '{raw}'.",
                        )

            await db.commit()
            await db.refresh(goal)

        return ToolResult(success=True, data=_serialize_goal(goal))

    async def _complete_goal(self, user_id: str, params: dict) -> ToolResult:
        """Mark an active goal as completed.

        Args:
            user_id: The authenticated user.
            params: Must contain ``goal_id``.

        Returns:
            ``ToolResult`` with ``goal_id`` on success, or an error if
            the goal was not found.
        """
        goal_id = params.get("goal_id", "")

        async with self._db_factory() as db:
            result = await db.execute(
                select(UserGoal).where(
                    UserGoal.id == goal_id,
                    UserGoal.user_id == user_id,
                    UserGoal.is_active.is_(True),
                )
            )
            goal = result.scalar_one_or_none()

            if goal is None:
                return ToolResult(success=False, error="Goal not found.")

            goal.is_completed = True
            await db.commit()

        return ToolResult(success=True, data={"goal_id": goal_id})

    async def _delete_goal(self, user_id: str, params: dict) -> ToolResult:
        """Soft-delete an active goal by setting ``is_active=False``.

        Args:
            user_id: The authenticated user.
            params: Must contain ``goal_id``.

        Returns:
            ``ToolResult`` with a success message, or an error if the
            goal was not found.
        """
        goal_id = params.get("goal_id", "")

        async with self._db_factory() as db:
            result = await db.execute(
                select(UserGoal).where(
                    UserGoal.id == goal_id,
                    UserGoal.user_id == user_id,
                    UserGoal.is_active.is_(True),
                )
            )
            goal = result.scalar_one_or_none()

            if goal is None:
                return ToolResult(success=False, error="Goal not found.")

            goal.is_active = False
            await db.commit()

        return ToolResult(success=True, data={"message": "Goal deleted successfully."})

    # ------------------------------------------------------------------
    # Streak tool implementation
    # ------------------------------------------------------------------

    async def _get_streaks(self, user_id: str) -> ToolResult:
        """Fetch all streak counters for the user.

        The ``freeze_count`` column is surfaced as ``freeze_tokens_available``
        to make its meaning clearer to the LLM.

        Args:
            user_id: The authenticated user.

        Returns:
            ``ToolResult`` containing a list of streak dicts.
        """
        async with self._db_factory() as db:
            result = await db.execute(
                select(UserStreak).where(UserStreak.user_id == user_id)
            )
            streaks = result.scalars().all()

        return ToolResult(
            success=True,
            data=[
                {
                    "streak_type": s.streak_type,
                    "current_count": s.current_count,
                    "longest_count": s.longest_count,
                    "last_activity_date": s.last_activity_date,
                    "freeze_tokens_available": s.freeze_count,
                }
                for s in streaks
            ],
        )

    # ------------------------------------------------------------------
    # Achievement tool implementation
    # ------------------------------------------------------------------

    async def _get_achievements(self, user_id: str) -> ToolResult:
        """Fetch all achievements with their locked/unlocked state.

        Delegates to ``AchievementTracker.get_all()`` which merges the
        static registry with the user's database rows.

        Args:
            user_id: The authenticated user.

        Returns:
            ``ToolResult`` containing the full achievement list from the
            tracker (key, name, description, category, unlocked_at,
            is_unlocked).
        """
        tracker = AchievementTracker()
        async with self._db_factory() as db:
            achievements = await tracker.get_all(user_id, db)

        return ToolResult(success=True, data=achievements)

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return a description of resources available for the LLM's context.

        Args:
            user_id: The authenticated user (unused — resources are
                user-agnostic descriptors).

        Returns:
            A list of ``Resource`` models describing goals, streaks,
            and achievements.
        """
        return [
            Resource(
                uri="user_progress://goals/active",
                name="Active Goals",
                description="The user's current active health and fitness goals with progress values.",
            ),
            Resource(
                uri="user_progress://streaks/all",
                name="Activity Streaks",
                description="The user's consecutive-day streaks for engagement, steps, workouts, and check-ins.",
            ),
            Resource(
                uri="user_progress://achievements/all",
                name="Achievements",
                description="All achievement definitions and their locked or unlocked status for this user.",
            ),
        ]


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _serialize_goal(goal: UserGoal) -> dict[str, Any]:
    """Serialize a ``UserGoal`` ORM instance to a plain dict.

    Converts the ``deadline`` date to an ISO-8601 string when present so
    the result is JSON-serialisable without further processing.

    Args:
        goal: The ORM instance to serialize.

    Returns:
        A dict containing the fields the LLM and clients care about.
    """
    return {
        "id": goal.id,
        "title": goal.title,
        "type": goal.type,
        "period": goal.period.value if isinstance(goal.period, GoalPeriod) else goal.period,
        "target_value": goal.target_value,
        "current_value": goal.current_value,
        "unit": goal.unit,
        "deadline": goal.deadline.isoformat() if goal.deadline is not None else None,
        "is_completed": goal.is_completed,
    }
