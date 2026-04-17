"""
Zuralog Cloud Brain — Insight Card Writer.

Makes a single OpenRouter LLM call to turn pre-computed InsightSignals
into natural-language insight cards. Uses OPENROUTER_INSIGHT_MODEL
(separate from the Coach tab model).

Fallback chain:
1. LLM returns valid JSON array → use LLM cards
   (sub-case: LLM returns malformed JSON → treated as failure, goes to step 2)
2. LLM call fails (APIError/timeout/parse error) → rule-based fallback per signal
3. Rule-based fallback also fails → minimum "working on it" card (always succeeds)
"""

import json
import logging
from typing import Any

from openai import APIError

from app.agent.llm_client import LLMClient
from app.analytics.insight_signal_detector import InsightSignal
from app.analytics.user_focus_profile import UserFocusProfile
from app.config import settings
from app.analytics.insight_card_schema import InsightCardSchema

logger = logging.getLogger(__name__)

# Allowlist validation to prevent prompt injection via user preferences
VALID_PERSONAS = {"tough_love", "balanced", "gentle"}
VALID_GOALS = {
    "weight_loss",
    "sleep",
    "fitness",
    "stress",
    "nutrition",
    "longevity",
    "build_muscle",
    "general_health",
}
VALID_FOCUSES = {
    "cutting",
    "recovery",
    "performance",
    "stress_management",
    "nutrition",
    "longevity",
    "body_recomposition",
    "sleep_optimisation",
    "activity_volume",
    "nutrition_tracking",
    "general",
}

_PROMPT_CHAR_WARN_THRESHOLD = 8000  # ~2000 tokens; log warning if exceeded

_SYSTEM_PROMPT = """\
You are a health insight writer for Zuralog. Turn structured health signal data into clear, personal, actionable insight cards.

User context:
- Coach persona: {persona}
- Fitness level: {fitness_level}
- Primary goals: {stated_goals}
- Inferred focus: {inferred_focus}
- Units: {units_system}

Writing style by persona:
- tough_love: Direct, honest, no sugarcoating. Holds the user accountable.
- balanced: Supportive but honest. Acknowledges effort and gaps equally.
- gentle: Encouraging, kind. Frames everything as an opportunity.

Output rules:
1. Return a JSON array ONLY. No text outside the array.
2. Each element: {{ "type": str, "title": str, "body": str, "priority": int(1-10), "reasoning": str }}
3. title: 3-7 words. Punchy headline.
4. body: 1-3 sentences. Use specific numbers from signal data. No generic advice.
5. priority: 1=most urgent, 10=least. Match severity (severity 5 → priority 1-2).
6. reasoning: 1 sentence explaining why this was surfaced today.
7. Never invent numbers. Only use values from the signals provided.
8. Each card must cover a different signal. No repeating insights.
9. Write in second person. No emoji.\
"""

_USER_PROMPT = """\
Today is {date}. Write one insight card per signal below.

Signals:
{signals_json}\
"""


