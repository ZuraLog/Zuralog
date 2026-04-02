"""Shared LLM input sanitization utilities."""
import re
import unicodedata

_DANGEROUS_PATTERN = re.compile(
    r'(ignore\s+(?:previous|above|all|everything)|system\s*:|assistant\s*:|forget\s+(?:all|everything|previous)|<\|im_start\|>|<\|im_end\|>|<\|endoftext\|>|<\|system\|>|\[INST\]|<<SYS>>|###\s*(?:instruction|system|prompt)\s*:|\[/INST\]|</s>|<\|user\|>|<\|assistant\|>|<\|end\|>|Human:|Assistant:)',
    re.IGNORECASE,
)


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
