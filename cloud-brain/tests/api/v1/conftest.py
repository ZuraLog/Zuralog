"""
conftest for tests/api/v1/ — typed quick-log endpoint tests.

IMPORTANT: This file must be loaded by pytest BEFORE the parent
tests/api/conftest.py runs its module stubs.  pytest collects
conftest.py files from the root outward, so this inner conftest
is processed first.

We pre-import the real quick_log_routes module here so that the
parent conftest's stub check (``if module_path in sys.modules``)
finds it already present and skips the stub entirely.  Without
this, the parent conftest would replace the real router with a
no-op stub and every endpoint test would receive a 404.
"""

from __future__ import annotations

# Pre-load the real quick_log_routes before any stub can replace it.
import app.api.v1.quick_log_routes  # noqa: F401
import app.models.quick_log  # noqa: F401
