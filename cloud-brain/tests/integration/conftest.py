"""
Zuralog Cloud Brain — Integration Test Configuration.

By default, when test_chat_tools.py tests exist in the last-failed cache,
only the failed ones are run (saves AI credits on long live tests).

Pass --all to run every test regardless of prior results:
    pytest tests/integration/test_chat_tools.py --all -v -s
"""

from __future__ import annotations

import pytest


def pytest_addoption(parser: pytest.Parser) -> None:
    try:
        parser.addoption(
            "--all",
            action="store_true",
            default=False,
            help=(
                "Run all integration tests, not just the ones that failed last time. "
                "Without this flag, only previously-failed tests in test_chat_tools.py "
                "are re-run (saves API credits)."
            ),
        )
    except ValueError:
        # Already registered by another conftest — ignore.
        pass


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Deselect passing test_chat_tools tests unless --all is given."""
    if config.getoption("--all", default=False):  # type: ignore[call-arg]
        return  # User wants everything — don't filter.

    cache = getattr(config, "cache", None)
    if cache is None:
        return  # Cache plugin disabled — run everything.

    last_failed: dict = cache.get("cache/lastfailed", {})
    if not last_failed:
        return  # No prior failures recorded — run everything.

    # Split items into chat-tool tests and everything else.
    chat_items = [i for i in items if "test_chat_tools" in str(i.nodeid)]
    other_items = [i for i in items if "test_chat_tools" not in str(i.nodeid)]

    # Which chat tests are in the last-failed set?
    failed_chat = [i for i in chat_items if i.nodeid in last_failed]

    if not failed_chat:
        # All chat tests passed last time — run everything (no filtering).
        return

    # Deselect chat tests that passed last time.
    deselected = [i for i in chat_items if i not in failed_chat]
    if deselected:
        config.hook.pytest_deselected(items=deselected)  # type: ignore[attr-defined]
        items[:] = other_items + failed_chat
