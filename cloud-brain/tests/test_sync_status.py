"""
Zuralog Cloud Brain — Sync Status Tracking Tests.

Tests that the Integration model has the required sync status fields
and that the SyncStatus enum values are valid.
"""

from app.models.integration import Integration, SyncStatus


def test_sync_status_enum_values():
    """SyncStatus enum should have idle, syncing, error values."""
    assert SyncStatus.IDLE == "idle"
    assert SyncStatus.SYNCING == "syncing"
    assert SyncStatus.ERROR == "error"


def test_integration_has_sync_fields():
    """Integration model should have sync_status and sync_error columns."""
    column_names = [col.name for col in Integration.__table__.columns]
    assert "sync_status" in column_names
    assert "sync_error" in column_names


def test_integration_sync_status_default():
    """sync_status should default to 'idle'."""
    integration = Integration(
        user_id="test-user",
        provider="strava",
    )
    assert integration.sync_status == SyncStatus.IDLE


def test_integration_sync_error_nullable():
    """sync_error should be nullable."""
    col = Integration.__table__.columns["sync_error"]
    assert col.nullable is True
