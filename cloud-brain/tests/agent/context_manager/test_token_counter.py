"""Tests for the token counter utility."""

from __future__ import annotations

from app.agent.context_manager.token_counter import (
    count_messages,
    count_tokens,
    truncate_to_tokens,
)


class TestCountTokens:
    def test_known_string(self) -> None:
        # "Hello, world!" encodes to exactly 4 tokens in cl100k_base
        assert count_tokens("Hello, world!") == 4

    def test_empty_string_returns_zero(self) -> None:
        assert count_tokens("") == 0

    def test_longer_text_increases_count(self) -> None:
        short = count_tokens("Hi")
        long = count_tokens("Hi, this is a much longer sentence that should have more tokens.")
        assert long > short

    def test_non_ascii(self) -> None:
        # Should not raise; may produce any positive token count
        result = count_tokens("こんにちは")
        assert result > 0


class TestCountMessages:
    def test_single_message_overhead(self) -> None:
        msgs = [{"role": "user", "content": "Hello"}]
        # "Hello" = 1 token + 4 overhead per message + 2 reply priming = 7
        result = count_messages(msgs)
        assert result == 7

    def test_empty_content_still_counts_overhead(self) -> None:
        msgs = [{"role": "user", "content": ""}]
        # 0 content tokens + 4 overhead + 2 priming = 6
        assert count_messages(msgs) == 6

    def test_two_messages_accumulates(self) -> None:
        msgs = [
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there"},
        ]
        single_user = count_messages([msgs[0]])
        single_asst = count_messages([msgs[1]])
        combined = count_messages(msgs)
        # Combined = both messages + only one set of reply priming
        # single_user and single_asst each have +2 reply priming overhead
        # combined should be (single_user - 2) + single_asst = single_user + single_asst - 2
        assert combined == single_user + single_asst - 2

    def test_none_content_treated_as_empty(self) -> None:
        msgs = [{"role": "tool", "content": None}]
        result = count_messages(msgs)
        assert result == 6  # 0 + 4 overhead + 2 priming


class TestTruncateToTokens:
    def test_short_string_unchanged(self) -> None:
        text = "Hello"
        assert truncate_to_tokens(text, 100) == text

    def test_long_string_truncated(self) -> None:
        text = "word " * 1000  # ~1000 tokens
        truncated = truncate_to_tokens(text, 50)
        assert count_tokens(truncated) <= 50

    def test_exact_boundary(self) -> None:
        text = "Hello, world!"  # 4 tokens
        assert truncate_to_tokens(text, 4) == text

    def test_truncated_to_one_below_boundary_is_shorter(self) -> None:
        text = "Hello, world!"  # 4 tokens
        truncated = truncate_to_tokens(text, 3)
        assert count_tokens(truncated) <= 3
        assert len(truncated) < len(text)
