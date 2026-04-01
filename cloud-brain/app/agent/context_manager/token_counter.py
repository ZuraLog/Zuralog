"""
Zuralog Cloud Brain — Token Counter.

Counts tokens using tiktoken with cl100k_base encoding, which is
compatible with OpenAI-format APIs including OpenRouter/Kimi K2.5.
Overcounts slightly vs. the actual model tokenizer — this is intentional
(conservative budget prevents hitting context limits).
"""

from __future__ import annotations

import tiktoken

_ENCODING = tiktoken.get_encoding("cl100k_base")

# Token overhead per message in the OpenAI messages format.
# Each message has ~4 tokens of role + separator overhead.
_TOKENS_PER_MESSAGE = 4
# Every request is primed with 2 tokens for the assistant reply.
_TOKENS_REPLY_PRIMING = 2


def count_tokens(text: str) -> int:
    """Count the number of tokens in a text string.

    Args:
        text: The text to tokenize.

    Returns:
        Token count as an integer. Returns 0 for empty strings.
    """
    if not text:
        return 0
    return len(_ENCODING.encode(text))


def count_messages(messages: list[dict]) -> int:
    """Count the total tokens in a list of OpenAI-format messages.

    Includes per-message overhead (role + separators) and reply priming.
    Matches the formula used by the OpenAI tiktoken cookbook.

    Args:
        messages: List of dicts with at least a 'content' key.

    Returns:
        Total token count including overhead.
    """
    total = _TOKENS_REPLY_PRIMING
    for msg in messages:
        total += _TOKENS_PER_MESSAGE
        content = msg.get("content") or ""
        if isinstance(content, str):
            total += count_tokens(content)
    return total


def truncate_to_tokens(text: str, max_tokens: int) -> str:
    """Truncate text to at most max_tokens tokens.

    Decodes the truncated token sequence back to a string, which may
    produce slightly fewer characters than the input if the boundary
    falls mid-codepoint.

    Args:
        text: The text to truncate.
        max_tokens: Maximum number of tokens to keep.

    Returns:
        Truncated text string decoded from the token sequence.
    """
    tokens = _ENCODING.encode(text)
    if len(tokens) <= max_tokens:
        return text
    return _ENCODING.decode(tokens[:max_tokens])
