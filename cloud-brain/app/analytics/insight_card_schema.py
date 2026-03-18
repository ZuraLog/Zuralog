"""Pydantic schema for validating LLM-generated insight cards.

Truncates oversized fields silently rather than raising — the LLM is
unpredictable and we'd rather show a trimmed card than drop it entirely.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, field_validator


class InsightCardSchema(BaseModel):
    """Validated insight card from the LLM.

    Field limits:
        title: max 200 characters
        body: max 2000 characters
        reasoning: max 1000 characters (optional)
        priority: integer 1-10 (clamped, not rejected)
    """

    type: str
    title: str
    body: str
    priority: int
    reasoning: Optional[str] = None

    @field_validator("title")
    @classmethod
    def truncate_title(cls, v: str) -> str:
        return v[:200] if len(v) > 200 else v

    @field_validator("body")
    @classmethod
    def truncate_body(cls, v: str) -> str:
        return v[:2000] if len(v) > 2000 else v

    @field_validator("reasoning")
    @classmethod
    def truncate_reasoning(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        return v[:1000] if len(v) > 1000 else v

    @field_validator("priority")
    @classmethod
    def clamp_priority(cls, v: int) -> int:
        return max(1, min(10, v))
