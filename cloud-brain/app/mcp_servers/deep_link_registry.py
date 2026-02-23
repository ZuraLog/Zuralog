"""
Zuralog Cloud Brain — Deep Link Registry (Phase 1.12).

Data-driven registry that maps (app_name, action) pairs to native deep
link URLs. The Edge Agent uses these URLs to open third-party apps
(Strava, Cal.ai, etc.) directly from LLM-generated action suggestions.

The registry is deliberately static — no instance state, no database.
Adding a new app is a one-line dictionary entry. Callable values are
supported for actions that need query-string interpolation at runtime.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Union

# ---------------------------------------------------------------------------
# Module-level lookup tables
# ---------------------------------------------------------------------------

_REGISTRY: dict[str, dict[str, Union[str, Callable[..., str]]]] = {
    "strava": {
        "record": "strava://record",
        "home": "strava://home",
    },
    "calai": {
        "camera": "calai://camera",
        "search": lambda query="": f"calai://search?q={query}",
    },
}
"""Maps app_name -> {action -> URL or callable(query=...) -> URL}."""

_FALLBACKS: dict[str, str] = {
    "strava": "https://www.strava.com",
    "calai": "https://www.calai.app",
}
"""Maps app_name -> HTTPS fallback URL used when the native scheme fails."""


class DeepLinkRegistry:
    """Pure static lookup class for resolving deep link URLs.

    Consumers call class methods directly — no instantiation required.
    The registry is immutable at runtime; extend it by adding entries
    to ``_REGISTRY`` and ``_FALLBACKS`` above.
    """

    @staticmethod
    def get_deep_link(app_name: str, action: str, *, query: str = "") -> str | None:
        """Resolve a deep link URL for the given app and action.

        If the registry entry is a callable (e.g. for search actions
        that accept a query parameter), it is invoked with ``query``
        to produce the final URL string.

        Args:
            app_name: Lowercase identifier of the target app
                (e.g. ``"strava"``, ``"calai"``).
            action: The in-app action to trigger
                (e.g. ``"record"``, ``"camera"``, ``"search"``).
            query: Optional query string passed to callable entries.

        Returns:
            The deep link URL as a string, or ``None`` if the app or
            action is not registered.
        """
        app_actions = _REGISTRY.get(app_name)
        if app_actions is None:
            return None

        entry = app_actions.get(action)
        if entry is None:
            return None

        if callable(entry):
            return entry(query=query)
        return entry

    @staticmethod
    def get_fallback_url(app_name: str) -> str | None:
        """Return the HTTPS fallback URL for an app.

        The Edge Agent should open this URL in a browser when the
        native deep link scheme is not handled (app not installed).

        Args:
            app_name: Lowercase identifier of the target app.

        Returns:
            The fallback URL, or ``None`` if the app is unknown.
        """
        return _FALLBACKS.get(app_name)

    @staticmethod
    def get_supported_apps() -> list[str]:
        """List all app identifiers that have registered deep links.

        Returns:
            A sorted list of app name strings.
        """
        return sorted(_REGISTRY.keys())

    @staticmethod
    def get_supported_actions(app_name: str) -> list[str]:
        """List all registered actions for a given app.

        Args:
            app_name: Lowercase identifier of the target app.

        Returns:
            A sorted list of action strings, or an empty list if the
            app is not registered.
        """
        app_actions = _REGISTRY.get(app_name)
        if app_actions is None:
            return []
        return sorted(app_actions.keys())
