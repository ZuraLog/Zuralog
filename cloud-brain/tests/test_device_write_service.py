"""
Zuralog Cloud Brain — Device Write Service Tests.

Tests the cloud-to-device write flow: constructing FCM payloads,
sending silent pushes, and handling offline devices.
"""

from unittest.mock import MagicMock

import pytest

from app.services.device_write_service import DeviceWriteService


@pytest.fixture
def mock_push_service():
    """Create a mocked PushService."""
    service = MagicMock()
    service.is_available = True
    service.send_data_message = MagicMock(return_value="msg-id-123")
    return service


@pytest.fixture
def write_service(mock_push_service):
    """Create a DeviceWriteService with mocked dependencies."""
    return DeviceWriteService(push_service=mock_push_service)


@pytest.mark.asyncio
async def test_send_write_request_success(write_service, mock_push_service):
    """Should construct and send an FCM data message."""
    result = await write_service.send_write_request(
        device_token="token-abc",
        data_type="nutrition",
        value={"calories": 500, "meal": "lunch"},
    )
    assert result["success"] is True
    mock_push_service.send_data_message.assert_called_once()
    call_args = mock_push_service.send_data_message.call_args
    assert call_args[1]["token"] == "token-abc"
    payload = call_args[1]["data"]
    assert payload["action"] == "write_health"
    assert payload["data_type"] == "nutrition"
    assert "value" in payload


@pytest.mark.asyncio
async def test_send_write_request_fcm_unavailable(mock_push_service):
    """Should return error when FCM is not configured."""
    mock_push_service.is_available = False
    service = DeviceWriteService(push_service=mock_push_service)
    result = await service.send_write_request(
        device_token="token",
        data_type="steps",
        value={"count": 100},
    )
    assert result["success"] is False
    assert "not configured" in result["error"].lower()


@pytest.mark.asyncio
async def test_send_write_request_fcm_send_fails(write_service, mock_push_service):
    """Should return error when FCM send returns None."""
    mock_push_service.send_data_message.return_value = None
    result = await write_service.send_write_request(
        device_token="token",
        data_type="steps",
        value={"count": 100},
    )
    assert result["success"] is False
    assert "could not reach" in result["error"].lower()


@pytest.mark.asyncio
async def test_payload_values_are_strings(write_service, mock_push_service):
    """FCM data values must all be strings."""
    await write_service.send_write_request(
        device_token="token",
        data_type="weight",
        value={"kg": 75.5},
    )
    call_data = mock_push_service.send_data_message.call_args[1]["data"]
    for key, val in call_data.items():
        assert isinstance(val, str), f"Key '{key}' has non-string value: {type(val)}"
