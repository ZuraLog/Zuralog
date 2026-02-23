"""
Zuralog Cloud Brain — System Prompt Tests.

Verifies the system prompt contains required persona elements,
capability descriptions, and safety constraints.
"""

from app.agent.prompts.system import SYSTEM_PROMPT, build_system_prompt


def test_system_prompt_contains_persona():
    """System prompt must define the Tough Love Coach persona."""
    assert "Tough Love" in SYSTEM_PROMPT
    assert "direct" in SYSTEM_PROMPT.lower()


def test_system_prompt_contains_capabilities():
    """System prompt must mention key data sources."""
    assert "Apple Health" in SYSTEM_PROMPT or "apple_health" in SYSTEM_PROMPT
    assert "Strava" in SYSTEM_PROMPT or "strava" in SYSTEM_PROMPT
    assert "Health Connect" in SYSTEM_PROMPT or "health_connect" in SYSTEM_PROMPT


def test_system_prompt_contains_safety():
    """System prompt must include medical disclaimer."""
    lower = SYSTEM_PROMPT.lower()
    assert "medical" in lower or "doctor" in lower


def test_system_prompt_has_tool_rules():
    """System prompt must instruct the AI to use tools for data."""
    lower = SYSTEM_PROMPT.lower()
    assert "tool" in lower


def test_build_system_prompt_default():
    """build_system_prompt() without suffix returns base prompt."""
    result = build_system_prompt()
    assert result == SYSTEM_PROMPT


def test_build_system_prompt_with_suffix():
    """build_system_prompt() with suffix appends user context."""
    suffix = "\nUser Goal: Lose 5kg. Tone: Gentle."
    result = build_system_prompt(user_context_suffix=suffix)
    assert SYSTEM_PROMPT in result
    assert "Lose 5kg" in result
    assert "Gentle" in result
