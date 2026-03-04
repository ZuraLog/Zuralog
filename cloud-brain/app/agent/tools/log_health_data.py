"""
Zuralog Cloud Brain — Log Health Data MCP Tool.

Implements a two-phase natural-language health logging flow:

**Phase 1 — Parse (default)**
  The LLM calls this tool with ``{"message": "<user text>"}``. The tool
  parses the message for loggable health metrics using heuristics/regex and
  returns a ``pending_confirmation`` response with structured entries and a
  human-readable confirmation prompt. The LLM relays this to the user.

**Phase 2 — Commit (after user confirms)**
  The LLM calls the tool again with ``{"message": "...", "confirmed": true}``.
  The tool writes the previously-parsed entries to the ``quick_logs`` database
  table via SQLAlchemy and returns a ``logged`` response.

This tool is NOT a FastAPI route or Celery task — it is registered with the
MCPClient and executed by the Orchestrator during the ReAct tool-call loop.

Supported metric types (from ``quick_logs`` VALID_METRIC_TYPES):
  - water   — e.g. "2 liters of water", "500ml", "8 oz of water"
  - mood    — e.g. "mood 7/10", "feeling a 6 today"
  - energy  — e.g. "energy level 8", "energy 4/10"
  - stress  — e.g. "stress 9/10", "really stressed, 8"
  - notes   — catch-all free-text when no specific metric is found
"""

from __future__ import annotations

import asyncio
import logging
import math
import re
import uuid
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Regex patterns for metric extraction
# ---------------------------------------------------------------------------

