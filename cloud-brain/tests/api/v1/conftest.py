"""
conftest for tests/api/v1/.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest

import app.models.quick_log  # noqa: F401


@pytest.fixture(autouse=True)
def disable_slowapi_for_direct_calls():
    """Disable the slowapi rate-limiter for tests that call route handlers directly.

    Tests that invoke route coroutines directly (bypassing the HTTP stack) pass
    MagicMock objects as the ``request`` parameter.  slowapi's decorator checks
    ``isinstance(request, starlette.requests.Request)`` and raises if it is not.
    Disabling the limiter here lets those tests run without a real ASGI request.
    """
    with patch("app.limiter.limiter.enabled", False):
        yield
