"""Shared LLM input sanitization utilities."""
import re

_DANGEROUS_PATTERN = re.compile(
    r'(ignore\s+(?:previous|above|all|everything)|system\s*:|assistant\s*:|forget\s+(?:all|everything|previous)|<\|im_start\|>|<\|im_end\|>|<\|endoftext\|>|<\|system\|>|\[INST\]|<<SYS>>|###\s*(?:instruction|system|prompt)\s*:|\[/INST\]|</s>|<\|user\|>|<\|assistant\|>|<\|end\|>|Human:|Assistant:)',
    re.IGNORECASE,
)


def sanitize_for_llm(text: str) -> str:
    """Remove prompt injection patterns from user-supplied text.

    Does NOT truncate — callers are responsible for length limits.
    """
    return _DANGEROUS_PATTERN.sub("[removed]", text)
