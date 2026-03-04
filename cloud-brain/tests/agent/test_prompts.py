"""
Zuralog Cloud Brain — Tests for Coaching Personas and build_system_prompt.

Validates that:
- Each persona contains language appropriate to its coaching style.
- ``build_system_prompt`` correctly assembles the full prompt from its
  component parts (persona text, proactivity modifier, memories,
  connected integrations).
- Invalid persona / proactivity keys raise ``ValueError``.
"""

from __future__ import annotations

import pytest

from app.agent.prompts.personas import (
    PERSONAS,
    PROACTIVITY_MODIFIERS,
    build_system_prompt,
)


# ---------------------------------------------------------------------------
# Persona content tests
# ---------------------------------------------------------------------------


class TestToughLovePersona:
    """Tough Love persona should contain direct, harsh coaching language."""

    def test_contains_direct_language(self) -> None:
        """Persona contains 'direct' or equivalent no-nonsense phrasing."""
        text = PERSONAS["tough_love"].lower()
        # The persona should reference directness
        assert "direct" in text or "blunt" in text or "no-nonsense" in text

    def test_contains_accountability_language(self) -> None:
        """Persona references holding users accountable."""
        text = PERSONAS["tough_love"].lower()
        assert "accountab" in text or "excuses" in text or "standard" in text

    def test_contains_data_driven_language(self) -> None:
        """Persona references using data before making claims."""
        text = PERSONAS["tough_love"].lower()
        assert "data" in text or "metric" in text or "number" in text

    def test_minimum_word_count(self) -> None:
        """Persona is at least 150 words (substantive, not a stub)."""
        words = PERSONAS["tough_love"].split()
        assert len(words) >= 150, f"Tough love persona too short: {len(words)} words"

    def test_contains_medical_disclaimer(self) -> None:
        """Persona must include a medical disclaimer."""
        text = PERSONAS["tough_love"].lower()
        assert "medical" in text or "doctor" in text

    def test_no_empty_praise_rule(self) -> None:
        """Tough love persona should explicitly reject empty praise."""
        text = PERSONAS["tough_love"].lower()
        assert "praise" in text or "mediocr" in text or "sugarcoat" in text


class TestBalancedPersona:
    """Balanced persona should contain supportive, evidence-based language."""

    def test_contains_warm_language(self) -> None:
        """Persona contains warmth / support indicators."""
        text = PERSONAS["balanced"].lower()
        assert "warm" in text or "care" in text or "supportive" in text or "genuine" in text

    def test_contains_honest_language(self) -> None:
        """Persona references honest feedback."""
        text = PERSONAS["balanced"].lower()
        assert "honest" in text or "evidence" in text or "clear" in text

    def test_contains_proportional_praise(self) -> None:
        """Balanced persona calls out proportional, not hollow, praise."""
        text = PERSONAS["balanced"].lower()
        assert "proportion" in text or "celebrate real" in text or "proportional" in text

    def test_minimum_word_count(self) -> None:
        """Persona is at least 150 words."""
        words = PERSONAS["balanced"].split()
        assert len(words) >= 150, f"Balanced persona too short: {len(words)} words"

    def test_contains_medical_disclaimer(self) -> None:
        """Persona must include a medical disclaimer."""
        text = PERSONAS["balanced"].lower()
        assert "medical" in text or "doctor" in text

    def test_references_data_first(self) -> None:
        """Balanced persona requires fetching real data before commenting."""
        text = PERSONAS["balanced"].lower()
        assert "data" in text or "metric" in text


class TestGentlePersona:
    """Gentle persona should contain empathetic, encouraging language."""

    def test_contains_empathy_language(self) -> None:
        """Persona contains empathy and encouragement indicators."""
        text = PERSONAS["gentle"].lower()
        assert "empathetic" in text or "compassion" in text or "kind" in text or "encourage" in text

    def test_celebrates_small_wins(self) -> None:
        """Gentle persona explicitly celebrates small or micro wins."""
        text = PERSONAS["gentle"].lower()
        assert "small" in text or "micro" in text or "mini" in text or "every step" in text

    def test_no_shame_language(self) -> None:
        """Persona explicitly rules out shaming users."""
        text = PERSONAS["gentle"].lower()
        assert "never shame" in text or "shame" in text

    def test_minimum_word_count(self) -> None:
        """Persona is at least 150 words."""
        words = PERSONAS["gentle"].split()
        assert len(words) >= 150, f"Gentle persona too short: {len(words)} words"

    def test_contains_medical_disclaimer(self) -> None:
        """Persona must include a medical disclaimer."""
        text = PERSONAS["gentle"].lower()
        assert "medical" in text or "doctor" in text or "healthcare" in text

    def test_references_progress_over_perfection(self) -> None:
        """Gentle persona values consistency over perfection."""
        text = PERSONAS["gentle"].lower()
        assert "progress" in text or "consistent" in text or "perfection" in text


# ---------------------------------------------------------------------------
# Proactivity modifiers
# ---------------------------------------------------------------------------


class TestProactivityModifiers:
    """Validate that proactivity modifiers exist and have the right intent."""

    def test_all_three_levels_exist(self) -> None:
        """All three proactivity levels are defined."""
        assert "low" in PROACTIVITY_MODIFIERS
        assert "medium" in PROACTIVITY_MODIFIERS
        assert "high" in PROACTIVITY_MODIFIERS

    def test_low_restricts_unsolicited_advice(self) -> None:
        """Low proactivity instructs the AI NOT to surface unsolicited advice."""
        text = PROACTIVITY_MODIFIERS["low"].lower()
        assert "only" in text or "not proactively" in text or "do not" in text

    def test_high_encourages_proactive_suggestions(self) -> None:
        """High proactivity instructs the AI to actively look for opportunities."""
        text = PROACTIVITY_MODIFIERS["high"].lower()
        assert "proactive" in text or "actively" in text or "look for" in text

    def test_medium_is_between_low_and_high(self) -> None:
        """Medium proactivity allows some pattern mentions but not overwhelming."""
        text = PROACTIVITY_MODIFIERS["medium"].lower()
        # Should reference occasional / not overwhelming
        assert "occasional" in text or "briefly" in text or "not overwhelm" in text


