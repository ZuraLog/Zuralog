"""Food image service.

Resolves a food description (e.g. "eggs with toast") to a stock photo URL
via Pexels, cached by normalised query. Used by the meal-parse loading
state to show contextual imagery while the AI parses the description.
"""
from __future__ import annotations

import re

_PUNCT_RE = re.compile(r"[^\w\s-]")  # keep letters/digits/_, whitespace, hyphen
_WHITESPACE_RE = re.compile(r"\s+")


def normalise_query(raw: str) -> str:
    """Normalise a user food description into a stable cache key.

    Rules:
      1. lowercase
      2. strip punctuation (keep hyphen so "low-carb" survives)
      3. collapse runs of whitespace to a single space
      4. strip leading/trailing whitespace

    Examples:
        "Eggs & Toast!"     -> "eggs toast"
        "low-carb  bagel"   -> "low-carb bagel"
        "   EGGS   "        -> "eggs"
    """
    lowered = raw.lower()
    depunct = _PUNCT_RE.sub(" ", lowered)
    collapsed = _WHITESPACE_RE.sub(" ", depunct)
    return collapsed.strip()
