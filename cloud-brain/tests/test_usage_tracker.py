"""
Life Logger Cloud Brain — Usage Tracker Service Tests.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.usage_tracker import UsageTracker


@pytest.fixture
def mock_session():
    """Create a mocked async DB session."""
    session = AsyncMock()
    session.add = MagicMock()
    session.commit = AsyncMock()
    return session


@pytest.fixture
def tracker(mock_session):
    """Create a UsageTracker with mocked DB."""
    return UsageTracker(session=mock_session)


@pytest.mark.asyncio
async def test_track_usage(tracker, mock_session):
    """track() should add a usage record to the session."""
    await tracker.track(
        user_id="user-1",
        model="moonshotai/kimi-k2.5",
        input_tokens=100,
        output_tokens=50,
    )
    mock_session.add.assert_called_once()
    mock_session.commit.assert_called_once()


@pytest.mark.asyncio
async def test_track_extracts_from_response(tracker):
    """track_from_response() should parse the OpenAI response usage."""
    mock_response = MagicMock()
    mock_response.usage.prompt_tokens = 200
    mock_response.usage.completion_tokens = 80
    mock_response.model = "moonshotai/kimi-k2.5"

    await tracker.track_from_response("user-1", mock_response)
    assert tracker._session.add.called


@pytest.mark.asyncio
async def test_track_zero_tokens(tracker, mock_session):
    """Zero token usage should still be recorded."""
    await tracker.track(
        user_id="user-1",
        model="moonshotai/kimi-k2.5",
        input_tokens=0,
        output_tokens=0,
    )
    mock_session.add.assert_called_once()