class InsightCardWriter:
    def __init__(
        self,
        signals: list[InsightSignal],
        focus: UserFocusProfile,
        target_date: str,
    ) -> None:
        self.signals = signals
        self.focus = focus
        self.target_date = target_date
        self._llm = LLMClient(model=settings.openrouter_insight_model)

    async def write_cards(self) -> list[dict[str, Any]]:
        """Write cards for all signals. Returns at least 1 card always."""
        if not self.signals:
            return [_minimum_card()]

        # Level 1: LLM call
        try:
            cards = await self._call_llm()
            if cards is not None:
                return cards
        except APIError as e:
            logger.warning("InsightCardWriter: LLM API error, falling back for date=%s. error=%s", self.target_date, e)
        except Exception as e:
            logger.error(
                "InsightCardWriter: unexpected LLM error, falling back for date=%s. error=%s", self.target_date, e
            )

        # Level 2: Rule-based fallback
        try:
            return [_rule_based_card(s) for s in self.signals]
        except Exception as e:
            logger.error("InsightCardWriter: rule-based fallback failed. error=%s", e)

        # Level 3: Minimum card guarantee
        return [_minimum_card()]

    async def _call_llm(self) -> list[dict[str, Any]] | None:
        """Call LLM and parse JSON response. Returns None on parse failure."""
        safe_persona = self.focus.coach_persona if self.focus.coach_persona in VALID_PERSONAS else "balanced"
        safe_goals = ", ".join(g for g in self.focus.stated_goals if g in VALID_GOALS) or "general health"
        safe_focus = self.focus.inferred_focus if self.focus.inferred_focus in VALID_FOCUSES else "general"
        safe_fitness = "active"
        if self.focus.fitness_level in ("beginner", "active", "athletic"):
            safe_fitness = self.focus.fitness_level

        system = _SYSTEM_PROMPT.format(
            persona=safe_persona,
            fitness_level=safe_fitness,
            stated_goals=safe_goals,
            inferred_focus=safe_focus,
            units_system="metric" if self.focus.units_system not in ("metric", "imperial") else self.focus.units_system,
        )

        signals_for_llm = [
            {
                "signal_type": s.signal_type,
                "metrics": s.metrics,
                "values": s.values,
                "actionable": s.actionable,
                "title_hint": s.title_hint,
                "data_payload": s.data_payload,
            }
            for s in self.signals
        ]

        user_msg = _USER_PROMPT.format(
            date=self.target_date,
            signals_json=json.dumps(signals_for_llm, indent=2),
        )

        if len(system) + len(user_msg) > _PROMPT_CHAR_WARN_THRESHOLD:
            logger.warning(
                "InsightCardWriter: prompt is large (%d chars, %d signals). Consider reducing data_payload.",
                len(system) + len(user_msg),
                len(self.signals),
            )

        response = await self._llm.chat(
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_msg},
            ],
            temperature=0.4,
            max_tokens=1024,
            # Insight model (MiniMax M2.7) is a reasoning model; without this
            # it spends output tokens on hidden chain-of-thought and returns
            # empty content, forcing every call to fall back to rule-based.
            # The response is a JSON array, so we can't use json_object mode
            # (which requires an object top-level) — rely on prompt discipline
            # for format and disable reasoning to guarantee content is emitted.
            reasoning={"effort": "none"},
        )

        raw = (response.choices[0].message.content or "").strip()

        # Strips the opening fence line (handles ```json, ```JSON, plain ```, etc.)
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1]
            raw = raw.rsplit("```", 1)[0].strip()

        try:
            raw_cards = json.loads(raw)
            if not isinstance(raw_cards, list) or len(raw_cards) == 0:
                logger.warning("InsightCardWriter: LLM returned non-list or empty response")
                return None

            validated: list[dict[str, Any]] = []
            for i, raw_card in enumerate(raw_cards):
                try:
                    card = InsightCardSchema.model_validate(raw_card)
                    validated.append(card.model_dump())
                except Exception as e:
                    logger.warning(
                        "InsightCardWriter: skipping invalid card at index %d — %s",
                        i,
                        e,
                    )
            return validated if validated else None
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning("InsightCardWriter: malformed JSON from LLM — %s. Raw: %.200s", e, raw)
            return None


def _rule_based_card(signal: InsightSignal) -> dict[str, Any]:
    """Generate a minimal rule-based card from a signal."""
    metric_label = signal.metrics[0].replace("_", " ") if signal.metrics else "metric"

    body_parts = []
    if "pct_change" in signal.values:
        pct = abs(signal.values["pct_change"])
        direction = "up" if signal.values["pct_change"] > 0 else "down"
        body_parts.append(f"Your {metric_label} is {direction} {pct:.0f}% recently.")
    elif "current" in signal.values and "target" in signal.values:
        body_parts.append(f"You're at {signal.values['current']} vs your goal of {signal.values['target']}.")
    elif "streak_days" in signal.values:
        body_parts.append(f"You have a {signal.values['streak_days']}-day streak.")
    else:
        body_parts.append(f"Your {metric_label} needs attention.")

    if signal.actionable:
        body_parts.append("Take action today to stay on track.")

    return {
        "type": signal.signal_type,
        "title": signal.title_hint or f"{metric_label.title()} update",
        "body": " ".join(body_parts),
        "priority": max(1, 11 - signal.severity * 2),
        "reasoning": f"Detected via {signal.signal_type} analysis.",
    }


def _minimum_card() -> dict[str, Any]:
    """Last-resort card when all fallbacks fail."""
    return {
        "type": "welcome",
        "title": "Insights loading",
        "body": "Your health insights are being prepared. Check back shortly.",
        "priority": 10,
        "reasoning": "Your insights are being prepared.",
    }
