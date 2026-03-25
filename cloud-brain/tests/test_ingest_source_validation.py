"""Tests for S-5: source field must only accept known literal values.

The HealthIngestRequest.source field must be restricted to
["apple_health", "health_connect"] and reject any other string.
"""

import pytest
from pydantic import ValidationError

from app.api.v1.health_ingest_schemas import HealthIngestRequest


def test_apple_health_is_valid():
    """source='apple_health' must be accepted."""
    req = HealthIngestRequest(source="apple_health")
    assert req.source == "apple_health"


def test_health_connect_is_valid():
    """source='health_connect' must be accepted."""
    req = HealthIngestRequest(source="health_connect")
    assert req.source == "health_connect"


def test_default_source_is_apple_health():
    """Omitting source must default to 'apple_health'."""
    req = HealthIngestRequest()
    assert req.source == "apple_health"


def test_evil_source_raises_validation_error():
    """source='evil_source' must raise ValidationError."""
    with pytest.raises(ValidationError):
        HealthIngestRequest(source="evil_source")


def test_arbitrary_string_raises_validation_error():
    """Any arbitrary unknown source string must raise ValidationError."""
    with pytest.raises(ValidationError):
        HealthIngestRequest(source="garmin")


def test_empty_string_raises_validation_error():
    """An empty string source must raise ValidationError."""
    with pytest.raises(ValidationError):
        HealthIngestRequest(source="")


def test_case_sensitive_rejection():
    """Source validation is case-sensitive — 'Apple_Health' is not valid."""
    with pytest.raises(ValidationError):
        HealthIngestRequest(source="Apple_Health")
