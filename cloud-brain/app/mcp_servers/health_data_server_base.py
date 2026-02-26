"""Shared base class for health-platform MCP servers.

Both ``AppleHealthServer`` and ``HealthConnectServer`` query the *same*
PostgreSQL schema and expose the *same* tool shapes — only the
``source_name`` filter and a handful of labels differ.

This module extracts all shared DB-query logic into
``HealthDataServerBase`` so that concrete subclasses remain thin
(≤ 80 lines each) and contain only what is truly platform-specific:
``name``, ``description``, ``source_name``, ``platform``,
``_read_tool_name``, and ``_write_tool_name``.

Usage example::

    class AppleHealthServer(HealthDataServerBase):
        @property
        def name(self) -> str:
            return "apple_health"

        @property
        def source_name(self) -> str:
            return "apple_health"

        @property
        def platform(self) -> str:
            return "ios"
"""

from __future__ import annotations

import logging
from abc import abstractmethod

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import (
    NutritionEntry as NutritionModel,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.user_device import UserDevice

logger = logging.getLogger(__name__)


class HealthDataServerBase(BaseMCPServer):
    """Abstract base class for health-platform MCP servers.

    Holds all shared DB-query and write-dispatch logic.  Concrete
    subclasses implement the five abstract properties that drive
    platform-specific behaviour.

    Parameters
    ----------
    db_factory : async context-manager factory, optional
        Called as ``async with db_factory() as db`` to obtain an
        ``AsyncSession``.  When ``None``, read/write tools return an
        appropriate error.
    device_write_service : DeviceWriteService, optional
        Used to dispatch FCM write commands to the user's device.
        When ``None``, write tools return an appropriate error.
    """

    def __init__(
        self,
        db_factory=None,
        device_write_service=None,
    ) -> None:
        """Initialise the server with optional database and write dependencies."""
        self._db_factory = db_factory
        self._device_write_service = device_write_service

    # ------------------------------------------------------------------
    # Abstract properties that subclasses must implement
    # ------------------------------------------------------------------

    @property
    @abstractmethod
    def name(self) -> str:
        """Unique server identifier used for registry lookup."""

    @property
    @abstractmethod
    def description(self) -> str:
        """Human-readable description for LLM system prompts."""

    @property
    @abstractmethod
    def source_name(self) -> str:
        """The ``source`` column value used for DB filtering.

        For Apple Health this is ``"apple_health"``; for Health Connect
        this is ``"health_connect"``.
        """

    @property
    @abstractmethod
    def platform(self) -> str:
        """Device platform used when looking up FCM tokens.

        Must be ``"ios"`` or ``"android"``.
        """

    @property
    @abstractmethod
    def _read_tool_name(self) -> str:
        """The MCP tool name for read operations.

        E.g. ``"apple_health_read_metrics"`` or
        ``"health_connect_read_metrics"``.
        """

    @property
    @abstractmethod
    def _write_tool_name(self) -> str:
        """The MCP tool name for write operations.

        E.g. ``"apple_health_write_entry"`` or
        ``"health_connect_write_entry"``.
        """

    # ------------------------------------------------------------------
    # BaseMCPServer interface
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return read and write tool schemas for this platform.

        Returns two tools:
        - ``{platform}_read_metrics``: Read health data from the database.
        - ``{platform}_write_entry``: Write health data via FCM to the device.
        """
        return [
            ToolDefinition(
                name=self._read_tool_name,
                description=(
                    f"Read health metrics from the Cloud Brain database "
                    f"(populated from {self.description.split('.')[0]}). "
                    "Use 'daily_summary' for general health questions. "
                    "Use specific types (steps, workouts, sleep) for targeted questions. "
                    "Always use today's date as end_date and an appropriate lookback for start_date."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "data_type": {
                            "type": "string",
                            "enum": [
                                "steps",
                                "calories",
                                "workouts",
                                "sleep",
                                "weight",
                                "nutrition",
                                "resting_heart_rate",
                                "hrv",
                                "vo2_max",
                                "daily_summary",
                                # Phase 6 new types
                                "body_fat",
                                "respiratory_rate",
                                "oxygen_saturation",
                                "heart_rate",
                                "distance",
                                "flights_climbed",
                            ],
                            "description": (
                                "The health metric type to query. "
                                "'daily_summary' returns all scalar metrics (steps, calories, HR, HRV, "
                                "VO2 max, body fat, respiratory rate, SpO2) for the date range in one call."
                            ),
                        },
                        "start_date": {
                            "type": "string",
                            "description": "Start date in ISO 8601 format (e.g., 2026-02-20).",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "End date in ISO 8601 format (e.g., 2026-02-26).",
                        },
                    },
                    "required": ["data_type", "start_date", "end_date"],
                },
            ),
            ToolDefinition(
                name=self._write_tool_name,
                description=(
                    f"Write health data to the user's {self.platform.upper()} device "
                    "via an FCM push notification. Supports: nutrition (calories), workout, weight."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "data_type": {
                            "type": "string",
                            "enum": ["nutrition", "workout", "weight"],
                            "description": "The type of health entry to write.",
                        },
                        "value": {
                            "type": "number",
                            "description": (
                                "The value to write. "
                                "For nutrition: calories (kcal). "
                                "For weight: kilograms. "
                                "For workout: energy burned (kcal)."
                            ),
                        },
                        "date": {
                            "type": "string",
                            "description": "Date/time in ISO 8601 format.",
                        },
                        "metadata": {
                            "type": "object",
                            "description": (
                                'Additional data. For workouts: {"activity_type": "running", "duration_seconds": 1800}'
                            ),
                        },
                    },
                    "required": ["data_type", "value", "date"],
                },
            ),
        ]

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a health tool.

        Routes read tools to the PostgreSQL database and write tools to
        the DeviceWriteService (FCM).

        Parameters
        ----------
        tool_name : str
            Must match ``_read_tool_name`` or ``_write_tool_name``.
        params : dict
            Tool-specific parameters matching the input_schema.
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Success with queried data, or failure with an error message.
        """
        if tool_name == self._read_tool_name:
            return await self._read_metrics(params, user_id)
        if tool_name == self._write_tool_name:
            return await self._write_entry(params, user_id)
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return available data resources.

        Currently empty — resources are surfaced through tool calls.
        """
        return []

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _read_metrics(self, params: dict, user_id: str) -> ToolResult:
        """Query the Cloud Brain database for health metrics.

        Parameters
        ----------
        params : dict
            Must contain ``data_type``, ``start_date``, ``end_date``.
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Data dict with ``data_type`` and ``records`` list, or error.
        """
        required = ("data_type", "start_date", "end_date")
        missing = [k for k in required if k not in params]
        if missing:
            return ToolResult(
                success=False,
                error=f"Missing required parameters: {', '.join(missing)}",
            )

        if not self._db_factory:
            return ToolResult(
                success=False,
                error="Database not configured. The server is not fully initialised.",
            )

        data_type = params["data_type"]
        start_date = params["start_date"]
        end_date = params["end_date"]

        try:
            async with self._db_factory() as db:
                return await self._dispatch_read(db, data_type, start_date, end_date, user_id)
        except Exception as exc:
            logger.exception(
                "%s read_metrics failed for user %s: %s",
                self.name,
                user_id,
                exc,
            )
            return ToolResult(success=False, error=str(exc))

    async def _dispatch_read(
        self,
        db: AsyncSession,
        data_type: str,
        start_date: str,
        end_date: str,
        user_id: str,
    ) -> ToolResult:
        """Route a read request to the appropriate DB query.

        Parameters
        ----------
        db : AsyncSession
            Active database session.
        data_type : str
            One of the supported metric types.
        start_date, end_date : str
            ISO date strings (YYYY-MM-DD).
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Query result or error.
        """
        # --- Daily scalar metrics ---
        _daily_scalar_types = (
            "steps", "calories", "resting_heart_rate", "hrv", "vo2_max", "daily_summary",
            "body_fat", "respiratory_rate", "oxygen_saturation", "heart_rate",
            "distance", "flights_climbed",
        )
        if data_type in _daily_scalar_types:
            result = await db.execute(
                select(DailyHealthMetrics)
                .where(
                    DailyHealthMetrics.user_id == user_id,
                    DailyHealthMetrics.date >= start_date,
                    DailyHealthMetrics.date <= end_date,
                )
                .order_by(DailyHealthMetrics.date)
            )
            rows = result.scalars().all()

            if data_type == "steps":
                records = [{"date": r.date, "steps": r.steps} for r in rows if r.steps is not None]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "steps",
                        "records": records,
                        "total_steps": sum(r.steps or 0 for r in rows),
                    },
                )
            if data_type == "calories":
                records = [
                    {"date": r.date, "active_calories": r.active_calories}
                    for r in rows
                    if r.active_calories is not None
                ]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "calories",
                        "records": records,
                        "total_active_calories": sum(r.active_calories or 0 for r in rows),
                    },
                )
            if data_type == "resting_heart_rate":
                records = [
                    {"date": r.date, "resting_heart_rate_bpm": r.resting_heart_rate}
                    for r in rows
                    if r.resting_heart_rate is not None
                ]
                return ToolResult(success=True, data={"data_type": "resting_heart_rate", "records": records})
            if data_type == "hrv":
                records = [{"date": r.date, "hrv_ms": r.hrv_ms} for r in rows if r.hrv_ms is not None]
                return ToolResult(success=True, data={"data_type": "hrv", "records": records})
            if data_type == "vo2_max":
                records = [
                    {"date": r.date, "vo2_max_ml_kg_min": r.vo2_max}
                    for r in rows
                    if r.vo2_max is not None
                ]
                return ToolResult(success=True, data={"data_type": "vo2_max", "records": records})
            if data_type == "daily_summary":
                records = [
                    {
                        "date": r.date,
                        "steps": r.steps,
                        "active_calories": r.active_calories,
                        "resting_heart_rate_bpm": r.resting_heart_rate,
                        "hrv_ms": r.hrv_ms,
                        "vo2_max_ml_kg_min": r.vo2_max,
                        "distance_meters": r.distance_meters,
                        "flights_climbed": r.flights_climbed,
                        "body_fat_percentage": r.body_fat_percentage,
                        "respiratory_rate_bpm": r.respiratory_rate,
                        "oxygen_saturation_pct": r.oxygen_saturation,
                        "heart_rate_avg_bpm": r.heart_rate_avg,
                    }
                    for r in rows
                ]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "daily_summary",
                        "records": records,
                        "record_count": len(records),
                    },
                )
            if data_type == "body_fat":
                records = [
                    {"date": r.date, "body_fat_percentage": r.body_fat_percentage}
                    for r in rows
                    if r.body_fat_percentage is not None
                ]
                return ToolResult(success=True, data={"data_type": "body_fat", "records": records})
            if data_type == "respiratory_rate":
                records = [
                    {"date": r.date, "respiratory_rate_bpm": r.respiratory_rate}
                    for r in rows
                    if r.respiratory_rate is not None
                ]
                return ToolResult(success=True, data={"data_type": "respiratory_rate", "records": records})
            if data_type == "oxygen_saturation":
                records = [
                    {"date": r.date, "oxygen_saturation_pct": r.oxygen_saturation}
                    for r in rows
                    if r.oxygen_saturation is not None
                ]
                return ToolResult(success=True, data={"data_type": "oxygen_saturation", "records": records})
            if data_type == "heart_rate":
                records = [
                    {"date": r.date, "heart_rate_avg_bpm": r.heart_rate_avg}
                    for r in rows
                    if r.heart_rate_avg is not None
                ]
                return ToolResult(success=True, data={"data_type": "heart_rate", "records": records})
            if data_type == "distance":
                records = [
                    {"date": r.date, "distance_meters": r.distance_meters}
                    for r in rows
                    if r.distance_meters is not None
                ]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "distance",
                        "records": records,
                        "total_distance_meters": sum(r.distance_meters or 0.0 for r in rows),
                    },
                )
            if data_type == "flights_climbed":
                records = [
                    {"date": r.date, "flights_climbed": r.flights_climbed}
                    for r in rows
                    if r.flights_climbed is not None
                ]
                return ToolResult(
                    success=True,
                    data={
                        "data_type": "flights_climbed",
                        "records": records,
                        "total_flights": sum(r.flights_climbed or 0 for r in rows),
                    },
                )

        # --- Workouts (filtered by source_name) ---
        if data_type == "workouts":
            result = await db.execute(
                select(UnifiedActivity)
                .where(
                    UnifiedActivity.user_id == user_id,
                    UnifiedActivity.source == self.source_name,
                )
                .order_by(UnifiedActivity.start_time)
            )
            rows = result.scalars().all()
            records = [
                {
                    "activity_type": r.activity_type,
                    "duration_seconds": r.duration_seconds,
                    "distance_meters": r.distance_meters,
                    "calories": r.calories,
                    "start_time": r.start_time.isoformat() if r.start_time else None,
                }
                for r in rows
            ]
            return ToolResult(
                success=True,
                data={
                    "data_type": "workouts",
                    "records": records,
                    "count": len(records),
                },
            )

        # --- Sleep (filtered by source_name) ---
        if data_type == "sleep":
            result = await db.execute(
                select(SleepRecord)
                .where(
                    SleepRecord.user_id == user_id,
                    SleepRecord.source == self.source_name,
                    SleepRecord.date >= start_date,
                    SleepRecord.date <= end_date,
                )
                .order_by(SleepRecord.date)
            )
            rows = result.scalars().all()
            records = [{"date": r.date, "hours": r.hours, "quality_score": r.quality_score} for r in rows]
            return ToolResult(
                success=True,
                data={
                    "data_type": "sleep",
                    "records": records,
                    "avg_hours": (round(sum(r.hours for r in rows) / len(rows), 2) if rows else 0),
                },
            )

        # --- Weight (filtered by source_name) ---
        if data_type == "weight":
            result = await db.execute(
                select(WeightMeasurement)
                .where(
                    WeightMeasurement.user_id == user_id,
                    WeightMeasurement.source == self.source_name,
                    WeightMeasurement.date >= start_date,
                    WeightMeasurement.date <= end_date,
                )
                .order_by(WeightMeasurement.date)
            )
            rows = result.scalars().all()
            records = [{"date": r.date, "weight_kg": r.weight_kg} for r in rows]
            return ToolResult(
                success=True,
                data={"data_type": "weight", "records": records},
            )

        # --- Nutrition (filtered by source_name) ---
        if data_type == "nutrition":
            result = await db.execute(
                select(NutritionModel)
                .where(
                    NutritionModel.user_id == user_id,
                    NutritionModel.source == self.source_name,
                    NutritionModel.date >= start_date,
                    NutritionModel.date <= end_date,
                )
                .order_by(NutritionModel.date)
            )
            rows = result.scalars().all()
            records = [
                {
                    "date": r.date,
                    "calories": r.calories,
                    "protein_grams": r.protein_grams,
                    "carbs_grams": r.carbs_grams,
                    "fat_grams": r.fat_grams,
                }
                for r in rows
            ]
            return ToolResult(
                success=True,
                data={"data_type": "nutrition", "records": records},
            )

        return ToolResult(
            success=False,
            error=f"Unsupported data_type: '{data_type}'",
        )

    async def _write_entry(self, params: dict, user_id: str) -> ToolResult:
        """Delegate a write request to the DeviceWriteService.

        Looks up the user's most recent device token for the target
        ``platform`` and sends an FCM push via ``DeviceWriteService``.

        Parameters
        ----------
        params : dict
            Must contain ``data_type``, ``value``, ``date``.
        user_id : str
            The authenticated user's ID.

        Returns
        -------
        ToolResult
            Dispatched confirmation or error if service unavailable.
        """
        required = ("data_type", "value", "date")
        missing = [k for k in required if k not in params]
        if missing:
            return ToolResult(
                success=False,
                error=f"Missing required parameters: {', '.join(missing)}",
            )

        if not self._db_factory:
            return ToolResult(
                success=False,
                error="Database not configured. The server is not fully initialised.",
            )

        if not self._device_write_service:
            return ToolResult(
                success=False,
                error=(
                    "Write service not configured. "
                    "Device write operations are not available in this environment."
                ),
            )

        data_type = params["data_type"]
        value = params["value"]
        date = params["date"]
        metadata = params.get("metadata", {})

        # Build value dict for the device
        if data_type == "nutrition":
            value_dict: dict = {"calories": value, "date": date}
        elif data_type == "weight":
            value_dict = {"weight_kg": value, "date": date}
        elif data_type == "workout":
            value_dict = {
                "calories": value,
                "activity_type": metadata.get("activity_type", "running"),
                "duration_seconds": metadata.get("duration_seconds", 1800),
                "date": date,
            }
        else:
            value_dict = {"value": value, "date": date}

        try:
            async with self._db_factory() as db:
                # Look up user's most recent device token for this platform
                result = await db.execute(
                    select(UserDevice)
                    .where(
                        UserDevice.user_id == user_id,
                        UserDevice.platform == self.platform,
                    )
                    .order_by(UserDevice.last_seen_at.desc())
                    .limit(1)
                )
                device = result.scalar_one_or_none()

                if not device:
                    return ToolResult(
                        success=False,
                        error=(
                            f"No registered {self.platform.upper()} device found for this user. "
                            f"Cannot perform {self.name} write."
                        ),
                    )

                success = self._device_write_service.send_write_request(
                    device_token=device.fcm_token,
                    data_type=data_type,
                    value_dict=value_dict,
                )

                if not success:
                    return ToolResult(
                        success=False,
                        error="Failed to dispatch FCM write request to device.",
                    )

                logger.info(
                    "%s write_entry: dispatched %s for user %s to device %s",
                    self.name,
                    data_type,
                    user_id,
                    device.id,
                )
                return ToolResult(
                    success=True,
                    data={
                        "status": "dispatched",
                        "message": f"Write request for '{data_type}' dispatched to your {self.platform.upper()} device.",
                        "device_id": device.id,
                    },
                )
        except Exception as exc:
            logger.exception(
                "%s write_entry failed for user %s: %s",
                self.name,
                user_id,
                exc,
            )
            return ToolResult(success=False, error=str(exc))
