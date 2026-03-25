"""Tests for A-3: window_size must be included in metric_trend cache key.

Verifies two things:
1. CacheService.make_key produces distinct keys when window_size differs
   (unit test — proves the plumbing works regardless of decorator).
2. The @cached decorator on metric_trend declares window_size in key_params
   (structural test — reads the decorator argument via function inspection).
"""

import inspect
import re


def test_make_key_differs_with_different_window_size():
    """Different window_size values must produce different cache keys."""
    from app.services.cache_service import CacheService

    key_7 = CacheService.make_key("analytics.trend", "user-abc", "steps", "7")
    key_30 = CacheService.make_key("analytics.trend", "user-abc", "steps", "30")

    assert key_7 != key_30, (
        "Cache keys for window_size=7 and window_size=30 must differ, "
        f"but both produced: {key_7!r}"
    )


def test_make_key_same_window_size_is_stable():
    """Same inputs must always produce the same cache key."""
    from app.services.cache_service import CacheService

    key_a = CacheService.make_key("analytics.trend", "user-abc", "steps", "7")
    key_b = CacheService.make_key("analytics.trend", "user-abc", "steps", "7")

    assert key_a == key_b


def test_metric_trend_decorator_includes_window_size():
    """The @cached decorator on metric_trend must list window_size in key_params.

    Strategy: read the source of analytics.py and assert the decorator line
    for metric_trend includes 'window_size'. This is the simplest approach
    that does not require spinning up FastAPI or a real cache.
    """
    import app.api.v1.analytics as analytics_module

    source = inspect.getsource(analytics_module)

    # Find the @cached decorator immediately before `async def metric_trend`
    # Pattern: @cached(...key_params=[...]...) followed (possibly with newline) by
    # async def metric_trend
    pattern = re.compile(
        r'@cached\([^)]*key_params=\[([^\]]*)\][^)]*\)\s*\nasync def metric_trend',
        re.DOTALL,
    )
    match = pattern.search(source)
    assert match is not None, (
        "Could not find @cached decorator before metric_trend. "
        "Make sure the decorator is on the line immediately before the function definition."
    )

    key_params_str = match.group(1)
    assert "window_size" in key_params_str, (
        f"window_size is missing from metric_trend key_params. "
        f"Found key_params: [{key_params_str}]"
    )
