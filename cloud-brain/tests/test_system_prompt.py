"""
Zuralog Cloud Brain — System Prompt Tests.

Verifies the system prompt contains required persona elements,
capability descriptions, and safety constraints.
"""

from datetime import date

from app.agent.prompts.system import SYSTEM_PROMPT, UserProfile, build_system_prompt


def test_system_prompt_contains_persona():
    """System prompt must contain a defined coaching persona."""
    assert "Zuralog" in SYSTEM_PROMPT
    assert "coach" in SYSTEM_PROMPT.lower()


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
    """build_system_prompt() default includes balanced persona and medium proactivity."""
    result = build_system_prompt()
    assert SYSTEM_PROMPT in result
    assert "Medium Proactivity" in result


def test_build_system_prompt_with_suffix():
    """build_system_prompt() with suffix appends user context."""
    suffix = "\nUser Goal: Lose 5kg. Tone: Gentle."
    result = build_system_prompt(user_context_suffix=suffix)
    assert SYSTEM_PROMPT in result
    assert "Lose 5kg" in result
    assert "Gentle" in result


class TestUserProfileInjection:
    def test_display_name_appears_in_prompt(self) -> None:
        profile = UserProfile(
            display_name="Alex",
            goals=["weight_loss", "sleep"],
            fitness_level="active",
            units_system="metric",
            timezone="America/New_York",
            birthday=None,
            height_cm=None,
        )
        prompt = build_system_prompt(user_profile=profile)
        assert "Alex" in prompt

    def test_goals_appear_in_prompt(self) -> None:
        profile = UserProfile(
            display_name=None,
            goals=["marathon", "strength"],
            fitness_level=None,
            units_system="metric",
            timezone="UTC",
            birthday=None,
            height_cm=None,
        )
        prompt = build_system_prompt(user_profile=profile)
        assert "marathon" in prompt
        assert "strength" in prompt

    def test_age_computed_from_birthday(self) -> None:
        # Birthday exactly 30 years ago today
        today = date.today()
        bday = date(today.year - 30, today.month, today.day)
        profile = UserProfile(
            display_name=None,
            goals=[],
            fitness_level=None,
            units_system="metric",
            timezone="UTC",
            birthday=bday,
            height_cm=None,
        )
        prompt = build_system_prompt(user_profile=profile)
        assert "30" in prompt

    def test_null_optional_fields_do_not_appear(self) -> None:
        profile = UserProfile(
            display_name=None,
            goals=[],
            fitness_level=None,
            units_system="metric",
            timezone="UTC",
            birthday=None,
            height_cm=None,
        )
        prompt = build_system_prompt(user_profile=profile)
        # Name, Age, Height, Fitness level must not appear
        assert "Name:" not in prompt
        assert "Age:" not in prompt
        assert "Height:" not in prompt
        assert "Fitness level:" not in prompt

    def test_units_and_timezone_always_appear_when_profile_provided(self) -> None:
        profile = UserProfile(
            display_name=None,
            goals=[],
            fitness_level=None,
            units_system="imperial",
            timezone="Europe/London",
            birthday=None,
            height_cm=None,
        )
        prompt = build_system_prompt(user_profile=profile)
        assert "imperial" in prompt
        assert "Europe/London" in prompt

    def test_no_profile_does_not_break_prompt(self) -> None:
        prompt = build_system_prompt(user_profile=None)
        assert "About This User" not in prompt

    def test_profile_injected_before_memories(self) -> None:
        profile = UserProfile(
            display_name="Jordan",
            goals=["fitness"],
            fitness_level="athletic",
            units_system="metric",
            timezone="UTC",
            birthday=None,
            height_cm=None,
        )
        prompt = build_system_prompt(
            user_profile=profile,
            memories=["User ran a 5K last week"],
        )
        profile_pos = prompt.index("About This User")
        memory_pos = prompt.index("User ran a 5K last week")
        assert profile_pos < memory_pos