# Water: "2 liters", "500 ml", "8 oz", "1.5 l of water", "2L"
_WATER_PATTERN = re.compile(
    r"""
    (?P<value>[\d]+(?:\.\d+)?)          # numeric value (int or decimal)
    \s*                                  # optional whitespace
    (?P<unit>liters?|litres?|l\b|ml\b|milliliters?|oz\b|ounces?|cups?)
    (?:\s+(?:of\s+)?water)?             # optional "of water" suffix
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Mood: "mood 7/10", "feeling a 7", "mood: 8", "i'm a 7 today"
_MOOD_PATTERN = re.compile(
    r"""
    (?:mood|feeling|feel)\s*[:\-]?\s*   # trigger word
    (?:a\s+)?                            # optional article
    (?P<value>\d+(?:\.\d+)?)            # numeric score
    (?:/10)?                             # optional /10 denominator
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Energy: "energy 8/10", "energy level 6"
_ENERGY_PATTERN = re.compile(
    r"""
    energy(?:\s+level)?\s*[:\-]?\s*     # trigger word
    (?P<value>\d+(?:\.\d+)?)            # numeric score
    (?:/10)?                             # optional /10 denominator
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Stress: "stress 9/10", "stress level 7"
_STRESS_PATTERN = re.compile(
    r"""
    stress(?:\s+level)?\s*[:\-]?\s*     # trigger word
    (?P<value>\d+(?:\.\d+)?)            # numeric score
    (?:/10)?                             # optional /10 denominator
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Unit normalisation helpers
_LITRE_UNITS = {"liter", "litre", "liters", "litres", "l"}
_ML_UNITS = {"ml", "milliliter", "milliliters"}
_OZ_UNITS = {"oz", "ounce", "ounces"}
_CUP_UNITS = {"cup", "cups"}

_ML_PER_LITRE = 1000.0
_ML_PER_OZ = 29.5735
_ML_PER_CUP = 236.588


# ---------------------------------------------------------------------------
# Metric extraction helpers
# ---------------------------------------------------------------------------


def _extract_water(message: str) -> dict[str, Any] | None:
    """Parse a water intake mention from the message.

    Normalises the value to litres for consistency.

    Args:
        message: Raw user message text.

    Returns:
        A parsed entry dict or ``None`` if no water mention is found.
    """
    match = _WATER_PATTERN.search(message)
    if not match:
        return None

    raw_value = float(match.group("value"))
    unit = match.group("unit").lower().rstrip("s")  # normalise plural

    # Normalise to litres
    if unit in _LITRE_UNITS or unit == "l":
        value_litres = raw_value
        display_unit = "liters"
    elif unit in _ML_UNITS or unit == "ml":
        value_litres = raw_value / _ML_PER_LITRE
        display_unit = "ml"
    elif unit in _OZ_UNITS or unit == "oz":
        value_litres = (raw_value * _ML_PER_OZ) / _ML_PER_LITRE
        display_unit = "oz"
    elif unit in _CUP_UNITS:
        value_litres = (raw_value * _ML_PER_CUP) / _ML_PER_LITRE
        display_unit = "cups"
    else:
        value_litres = raw_value
        display_unit = unit

    return {
        "metric_type": "water",
        "value": round(value_litres, 3),
        "unit": "liters",
        "label": f"Water intake: {raw_value} {display_unit}",
        "_raw_value": raw_value,
        "_raw_unit": display_unit,
    }


def _extract_scale_metric(
    pattern: re.Pattern[str],
    metric_type: str,
    label_prefix: str,
    message: str,
) -> dict[str, Any] | None:
    """Parse a 1-10 scale metric (mood, energy, stress).

    Args:
        pattern: Compiled regex pattern with a ``value`` group.
        metric_type: The QuickLog metric_type string.
        label_prefix: Human-readable prefix for the confirmation label.
        message: Raw user message text.

    Returns:
        A parsed entry dict or ``None`` if the pattern does not match.
    """
    match = pattern.search(message)
    if not match:
        return None

    raw_value = float(match.group("value"))
    # Clamp to valid 1-10 range
    value = max(1.0, min(10.0, raw_value))
    return {
        "metric_type": metric_type,
        "value": value,
        "unit": "/10",
        "label": f"{label_prefix}: {value}/10",
    }


def _validate_entry(entry: dict[str, Any]) -> dict[str, Any] | None:
    """Validate and sanitise a single parsed entry before DB write.

    Rejects entries with an unknown metric_type or a non-finite value.
    Truncates ``text_value`` and ``label`` to safe lengths.

    Args:
        entry: A dict from ``_parse_entries`` or caller-supplied ``parsed_entries``.

    Returns:
        The (possibly mutated) entry if valid, or ``None`` to skip it.
    """
    # Import here to avoid circular deps — same pattern used elsewhere in the file
    from app.models.quick_log import VALID_METRIC_TYPES  # noqa: PLC0415

    metric_type = entry.get("metric_type", "")
    if metric_type not in VALID_METRIC_TYPES:
        logger.warning(
            "_validate_entry: unknown metric_type '%s' — skipping entry", metric_type
        )
        return None

    value = entry.get("value")
    if value is not None:
        try:
            value = float(value)
        except (TypeError, ValueError):
            logger.warning(
                "_validate_entry: non-numeric value '%s' for metric_type '%s' — skipping",
                value,
                metric_type,
            )
            return None
        if not math.isfinite(value):
            logger.warning(
                "_validate_entry: non-finite value %s for metric_type '%s' — skipping",
                value,
                metric_type,
            )
            return None
        # Clamp scale metrics to [1, 10]; water to [0, 100 litres]
        if metric_type in ("mood", "energy", "stress", "sleep_quality", "pain"):
            value = max(1.0, min(10.0, value))
        elif metric_type == "water":
            value = max(0.0, min(100.0, value))
        entry = dict(entry)
        entry["value"] = value

    # Truncate text fields to prevent excessively large DB writes
    if entry.get("text_value") is not None:
        entry = dict(entry)
        entry["text_value"] = str(entry["text_value"])[:2000]
    if entry.get("label") is not None:
        entry = dict(entry)
        entry["label"] = str(entry["label"])[:500]

    return entry


def _parse_entries(message: str) -> list[dict[str, Any]]:
    """Extract all loggable health entries from a natural-language message.

    Applies water, mood, energy, and stress patterns in order. If none
    match, treats the entire message as a free-text notes entry.

    Args:
        message: Raw user input text.

    Returns:
        A list of parsed entry dicts (may be empty if nothing is recognised).
    """
    entries: list[dict[str, Any]] = []

    water = _extract_water(message)
    if water:
        entries.append(water)

    mood = _extract_scale_metric(_MOOD_PATTERN, "mood", "Mood", message)
    if mood:
        entries.append(mood)

    energy = _extract_scale_metric(_ENERGY_PATTERN, "energy", "Energy", message)
    if energy:
        entries.append(energy)

    stress = _extract_scale_metric(_STRESS_PATTERN, "stress", "Stress", message)
    if stress:
        entries.append(stress)

    return entries


def _build_confirmation_message(entries: list[dict[str, Any]]) -> str:
    """Build the human-readable confirmation string shown to the user.

    Args:
        entries: Parsed metric entry dicts.

    Returns:
        A formatted string listing what will be logged.
    """
    items = ", ".join(e["label"] for e in entries)
    return f"I'll log: {items}. Confirm?"


# ---------------------------------------------------------------------------
# Tool class
# ---------------------------------------------------------------------------


class LogHealthDataTool:
    """MCP tool for parsing and logging health data from natural language.

    Implements a two-phase confirmation flow:
      1. First call (no ``confirmed`` flag): parse the message and return a
         ``pending_confirmation`` response for the user to review.
      2. Second call (``confirmed: true``): write the entries to the database
         and return a ``logged`` response.

    Attributes:
        name: MCP tool identifier.
        description: Natural-language description shown to the LLM.
        input_schema: JSON Schema for the tool's input arguments.
    """

    name = "log_health_data"

    description = (
        "Parse and log health data mentioned by the user in natural language. "
        "Use this when the user says things like 'I drank 2 liters of water', "
        "'I'm feeling a 7/10 today', 'I took ibuprofen', "
        "'Had 1800 calories for lunch', 'energy level 8', 'stress 9/10'."
    )

    input_schema: dict[str, Any] = {
        "type": "object",
        "required": ["message"],
        "properties": {
            "message": {
                "type": "string",
                "description": (
                    "The natural-language text from the user that contains "
                    "health data to log (e.g. 'I drank 2 liters of water')."
                ),
            },
            "confirmed": {
                "type": "boolean",
                "description": (
                    "Set to true on the second call (after the user confirms) "
                    "to actually write the entries to the database."
                ),
                "default": False,
            },
            "parsed_entries": {
                "type": "array",
                "description": (
                    "The entries array from the previous pending_confirmation "
                    "response. Required when confirmed=true to avoid re-parsing."
                ),
                "items": {"type": "object"},
            },
        },
    }

    async def execute(
        self,
        arguments: dict[str, Any],
        user_id: str,
        db: Any,
    ) -> dict[str, Any]:
        """Execute the tool in parse or commit mode.

        **Parse mode** (default, ``confirmed`` not set or ``False``):
          Parses ``message`` for health metrics and returns a structured
          ``pending_confirmation`` response with the detected entries.

        **Commit mode** (``confirmed=True``):
          Writes the entries from ``parsed_entries`` (or re-parsed from
          ``message``) to the ``quick_logs`` table.

        Args:
            arguments: Tool input dict matching ``input_schema``.
            user_id: Authenticated user ID used as the ``user_id`` FK.
            db: Async SQLAlchemy session for database writes.

        Returns:
            A result dict with one of the following ``status`` values:

            - ``"pending_confirmation"`` — entries detected, awaiting user OK.
            - ``"logged"`` — entries written to DB (commit mode).
            - ``"no_data"`` — no loggable metrics found in the message.
            - ``"error"`` — an unexpected error occurred during commit.
        """
        message: str = arguments.get("message", "")
        confirmed: bool = bool(arguments.get("confirmed", False))
        pre_parsed: list[dict[str, Any]] | None = arguments.get("parsed_entries")

        # ------------------------------------------------------------------
        # Phase 1: Parse
        # ------------------------------------------------------------------
        if not confirmed:
            entries = _parse_entries(message)
            if not entries:
                logger.info(
                    "log_health_data: no parseable metrics in message for user '%s'.",
                    user_id,
                )
                return {
                    "status": "no_data",
                    "message": "I couldn't find any loggable health data in that message. "
                    "Try saying something like 'I drank 2 liters of water' "
                    "or 'mood 7/10'.",
                }

            confirmation = _build_confirmation_message(entries)
            logger.info(
                "log_health_data: parsed %d entries for user '%s': %s",
                len(entries),
                user_id,
                [e["label"] for e in entries],
            )
            return {
                "status": "pending_confirmation",
                "entries": entries,
                "confirmation_message": confirmation,
            }

        # ------------------------------------------------------------------
        # Phase 2: Commit
        # ------------------------------------------------------------------
        raw_entries: list[dict[str, Any]] = pre_parsed or _parse_entries(message)
        # Validate and sanitise every entry — especially important for
        # LLM-supplied parsed_entries which arrive as unvalidated JSON.
        entries_to_log: list[dict[str, Any]] = [
            validated
            for entry in raw_entries
            if (validated := _validate_entry(entry)) is not None
        ]
        if not entries_to_log:
            return {
                "status": "no_data",
                "message": "No entries to log.",
            }

        try:
            # Import inside function to avoid circular imports at module level
            from app.models.quick_log import QuickLog  # noqa: PLC0415

            now_iso = datetime.now(timezone.utc).isoformat()
            logged_entries = []

            for entry in entries_to_log:
                metric_type = entry.get("metric_type", "notes")
                value = entry.get("value")
                label = entry.get("label", "")

                log = QuickLog(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    metric_type=metric_type,
                    value=float(value) if value is not None else None,
                    text_value=label if metric_type == "notes" else None,
                    tags=[],
                    logged_at=now_iso,
                )
                db.add(log)
                logged_entries.append(
                    {"id": log.id, "metric_type": metric_type, "label": label}
                )

            await asyncio.shield(db.commit())
            logger.info(
                "log_health_data: committed %d entries for user '%s'.",
                len(logged_entries),
                user_id,
            )
            return {
                "status": "logged",
                "logged_count": len(logged_entries),
                "entries": logged_entries,
                "message": f"Logged {len(logged_entries)} metric(s) successfully.",
            }

        except Exception:
            logger.exception(
                "log_health_data: commit failed for user '%s'.", user_id
            )
            return {
                "status": "error",
                "message": "An error occurred while saving your health data. Please try again.",
            }