# ---------------------------------------------------------------------------
# build_system_prompt tests
# ---------------------------------------------------------------------------


class TestBuildSystemPrompt:
    """Tests for the build_system_prompt factory function."""

    def test_includes_persona_text(self) -> None:
        """Output contains the selected persona's base text."""
        for persona in ("tough_love", "balanced", "gentle"):
            prompt = build_system_prompt(persona=persona, proactivity="medium")
            # The persona text is a substantial substring of the prompt
            assert PERSONAS[persona][:100] in prompt, f"Persona '{persona}' text not found in assembled prompt"

    def test_includes_proactivity_modifier(self) -> None:
        """Output contains the selected proactivity modifier text."""
        for level in ("low", "medium", "high"):
            prompt = build_system_prompt(persona="balanced", proactivity=level)
            assert PROACTIVITY_MODIFIERS[level] in prompt, (
                f"Proactivity '{level}' modifier not found in assembled prompt"
            )

    def test_includes_memories_when_provided(self) -> None:
        """Output contains all provided memory strings."""
        memories = [
            "User has a knee injury from 2024",
            "User's goal is to complete a half-marathon",
        ]
        prompt = build_system_prompt(
            persona="balanced",
            proactivity="medium",
            memories=memories,
        )
        assert "User has a knee injury from 2024" in prompt
        assert "User's goal is to complete a half-marathon" in prompt

    def test_includes_connected_integrations_when_provided(self) -> None:
        """Output lists all provided connected integration names."""
        integrations = ["strava", "apple_health", "fitbit"]
        prompt = build_system_prompt(
            persona="balanced",
            proactivity="medium",
            connected_integrations=integrations,
        )
        assert "strava" in prompt
        assert "apple_health" in prompt
        assert "fitbit" in prompt

    def test_no_memories_section_omits_memory_block(self) -> None:
        """When memories=None, the memory section is not in the prompt."""
        prompt = build_system_prompt(persona="gentle", proactivity="low", memories=None)
        assert "Long-Term Memory" not in prompt

    def test_no_integrations_mentions_not_connected(self) -> None:
        """When connected_integrations=None, prompt notes no integrations."""
        prompt = build_system_prompt(
            persona="gentle",
            proactivity="low",
            connected_integrations=None,
        )
        # Some variation of "not connected" or "no integrations" should appear
        assert "not connected" in prompt.lower() or "not authorised" in prompt.lower() or "not yet" in prompt.lower()

    def test_different_personas_produce_different_prompts(self) -> None:
        """Each persona key produces a uniquely distinct system prompt."""
        prompts = {
            p: build_system_prompt(persona=p, proactivity="medium") for p in ("tough_love", "balanced", "gentle")
        }
        assert prompts["tough_love"] != prompts["balanced"]
        assert prompts["balanced"] != prompts["gentle"]
        assert prompts["tough_love"] != prompts["gentle"]

    def test_empty_memories_list_omits_memory_block(self) -> None:
        """Empty memories list should not inject the memory section."""
        prompt = build_system_prompt(persona="balanced", proactivity="medium", memories=[])
        # Empty list should behave like None
        assert "Long-Term Memory" not in prompt

    def test_default_persona_is_balanced(self) -> None:
        """Calling build_system_prompt() without args uses 'balanced' persona."""
        prompt = build_system_prompt()
        assert PERSONAS["balanced"][:50] in prompt

    def test_default_proactivity_is_medium(self) -> None:
        """Calling build_system_prompt() without args uses 'medium' proactivity."""
        prompt = build_system_prompt()
        assert PROACTIVITY_MODIFIERS["medium"] in prompt


# ---------------------------------------------------------------------------
# Validation — unknown keys raise ValueError
# ---------------------------------------------------------------------------


class TestValidation:
    """Unknown persona or proactivity keys must raise ValueError."""

    def test_unknown_persona_raises_value_error(self) -> None:
        """Passing an unrecognised persona key raises ValueError."""
        with pytest.raises(ValueError, match="Unknown persona"):
            build_system_prompt(persona="drill_sergeant", proactivity="medium")

    def test_unknown_proactivity_raises_value_error(self) -> None:
        """Passing an unrecognised proactivity key raises ValueError."""
        with pytest.raises(ValueError, match="Unknown proactivity"):
            build_system_prompt(persona="balanced", proactivity="maximum_overdrive")

    def test_empty_persona_string_raises_value_error(self) -> None:
        """Empty string persona key raises ValueError."""
        with pytest.raises(ValueError):
            build_system_prompt(persona="", proactivity="medium")

    def test_empty_proactivity_string_raises_value_error(self) -> None:
        """Empty string proactivity key raises ValueError."""
        with pytest.raises(ValueError):
            build_system_prompt(persona="balanced", proactivity="")

    def test_case_sensitive_persona_validation(self) -> None:
        """Persona keys are case-sensitive — 'Balanced' is invalid."""
        with pytest.raises(ValueError):
            build_system_prompt(persona="Balanced", proactivity="medium")

    def test_case_sensitive_proactivity_validation(self) -> None:
        """Proactivity keys are case-sensitive — 'Low' is invalid."""
        with pytest.raises(ValueError):
            build_system_prompt(persona="balanced", proactivity="Low")
