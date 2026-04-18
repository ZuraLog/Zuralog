"""Unit tests for food_image_service."""
import pytest

from app.services.food_image_service import normalise_query


class TestNormaliseQuery:
    def test_lowercases(self):
        assert normalise_query("EGGS") == "eggs"

    def test_collapses_whitespace(self):
        assert normalise_query("eggs   and   toast") == "eggs and toast"

    def test_strips_leading_trailing_whitespace(self):
        assert normalise_query("   eggs  ") == "eggs"

    def test_strips_punctuation_except_hyphen(self):
        assert normalise_query("Eggs & Toast!") == "eggs toast"
        assert normalise_query("low-carb bagel") == "low-carb bagel"

    def test_collapses_after_punctuation_strip(self):
        # "Eggs , Toast" -> "eggs  toast" -> "eggs toast"
        assert normalise_query("Eggs , Toast") == "eggs toast"

    def test_empty_returns_empty(self):
        assert normalise_query("") == ""
        assert normalise_query("   ") == ""
