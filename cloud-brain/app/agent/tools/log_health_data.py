"""
Zuralog Cloud Brain — NL Health Data Logging Tool.

Parses natural language input to extract loggable health data items
(water, mood, energy, stress, weight, sleep, steps, notes) and writes
confirmed items to the QuickLog table.

Two-step flow:
  1. parse_nl_for_logging(text) → LogConfirmationPayload
     Client shows a confirmation card to the user.
  2. write_confirmed_logs(payload, user_id, session) → int
     After user confirms, persist the parsed items.

Supported patterns (examples):
  "I drank 3 glasses of water"          → water: 3
  "feeling a 7/10 today"                → mood: 7
  "mood is great"                       → mood: 8 (mapped from text)
  "energy level 4"                      → energy: 4
  "stress is high"                      → stress: 8 (mapped from text)
  "weight is 75kg"                      → weight: 75
  "slept 7.5 hours"                     → sleep_quality (hours noted)
  "walked 10,000 steps"                 → steps: 10000
  note: "had a headache today"          → notes: "had a headache today"
"""

from __future__ import annotations

import logging
import re
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.quick_log import MetricType, QuickLog

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class LoggableItem:
    """A single parsed loggable health data point.

    Attributes:
        metric_type: Canonical metric name (aligned with MetricType enum values
            plus 'weight', 'sleep_hours', 'steps').
        value: Numeric value (e.g. 7.5 for sleep hours). None for text-only.
        text_value: Text value for notes or descriptive entries.
        unit: Unit string (e.g. "cups", "kg", "hours"). May be None.
        confidence: Parser confidence 0–1. < 0.5 = low confidence.
        raw_text: The original text fragment that produced this item.
    """

    metric_type: str
    value: float | None
    text_value: str | None
    unit: str | None
    confidence: float
    raw_text: str


@dataclass
class LogConfirmationPayload:
    """Pending log items awaiting user confirmation.

    Attributes:
        items: Parsed loggable items.
        confirmation_id: UUID string the client references when confirming.
        summary: Human-readable summary for the confirmation card UI.
    """

    items: list[LoggableItem]
    confirmation_id: str
    summary: str


# ---------------------------------------------------------------------------
# Text → score mappings
# ---------------------------------------------------------------------------

_MOOD_TEXT_MAP: dict[str, float] = {
    "terrible": 1.0,
    "awful": 1.0,
    "horrible": 1.0,
    "bad": 3.0,
    "poor": 3.0,
    "rough": 3.0,
    "okay": 5.0,
    "ok": 5.0,
    "alright": 5.0,
    "fine": 5.0,
    "meh": 5.0,
    "good": 7.0,
    "well": 7.0,
    "decent": 6.0,
    "great": 8.0,
    "amazing": 9.0,
    "fantastic": 9.0,
    "excellent": 9.0,
    "perfect": 10.0,
    "incredible": 10.0,
}

_STRESS_TEXT_MAP: dict[str, float] = {
    "none": 0.0,
    "no stress": 0.0,
    "calm": 1.0,
    "relaxed": 1.0,
    "low": 2.0,
    "minimal": 2.0,
    "moderate": 5.0,
    "some": 5.0,
    "medium": 5.0,
    "high": 8.0,
    "stressed": 8.0,
    "anxious": 8.0,
    "very high": 9.0,
    "overwhelming": 10.0,
    "extreme": 10.0,
}

_ENERGY_TEXT_MAP: dict[str, float] = {
    "exhausted": 1.0,
    "drained": 1.0,
    "tired": 3.0,
    "fatigued": 3.0,
    "low": 3.0,
    "okay": 5.0,
    "moderate": 5.0,
    "good": 7.0,
    "energetic": 8.0,
    "great": 8.0,
    "very energetic": 9.0,
    "high": 9.0,
    "amazing": 10.0,
}


def _map_text_to_score(text: str, mapping: dict[str, float]) -> float | None:
    """Map a descriptive word to a numeric score.

    Args:
        text: The word/phrase to map.
        mapping: Dict of text → score.

    Returns:
        Numeric score, or None if no match.
    """
    text_lower = text.lower().strip()
    return mapping.get(text_lower)


# ---------------------------------------------------------------------------
# Pattern definitions
# ---------------------------------------------------------------------------

