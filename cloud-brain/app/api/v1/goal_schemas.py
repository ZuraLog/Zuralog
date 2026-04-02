"""
Zuralog Cloud Brain — Goal Pydantic Schemas.

Request/response schemas for the Goals CRUD API.  Field names use
snake_case to match the Flutter client's ``Goal.fromJson`` contract
exactly.

Schemas:
    - GoalResponse: Single goal returned to the client.
    - GoalListResponse: Wrapped list ``{"goals": [...]}``.
    - GoalCreateRequest: Payload for creating a new goal.
    - GoalUpdateRequest: Payload for editing an existing goal.
"""

from __future__ import annotations

from datetime import date as _date
from typing import Any

from pydantic import BaseModel, ConfigDict, field_validator

VALID_TYPES: set[str] = {
    "weight_target",
    "weekly_run_count",
    "daily_calorie_limit",
    "sleep_duration",
    "step_count",
    "water_intake",
    "custom",
}

VALID_PERIODS: set[str] = {"daily", "weekly", "long_term"}


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class GoalResponse(BaseModel):
    """Single goal payload returned to the Flutter client.

    Field names match ``Goal.fromJson`` in ``progress_models.dart``.
    """

    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    type: str
    period: str
    title: str
    target_value: float
    current_value: float
    unit: str
    start_date: _date | None = None
    deadline: _date | None = None
    is_completed: bool
    ai_commentary: str | None
    progress_history: list[Any]


class GoalListResponse(BaseModel):
    """Wrapped list of goals.

    The Flutter ``GoalList.fromJson`` reads ``json['goals']``,
    so we must return ``{"goals": [...]}``.
    """

    model_config = ConfigDict(from_attributes=True)

    goals: list[GoalResponse]


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class GoalCreateRequest(BaseModel):
    """Payload for creating a new goal.

    Attributes:
        type: Goal type slug (must be one of VALID_TYPES).
        period: Time horizon slug (must be one of VALID_PERIODS).
        title: Short user-facing title (1–200 characters).
        target_value: Numeric target (must be > 0).
        unit: Optional measurement label (max 50 characters).
        deadline: Optional deadline in YYYY-MM-DD format.
    """

    type: str
    period: str
    title: str
    target_value: float
    unit: str = ""
    deadline: _date | None = None

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        if v not in VALID_TYPES:
            msg = f"type must be one of {sorted(VALID_TYPES)}"
            raise ValueError(msg)
        return v

    @field_validator("period")
    @classmethod
    def validate_period(cls, v: str) -> str:
        if v not in VALID_PERIODS:
            msg = f"period must be one of {sorted(VALID_PERIODS)}"
            raise ValueError(msg)
        return v

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("title cannot be empty")
        if len(v) > 200:
            raise ValueError("title cannot exceed 200 characters")
        return v

    @field_validator("target_value")
    @classmethod
    def validate_target(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("target_value must be greater than 0")
        return v

    @field_validator("unit")
    @classmethod
    def validate_unit(cls, v: str) -> str:
        if len(v) > 50:
            raise ValueError("unit cannot exceed 50 characters")
        return v


class GoalUpdateRequest(BaseModel):
    """Payload for editing an existing goal.

    All fields are optional — only send what changed.

    Attributes:
        title: New title (1–200 characters).
        target_value: New numeric target (must be > 0).
        unit: New measurement label (max 50 characters).
        deadline: New deadline in YYYY-MM-DD format, or None to clear.
    """

    title: str | None = None
    target_value: float | None = None
    unit: str | None = None
    deadline: _date | None = None
    period: str | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if not v:
                raise ValueError("title cannot be empty")
            if len(v) > 200:
                raise ValueError("title cannot exceed 200 characters")
        return v

    @field_validator("target_value")
    @classmethod
    def validate_target(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("target_value must be greater than 0")
        return v

    @field_validator("unit")
    @classmethod
    def validate_unit(cls, v: str | None) -> str | None:
        if v is not None and len(v) > 50:
            raise ValueError("unit cannot exceed 50 characters")
        return v
