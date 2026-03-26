"""Tests that journal POST and PUT trigger the checkin streak.

Verifies StreakTracker.record_activity is called with streak_type="checkin"
on both create (POST) and update (PUT) journal operations.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


# ---------------------------------------------------------------------------
# We test the route handler functions directly rather than via the HTTP layer.
# The top-level conftest stubs out journal_routes on the app object to avoid
# Python 3.14 annotation evaluation issues, but direct imports of the module
# work fine for unit testing the handler logic.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_journal_entry_triggers_checkin_streak():
    """POST journal upsert calls StreakTracker with streak_type='checkin'."""
    # Import the handler directly — bypasses HTTP stack and conftest stubs.
    from app.api.v1.journal_routes import create_journal_entry
    from app.api.v1.journal_routes import JournalEntryCreate

    mock_db = AsyncMock()

    # Simulate "no existing entry" so a new one is created.
    no_result = MagicMock()
    no_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=no_result)
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()

    # Simulate db.refresh setting entry.date
    fake_entry = MagicMock()
    fake_entry.id = "entry-001"
    fake_entry.user_id = "user-001"
    fake_entry.date = "2026-03-25"
    fake_entry.notes = "Good day"
    fake_entry.tags = []
    fake_entry.source = "diary"
    fake_entry.conversation_id = None
    fake_entry.created_at = None

    async def _refresh(obj):
        # Replace the object's internals with fake_entry attributes
        for attr in ("id", "user_id", "date", "notes", "tags", "source",
                     "conversation_id", "created_at"):
            setattr(obj, attr, getattr(fake_entry, attr))

    mock_db.refresh = _refresh

    body = JournalEntryCreate(
        date="2026-03-25",
        content="Good day",
        tags=[],
    )

    with patch(
        "app.api.v1.journal_routes.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(return_value=MagicMock())
        MockTracker.return_value = instance

        await create_journal_entry(body=body, user_id="user-001", db=mock_db)

    instance.record_activity.assert_called_once()
    call_kwargs = instance.record_activity.call_args.kwargs
    assert call_kwargs["streak_type"] == "checkin"
    assert call_kwargs["user_id"] == "user-001"
    assert call_kwargs["activity_date"] == date(2026, 3, 25)


@pytest.mark.asyncio
async def test_update_journal_entry_triggers_checkin_streak():
    """PUT journal replacement calls StreakTracker with streak_type='checkin'."""
    from app.api.v1.journal_routes import update_journal_entry
    from app.api.v1.journal_routes import JournalEntryCreate

    mock_db = AsyncMock()

    fake_entry = MagicMock()
    fake_entry.id = "entry-002"
    fake_entry.user_id = "user-001"
    fake_entry.date = "2026-03-24"
    fake_entry.notes = "Updated"
    fake_entry.tags = []
    fake_entry.source = "diary"
    fake_entry.conversation_id = None
    fake_entry.created_at = None

    found_result = MagicMock()
    found_result.scalar_one_or_none.return_value = fake_entry
    mock_db.execute = AsyncMock(return_value=found_result)
    mock_db.commit = AsyncMock()

    async def _refresh(obj):
        pass  # entry is already a MagicMock with all fields set

    mock_db.refresh = _refresh

    body = JournalEntryCreate(
        date="2026-03-24",
        content="Updated",
        tags=[],
    )

    with patch(
        "app.api.v1.journal_routes.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(return_value=MagicMock())
        MockTracker.return_value = instance

        await update_journal_entry(
            entry_id="entry-002", body=body, user_id="user-001", db=mock_db
        )

    instance.record_activity.assert_called_once()
    call_kwargs = instance.record_activity.call_args.kwargs
    assert call_kwargs["streak_type"] == "checkin"
    assert call_kwargs["activity_date"] == date(2026, 3, 24)


@pytest.mark.asyncio
async def test_journal_streak_failure_does_not_block_response():
    """A StreakTracker error on journal POST must not propagate."""
    from app.api.v1.journal_routes import create_journal_entry
    from app.api.v1.journal_routes import JournalEntryCreate

    mock_db = AsyncMock()

    no_result = MagicMock()
    no_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=no_result)
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()

    fake_entry = MagicMock()
    fake_entry.id = "entry-003"
    fake_entry.user_id = "user-001"
    fake_entry.date = "2026-03-25"
    fake_entry.notes = "Hello"
    fake_entry.tags = []
    fake_entry.source = "diary"
    fake_entry.conversation_id = None
    fake_entry.created_at = None

    async def _refresh(obj):
        for attr in ("id", "user_id", "date", "notes", "tags", "source",
                     "conversation_id", "created_at"):
            setattr(obj, attr, getattr(fake_entry, attr))

    mock_db.refresh = _refresh

    body = JournalEntryCreate(date="2026-03-25", content="Hello")

    with patch(
        "app.api.v1.journal_routes.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(side_effect=RuntimeError("streak DB error"))
        MockTracker.return_value = instance

        # Should not raise
        result = await create_journal_entry(body=body, user_id="user-001", db=mock_db)

    assert result["date"] == "2026-03-25"
