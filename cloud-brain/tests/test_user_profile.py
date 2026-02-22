"""
Life Logger Cloud Brain — User Profile Manager Tests.

Tests for the dynamic system prompt suffix generation.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.agent.context_manager.user_profile_service import UserProfileService


@pytest.fixture
def mock_session():
    """Create a mocked async DB session."""
    return AsyncMock()


@pytest.fixture
def profile_service(mock_session):
    """Create a UserProfileService with mocked DB."""
    return UserProfileService(session=mock_session)


@pytest.mark.asyncio
async def test_get_system_prompt_suffix_tough_love(profile_service, mock_session):
    """Tough love persona should produce a tough prompt suffix."""
    mock_result = MagicMock()
    mock_row = {
        "id": "user-1",
        "email": "test@test.com",
        "coach_persona": "tough_love",
        "is_premium": False,
    }
    mock_result.mappings.return_value.first.return_value = mock_row
    mock_session.execute.return_value = mock_result

    suffix = await profile_service.get_system_prompt_suffix("user-1")
    assert isinstance(suffix, str)
    assert "tough" in suffix.lower() or "direct" in suffix.lower()


@pytest.mark.asyncio
async def test_get_system_prompt_suffix_gentle(profile_service, mock_session):
    """Gentle persona should produce a supportive prompt suffix."""
    mock_result = MagicMock()
    mock_row = {
        "id": "user-2",
        "email": "gentle@test.com",
        "coach_persona": "gentle",
        "is_premium": True,
    }
    mock_result.mappings.return_value.first.return_value = mock_row
    mock_session.execute.return_value = mock_result

    suffix = await profile_service.get_system_prompt_suffix("user-2")
    assert "gentle" in suffix.lower() or "supportive" in suffix.lower()


@pytest.mark.asyncio
async def test_get_system_prompt_suffix_not_found(profile_service, mock_session):
    """Missing user should return empty string."""
    mock_result = MagicMock()
    mock_result.mappings.return_value.first.return_value = None
    mock_session.execute.return_value = mock_result

    suffix = await profile_service.get_system_prompt_suffix("ghost-user")
    assert suffix == ""
