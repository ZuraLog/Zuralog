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

# High-signal phrases that detect prompt-injection attempts.
#
# Design principle: patterns that overlap with ordinary health language require
# an instruction-specific follow-on target so that legitimate coaching memories
# (e.g. "Ignore your cravings", "Forget your old habits", "Skip all processed
# foods", "You are now at 95% of your goal") do not produce false positives.
# Patterns that are genuinely rare in health contexts (e.g. "your new
# instructions are", "system prompt", "you have no restrictions") are matched
# unconditionally.
_HIGH_SIGNAL_PHRASES = re.compile(
    r'(?:'
    # Instruction-override phrases — always high-signal in any context
    r'your\s+new\s+instructions'
    r'|new\s+instructions\s+are'
    r'|system\s+prompt'
    r'|you\s+have\s+no\s+restrictions'
    # Broad ignore/forget — only when clearly targeting prior instructions
    r'|ignore\s+(?:all|previous|above|every)\b'
    r'|forget\s+(?:all|previous|every)\b'
    # AI identity reassignment — require an identity target after "you are now"
    # so "You are now at 95% of your goal" is not flagged
    r'|you\s+are\s+now\s+(?:a\s+different\b|an?\s+(?:unrestricted|alternative|other)\b|dan\b|without\s+restrictions?)'
    # "act as / act like" — require an AI-identity or restriction-dropping target
    # so "act as a baseline" and "act as a personal trainer" are not flagged
    r'|act\s+as\s+(?:an?\s+)?(?:unrestricted\b|different\s+ai\b|ai\s+with(?:out)?\b|dan\b|another\s+ai\b)'
    r'|act\s+like\s+(?:an?\s+(?:unrestricted|different)\b|dan\b|you\s+have\s+no|a\s+different\s+ai\b)'
    # "ignore/forget/override/disregard your …" — require an instruction target
    # so "Ignore your cravings", "Forget your old habits", "Override your
    # instinct to skip leg day" are not flagged
    r'|(?:ignore|forget|override|disregard)\s+your\s+(?:rules?|guidelines?|instructions?|safety|constraints?|restrictions?|training|previous)\b'
    # Reveal — already requires an instruction target (tightened in review)
    r'|reveal\s+your\s+(?:system|internal|prompt|instructions?|rules?|guidelines?|secrets?|configuration)\b'
    # "pretend you …" — require a restriction-dropping follow-on so
    # "pretend you ate only vegetables" is not flagged
    r'|pretend\s+you\s+(?:have\s+no\s+(?:restrictions?|rules?|guidelines?)'
    r'|are\s+(?:an?\s+)?(?:unrestricted\b|a\s+different\s+ai\b)'
    r'|don.t\s+have\s+(?:any\s+)?(?:restrictions?|rules?|guidelines?|safety)\b)'
    # "skip all …" — require a safety/rule target so "skip all processed foods"
    # is not flagged
    r'|skip\s+all\s+(?:safety|rules?|guidelines?|restrictions?|warnings?|disclaimers?|checks?|filters?)\b'
    r')',
    re.IGNORECASE,
)


def is_memory_injection_attempt(text: str) -> bool:
    """Return True if *text* looks like a prompt-injection attempt.

    Used as a general-purpose injection guard at two points in the pipeline:
    1. Before injecting a stored memory into the system prompt.
    2. Before feeding a tool result back to the model in the orchestrator.

    Intentionally narrower than ``sanitize_for_llm`` — that function
    sanitises arbitrary user input by replacing dangerous patterns.  This
    function is a binary gate: it returns True so the caller can decide to
    skip or redact the content entirely.

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
