"""
Zuralog Cloud Brain — Coaching Personas (re-export).

This module re-exports persona definitions from ``app.agent.prompts.system``,
which is the single source of truth. Import from here for backward
compatibility; prefer importing from ``system`` directly in new code.
"""

from __future__ import annotations

from app.agent.prompts.system import (
    PERSONAS,
    PROACTIVITY_MODIFIERS,
    build_system_prompt,
)

__all__ = ["PERSONAS", "PROACTIVITY_MODIFIERS", "build_system_prompt"]
