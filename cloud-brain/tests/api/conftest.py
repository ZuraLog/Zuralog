"""
Local conftest for API-level tests.

The root conftest unconditionally imports ``app.main``, which in turn imports
``journal_routes`` — a pre-existing file with a Python 3.14 / Pydantic
incompatibility.  We stub that router before ``app.main`` is imported so the
test suite can still exercise our new preferences and health-score routes.
"""

from __future__ import annotations

import sys
import types
from unittest.mock import MagicMock


def _stub_router_module(module_path: str) -> None:
    """Insert a stub module with a no-op ``router`` into ``sys.modules``.

    Args:
        module_path: Dotted module path to stub (e.g.
            ``"app.api.v1.journal_routes"``).
    """
    if module_path in sys.modules:
        return
    stub = types.ModuleType(module_path)
    stub.router = MagicMock()
    sys.modules[module_path] = stub


# Stub the broken Phase-2 routes that fail on Python 3.14 before app.main loads.
# journal_routes no longer needs stubbing — it loads cleanly after streak integration.
_stub_router_module("app.api.v1.achievement_routes")
_stub_router_module("app.api.v1.streak_routes")
# quick_log_routes no longer needs stubbing — it loads cleanly on Python 3.14.
_stub_router_module("app.api.v1.emergency_card_routes")

# Also stub dependent models so the stubs don't cascade.
for _m in (
    # app.models.journal_entry no longer needs stubbing.
    "app.models.achievement",
    "app.models.streak",
    # app.models.quick_log no longer needs stubbing.
    "app.models.emergency_card",
):
    if _m not in sys.modules:
        _stub = types.ModuleType(_m)
        sys.modules[_m] = _stub
