"""Shared LLM input sanitization utilities."""
import re
import unicodedata

_DANGEROUS_PATTERN = re.compile(
    r'(ignore\s+(?:previous|above|all|everything)|system\s*:|assistant\s*:|forget\s+(?:all|everything|previous)|<\|im_start\|>|<\|im_end\|>|<\|endoftext\|>|<\|system\|>|\[INST\]|<<SYS>>|###\s*(?:instruction|system|prompt)\s*:|\[/INST\]|</s>|<\|user\|>|<\|assistant\|>|<\|end\|>|Human:|Assistant:)',
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# Memory injection filter
# ---------------------------------------------------------------------------

# High-signal phrases that are essentially never part of a legitimate health
# memory. These are matched unconditionally (case-insensitive).
_HIGH_SIGNAL_PHRASES = re.compile(
    r'(?:'
    r'your\s+new\s+instructions'
    r'|you\s+are\s+now'
    r'|system\s+prompt'
    r'|act\s+as(?:\s+an?)?\b'
    r'|act\s+like\b'
    r'|ignore\s+your\b'
    r'|forget\s+your\b'
    r'|override\s+your\b'
    r'|disregard\s+your\b'
    r'|reveal\s+your\b'
    r'|pretend\s+you\b'
    r'|you\s+have\s+no\s+restrictions'
    r'|skip\s+all\b'
    r'|new\s+instructions\s+are'
    r'|ignore\s+(?:all|previous|above|every)\b'
    r'|forget\s+(?:all|previous|every|every\w*)\b'
    r')',
    re.IGNORECASE,
)


def is_memory_injection_attempt(text: str) -> bool:
    """Return True if *text* looks like a prompt-injection attempt.

    This is used exclusively when deciding whether to inject a stored memory
    into the system prompt.  It is intentionally narrower than
    ``sanitize_for_llm`` — that function sanitises user input; this one
    guards the memory injection path.

    Design goals:
    - Catch classic injection phrases ("your new instructions are", "act as",
      "system prompt", …) unconditionally.
    - Do NOT flag normal health memories such as "always drink water" or
      "do not suggest dairy-based proteins".
    """
    # NFKC normalise to defeat homoglyph tricks before matching.
    normalised = unicodedata.normalize("NFKC", text)
    # Strip invisible characters.
    normalised = re.sub(r'[\u00ad\u200b\u200c\u200d\u2060\ufeff]', '', normalised)

    return bool(_HIGH_SIGNAL_PHRASES.search(normalised))


def sanitize_for_llm(text: str) -> str:
    """Remove prompt injection patterns from user-supplied text.

    Applies NFKC Unicode normalization first to neutralise homoglyph
    attacks (e.g. Turkish dotless-i, full-width characters) before
    running the pattern match. Does NOT truncate — callers are
    responsible for length limits.
    """
    # NFKC normalisation: collapses Unicode homoglyphs to their ASCII
    # canonical forms so the regex catches variants like ıgnore (U+0131)
    text = unicodedata.normalize("NFKC", text)
    # Strip zero-width and soft-hyphen characters
    text = re.sub(r'[\u00ad\u200b\u200c\u200d\u2060\ufeff]', '', text)
    return _DANGEROUS_PATTERN.sub("[removed]", text)
