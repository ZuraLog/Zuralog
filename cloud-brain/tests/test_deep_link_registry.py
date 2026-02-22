"""Tests for the DeepLinkRegistry static lookup class.

Verifies that all supported apps and actions resolve to correct deep
link URLs, that callable entries (e.g. search with query) interpolate
properly, and that unknown apps/actions return ``None`` or empty lists.
"""

from app.mcp_servers.deep_link_registry import DeepLinkRegistry


class TestDeepLinkRegistry:
    """Exhaustive coverage of every registry lookup path."""

    # ------------------------------------------------------------------
    # Strava deep links
    # ------------------------------------------------------------------

    def test_strava_record_returns_deep_link(self) -> None:
        result = DeepLinkRegistry.get_deep_link("strava", "record")
        assert result == "strava://record"

    def test_strava_home_returns_deep_link(self) -> None:
        result = DeepLinkRegistry.get_deep_link("strava", "home")
        assert result == "strava://home"

    # ------------------------------------------------------------------
    # Cal.ai deep links
    # ------------------------------------------------------------------

    def test_calai_camera_returns_deep_link(self) -> None:
        result = DeepLinkRegistry.get_deep_link("calai", "camera")
        assert result == "calai://camera"

    def test_calai_search_with_query(self) -> None:
        result = DeepLinkRegistry.get_deep_link("calai", "search", query="coffee")
        assert result == "calai://search?q=coffee"

    def test_calai_search_without_query(self) -> None:
        result = DeepLinkRegistry.get_deep_link("calai", "search")
        assert result == "calai://search?q="

    # ------------------------------------------------------------------
    # Unsupported app / action
    # ------------------------------------------------------------------

    def test_unsupported_app_returns_none(self) -> None:
        result = DeepLinkRegistry.get_deep_link("unknown_app", "record")
        assert result is None

    def test_unsupported_action_returns_none(self) -> None:
        result = DeepLinkRegistry.get_deep_link("strava", "unknown_action")
        assert result is None

    # ------------------------------------------------------------------
    # Fallback URLs
    # ------------------------------------------------------------------

    def test_get_fallback_url_strava(self) -> None:
        result = DeepLinkRegistry.get_fallback_url("strava")
        assert result == "https://www.strava.com"

    def test_get_fallback_url_calai(self) -> None:
        result = DeepLinkRegistry.get_fallback_url("calai")
        assert result == "https://www.calai.app"

    def test_get_fallback_url_unknown(self) -> None:
        result = DeepLinkRegistry.get_fallback_url("unknown")
        assert result is None

    # ------------------------------------------------------------------
    # Discovery helpers
    # ------------------------------------------------------------------

    def test_get_supported_apps(self) -> None:
        apps = DeepLinkRegistry.get_supported_apps()
        assert "strava" in apps
        assert "calai" in apps

    def test_get_supported_actions(self) -> None:
        actions = DeepLinkRegistry.get_supported_actions("strava")
        assert "record" in actions
        assert "home" in actions

    def test_get_supported_actions_unknown_app(self) -> None:
        actions = DeepLinkRegistry.get_supported_actions("unknown")
        assert actions == []