_PATTERNS: list[tuple[str, str, str | None]] = [
    # (regex, metric_type, unit_if_fixed)
    # Water
    (r"drank?\s+(\d+(?:\.\d+)?)\s*(glasses?|cups?|liters?|litres?|ml|oz)", "water", None),
    (r"(\d+(?:\.\d+)?)\s*(glasses?|cups?|liters?|litres?|ml|oz)\s+of\s+water", "water", None),
    # Mood — numeric
    (r"(?:mood|feeling|feel)\s+(?:is\s+)?(?:a\s+)?(\d+(?:\.\d+)?)\s*(?:/10)?", "mood", None),
    (r"feeling\s+a\s+(\d+(?:\.\d+)?)\s*/\s*10", "mood", "/10"),
    # Mood — text
    (
        r"(?:feeling|mood is|mood:)\s+(terrible|awful|horrible|bad|poor|rough|okay|ok|alright|fine|meh|good|well|decent|great|amazing|fantastic|excellent|perfect|incredible)",
        "mood_text",
        None,
    ),
    # Energy — numeric
    (r"energy\s+(?:level\s+)?(?:is\s+)?(\d+(?:\.\d+)?)\s*(?:/10)?", "energy", None),
    # Energy — text
    (r"(?:feeling|energy is|energy:)\s+(exhausted|drained|tired|fatigued|energetic|good)", "energy_text", None),
    # Stress — numeric
    (r"stress\s+(?:level\s+)?(?:is\s+)?(\d+(?:\.\d+)?)\s*(?:/10)?", "stress", None),
    # Stress — text
    (
        r"stress(?:\s+is|:)\s+(none|calm|relaxed|low|minimal|moderate|some|medium|high|stressed|anxious|very\s+high|overwhelming|extreme)",
        "stress_text",
        None,
    ),
    # Weight
    (r"weigh\s+(\d+(?:\.\d+)?)\s*(kg|lbs?|pounds?|kilograms?)", "weight", None),
    (r"weight\s+(?:is\s+)?(\d+(?:\.\d+)?)\s*(kg|lbs?|pounds?|kilograms?)", "weight", None),
    # Sleep
    (r"slept?\s+(\d+(?:\.\d+)?)\s*(hours?|hrs?)", "sleep_hours", "hours"),
    (r"(\d+(?:\.\d+)?)\s*(hours?|hrs?)\s+of\s+sleep", "sleep_hours", "hours"),
    # Steps
    (r"walked?\s+(\d[\d,]*)\s+steps?", "steps", "steps"),
    (r"(\d[\d,]*)\s+steps?", "steps", "steps"),
    # Distance
    (r"ran?\s+(\d+(?:\.\d+)?)\s*(km|kilometers?|miles?|mi)", "steps", None),  # approximate
    # Notes — quoted
    (r'note:\s*"([^"]+)"', "notes", None),
    (r"note:\s*(.+?)(?:\.|$)", "notes", None),
]


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------


def parse_nl_for_logging(text: str) -> LogConfirmationPayload:
    """Parse natural language input to extract loggable health data items.

    Args:
        text: Free-form user input string.

    Returns:
        LogConfirmationPayload with parsed items, confirmation ID, and summary.
    """
    if not text or not text.strip():
        return LogConfirmationPayload(
            items=[],
            confirmation_id=str(uuid.uuid4()),
            summary="No loggable health data detected.",
        )

    items: list[LoggableItem] = []
    text_lower = text.lower()

    for pattern, metric_type, default_unit in _PATTERNS:
        match = re.search(pattern, text_lower, re.IGNORECASE)
        if not match:
            continue

        if metric_type.endswith("_text"):
            # Text-to-score mapping
            word = match.group(1).strip()
            base_metric = metric_type.replace("_text", "")
            mapping = {"mood": _MOOD_TEXT_MAP, "energy": _ENERGY_TEXT_MAP, "stress": _STRESS_TEXT_MAP}.get(
                base_metric, {}
            )
            score = _map_text_to_score(word, mapping)
            if score is not None:
                items.append(
                    LoggableItem(
                        metric_type=base_metric,
                        value=score,
                        text_value=word,
                        unit="/10",
                        confidence=0.75,
                        raw_text=match.group(0),
                    )
                )
        elif metric_type == "notes":
            note_text = match.group(1).strip()
            if note_text:
                items.append(
                    LoggableItem(
                        metric_type="notes",
                        value=None,
                        text_value=note_text,
                        unit=None,
                        confidence=0.9,
                        raw_text=match.group(0),
                    )
                )
        else:
            raw_value = match.group(1).replace(",", "")
            try:
                value = float(raw_value)
            except ValueError:
                continue

            # Determine unit
            unit = default_unit
            if len(match.groups()) >= 2:
                unit = match.group(2) if match.group(2) else default_unit

            # Normalize water to cups if possible
            if metric_type == "water" and unit:
                unit_lower = unit.lower()
                if unit_lower in ("ml",):
                    value = round(value / 240, 1)  # 240ml ≈ 1 cup
                    unit = "cups"
                elif unit_lower in ("liter", "litre", "liters", "litres", "l"):
                    value = round(value * 4.2, 1)
                    unit = "cups"

            # Confidence heuristics
            confidence = 0.9
            if metric_type in ("mood", "energy", "stress") and value > 10:
                confidence = 0.5  # Suspicious — could be misparse

            items.append(
                LoggableItem(
                    metric_type=metric_type,
                    value=value,
                    text_value=None,
                    unit=unit,
                    confidence=confidence,
                    raw_text=match.group(0),
                )
            )

    # Deduplicate: keep highest-confidence item per metric_type
    seen: dict[str, LoggableItem] = {}
    for item in items:
        if item.metric_type not in seen or item.confidence > seen[item.metric_type].confidence:
            seen[item.metric_type] = item
    items = list(seen.values())

    summary = _build_summary(items)

    return LogConfirmationPayload(
        items=items,
        confirmation_id=str(uuid.uuid4()),
        summary=summary,
    )


