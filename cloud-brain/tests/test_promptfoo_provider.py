"""
Unit tests for the PromptFoo custom provider.

These tests do NOT make real HTTP calls.  They verify:
  1. The provider returns a clean error dict when the API key is missing.
  2. The model is resolved from options["config"]["model"] when provided.
  3. The default model (_MODEL) is used when no config is supplied.
"""

from __future__ import annotations

import importlib
import os
import sys
from pathlib import Path
from unittest import mock

# ---------------------------------------------------------------------------
# Make sure the promptfoo directory is importable as "provider"
# ---------------------------------------------------------------------------

_PROMPTFOO_DIR = Path(__file__).resolve().parent.parent.parent / "promptfoo"


def _load_provider():
    """Import the provider module fresh, with promptfoo dir on sys.path."""
    if str(_PROMPTFOO_DIR) not in sys.path:
        sys.path.insert(0, str(_PROMPTFOO_DIR))
    # Force a fresh import so env-var patches take effect predictably.
    if "provider" in sys.modules:
        del sys.modules["provider"]
    return importlib.import_module("provider")


# ---------------------------------------------------------------------------
# Test 1: missing API key — model param supplied via config
# ---------------------------------------------------------------------------


def test_call_api_missing_key_with_model_config():
    """Provider returns a clean error dict when OPENROUTER_API_KEY is absent,
    even when a model override is passed through options["config"]."""
    provider = _load_provider()

    with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": ""}, clear=False):
        result = provider.call_api(
            "hello",
            {"config": {"model": "qwen/qwen3.5-flash-02-23"}},
            {"vars": {}},
        )

    assert result == {"error": "OPENROUTER_API_KEY environment variable is not set."}


# ---------------------------------------------------------------------------
# Test 2: missing API key — no config (default model path)
# ---------------------------------------------------------------------------


def test_call_api_missing_key_no_config():
    """Provider returns the same clean error dict when no config is supplied,
    confirming the default-model code path works without crashing."""
    provider = _load_provider()

    with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": ""}, clear=False):
        result = provider.call_api("hello", {}, {"vars": {}})

    assert result == {"error": "OPENROUTER_API_KEY environment variable is not set."}


# ---------------------------------------------------------------------------
# Test 3: model resolution logic
# ---------------------------------------------------------------------------


def test_model_resolution_uses_config_when_provided():
    """When options["config"]["model"] is set, the resolved model must match
    that value — not the module-level _MODEL default."""
    provider = _load_provider()

    custom_model = "qwen/qwen3.5-flash-02-23"
    options = {"config": {"model": custom_model}}

    resolved = options.get("config", {}).get("model", provider._MODEL)

    assert resolved == custom_model


def test_model_resolution_falls_back_to_default():
    """When options contains no config key, the resolved model must be the
    module-level _MODEL constant (Kimi K2.5)."""
    provider = _load_provider()

    options: dict = {}

    resolved = options.get("config", {}).get("model", provider._MODEL)

    assert resolved == provider._MODEL
    assert resolved == "moonshotai/kimi-k2.5"


# ---------------------------------------------------------------------------
# Test 5: conversation_history is prepended between system and final user msg
# ---------------------------------------------------------------------------


def test_conversation_history_prepended_in_correct_order():
    """When conversation_history is supplied in vars, the assembled messages
    array must be: [system, ...history, user_prompt] — in that exact order."""
    provider = _load_provider()

    history = [
        {"role": "user", "content": "How many steps daily?"},
        {"role": "assistant", "content": "Aim for 7,000-10,000 steps."},
    ]
    captured: list = []

    def _fake_post(*args, **kwargs):
        captured.append(kwargs.get("json", {}).get("messages", []))
        raise RuntimeError("stop after capture")

    import httpx

    with (
        mock.patch.dict(
            os.environ,
            {"OPENROUTER_API_KEY": "fake-key"},
            clear=False,
        ),
        mock.patch.object(httpx.Client, "post", _fake_post),
    ):
        provider.call_api(
            "Final attack prompt",
            {},
            {"vars": {"conversation_history": history}},
        )

    assert len(captured) == 1, "post should have been called exactly once"
    messages = captured[0]

    # First message must be the system prompt
    assert messages[0]["role"] == "system"

    # Middle messages must be the history in order
    assert messages[1] == history[0]
    assert messages[2] == history[1]

    # Last message must be the final user prompt
    assert messages[-1] == {"role": "user", "content": "Final attack prompt"}


# ---------------------------------------------------------------------------
# Test 6: missing conversation_history does not break the provider
# ---------------------------------------------------------------------------


def test_missing_conversation_history_does_not_regress():
    """When conversation_history is absent from vars, the messages array must
    still be [system, user] — the provider must not crash or produce extras."""
    provider = _load_provider()

    captured: list = []

    def _fake_post(*args, **kwargs):
        captured.append(kwargs.get("json", {}).get("messages", []))
        raise RuntimeError("stop after capture")

    import httpx

    with (
        mock.patch.dict(
            os.environ,
            {"OPENROUTER_API_KEY": "fake-key"},
            clear=False,
        ),
        mock.patch.object(httpx.Client, "post", _fake_post),
    ):
        provider.call_api("Hello", {}, {"vars": {}})

    assert len(captured) == 1
    messages = captured[0]

    # Exactly two messages: system then user
    assert len(messages) == 2
    assert messages[0]["role"] == "system"
    assert messages[1] == {"role": "user", "content": "Hello"}
