"""
Zuralog Cloud Brain — Message Classifier.

Classifies incoming user messages as 'deep_analysis' (requiring Kimi K2.5 / Zura)
or 'standard' (handled by Qwen3.5-Flash / Zura Flash).

Uses a fast-path heuristic for obviously short/simple messages, then falls back
to a single structured LLM call for anything ambiguous. Always fails safe to
'standard' on timeout, API error, or unexpected output.
"""

import asyncio
import logging
from enum import Enum
from typing import Any

from openai import AsyncOpenAI

from app.config import settings

logger = logging.getLogger(__name__)


class MessageTier(str, Enum):
    """Classification result for a user message."""

    deep_analysis = "deep_analysis"
    standard = "standard"


_CLASSIFIER_TIMEOUT = 3.0  # seconds before we give up and default to standard

_CLASSIFIER_SYSTEM = """You are a message classifier for a health and fitness AI coach.

Classify the user message into exactly one of these categories:

deep_analysis — Use this for:
- Complex health data analysis across multiple metrics or time periods
- Training plan or program generation requiring calculations
- Periodization, load management, or structured programming requests
- Causal analysis ("why is X happening?", "what's causing Y?")
- Goal setting with specific constraints and calculations
- Correlation analysis across different health metrics
- Multi-week or multi-month trend analysis

standard — Use this for:
- Greetings, thanks, casual conversation
- Simple single-metric lookups ("what were my steps yesterday?")
- Activity logging and confirmations
- General motivation, encouragement, tips
- Simple one-question answers
- Short memory retrievals
- Any message under 8 words with no plan/analysis keywords

Respond with ONLY the category name. No explanation. No punctuation. No extra text."""

_PLAN_KEYWORDS = frozenset({
    "plan", "program", "schedule", "routine", "periodiz",
    "analyze", "analysis", "compare", "breakdown", "correlat",
    "trend", "pattern", "why", "cause", "optimize",
})


def _compute_signals(text: str) -> dict[str, Any]:
    """Compute cheap heuristic signals from the message text."""
    lower = text.lower()
    words = lower.split()
    has_plan_keyword = any(kw in lower for kw in _PLAN_KEYWORDS)
    return {
        "word_count": len(words),
        "has_question_mark": "?" in text,
        "has_plan_keyword": has_plan_keyword,
    }


async def classify_message(text: str) -> MessageTier:
    """Classify a user message as deep_analysis or standard.

    Uses a fast path for obviously simple messages (< 8 words, no plan keywords).
    Falls back to a single LLM call for anything ambiguous.
    Always returns MessageTier.standard on any failure.

    Args:
        text: The user's message text.

    Returns:
        MessageTier.deep_analysis or MessageTier.standard.
    """
    signals = _compute_signals(text)

    # Fast path: very short messages with no plan keywords are always standard.
    if signals["word_count"] < 8 and not signals["has_plan_keyword"]:
        return MessageTier.standard

    # LLM path: ask the classifier model.
    try:
        client = AsyncOpenAI(
            api_key=settings.openrouter_api_key.get_secret_value(),
            base_url="https://openrouter.ai/api/v1",
        )
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model=settings.openrouter_classifier_model,
                messages=[
                    {"role": "system", "content": _CLASSIFIER_SYSTEM},
                    {"role": "user", "content": text[:500]},
                ],
                temperature=0.0,
                max_tokens=10,
            ),
            timeout=_CLASSIFIER_TIMEOUT,
        )
        raw = response.choices[0].message.content or ""
        raw = raw.strip().lower()
        try:
            return MessageTier(raw)
        except ValueError:
            logger.warning("Classifier returned unexpected value %r, defaulting to standard", raw)
            return MessageTier.standard
    except asyncio.TimeoutError:
        logger.info("Classifier timed out, defaulting to standard")
        return MessageTier.standard
    except Exception as exc:
        logger.warning("Classifier error: %s, defaulting to standard", exc)
        return MessageTier.standard