def _build_summary(items: list[LoggableItem]) -> str:
    """Build a human-readable summary string for the confirmation card.

    Args:
        items: Parsed loggable items.

    Returns:
        Summary string.
    """
    if not items:
        return "No loggable health data detected."

    parts: list[str] = []
    for item in items:
        if item.metric_type == "water":
            parts.append(f"💧 Water: {item.value} {item.unit or 'units'}")
        elif item.metric_type == "mood":
            parts.append(f"😊 Mood: {item.value}/10")
        elif item.metric_type == "energy":
            parts.append(f"⚡ Energy: {item.value}/10")
        elif item.metric_type == "stress":
            parts.append(f"🧘 Stress: {item.value}/10")
        elif item.metric_type == "weight":
            parts.append(f"⚖️ Weight: {item.value} {item.unit or 'kg'}")
        elif item.metric_type == "sleep_hours":
            parts.append(f"😴 Sleep: {item.value} hours")
        elif item.metric_type == "steps":
            val = int(item.value) if item.value else 0
            parts.append(f"👟 Steps: {val:,}")
        elif item.metric_type == "notes":
            parts.append(f"📝 Note: {item.text_value}")
        else:
            parts.append(f"{item.metric_type}: {item.value}")

    return " | ".join(parts)


# ---------------------------------------------------------------------------
# Write confirmed logs
# ---------------------------------------------------------------------------

# Map NL metric types to QuickLog MetricType values
_METRIC_TYPE_MAP: dict[str, str] = {
    "water": MetricType.WATER.value,
    "mood": MetricType.MOOD.value,
    "energy": MetricType.ENERGY.value,
    "stress": MetricType.STRESS.value,
    "weight": MetricType.NOTES.value,  # No dedicated weight type — log as notes with value
    "sleep_hours": MetricType.SLEEP_QUALITY.value,
    "steps": MetricType.NOTES.value,  # No dedicated steps quick-log type
    "notes": MetricType.NOTES.value,
}


async def write_confirmed_logs(
    confirmation_payload: LogConfirmationPayload,
    user_id: str,
    session: AsyncSession,
) -> int:
    """Persist confirmed log items to the QuickLog table.

    Only writes items with confidence >= 0.5.

    Args:
        confirmation_payload: The payload previously returned by parse_nl_for_logging.
        user_id: Zuralog user ID (authenticated caller).
        session: Open async DB session.

    Returns:
        Number of rows written.
    """
    written = 0
    now = datetime.now(timezone.utc)

    for item in confirmation_payload.items:
        if item.confidence < 0.5:
            logger.debug("Skipping low-confidence item: %s (%.2f)", item.metric_type, item.confidence)
            continue

        metric_type_value = _METRIC_TYPE_MAP.get(item.metric_type, MetricType.NOTES.value)

        # Build a text_value note for types without a dedicated slot.
        text_val = item.text_value
        if item.metric_type in ("weight", "steps") and item.value is not None:
            label = item.metric_type.replace("_", " ").title()
            unit_str = f" {item.unit}" if item.unit else ""
            text_val = f"{label}: {item.value}{unit_str}"

        log_entry = QuickLog(
            user_id=user_id,
            metric_type=metric_type_value,
            value=item.value,
            text_value=text_val,
            logged_at=now,
        )
        session.add(log_entry)
        written += 1

    if written:
        await session.commit()
        logger.info(
            "write_confirmed_logs: wrote %d entries for user %s (confirmation_id=%s)",
            written,
            user_id,
            confirmation_payload.confirmation_id,
        )

    return written
