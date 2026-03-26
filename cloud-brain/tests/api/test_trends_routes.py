"""Tests for Trends API endpoints and helper functions."""
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.api.v1.trends_routes import (
    _make_pattern_id,
    _parse_pattern_id,
    _make_headline,
    _make_body,
)

TEST_USER_ID = str(uuid.uuid4())
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_auth():
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    yield
    app.dependency_overrides.pop(get_authenticated_user_id, None)


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.execute = AsyncMock()
    db.execute.return_value.fetchall = MagicMock(return_value=[])
    db.execute.return_value.scalar_one_or_none = MagicMock(return_value=None)
    db.execute.return_value.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


@pytest.fixture
def client(mock_auth, mock_db):
    return TestClient(app)


def _make_brief(data_maturity_days: int):
    """Create a minimal HealthBrief stub for testing."""
    brief = MagicMock()
    brief.data_maturity_days = data_maturity_days
    return brief


# ---------------------------------------------------------------------------
# Unit tests — helper functions (no DB, no async)
# ---------------------------------------------------------------------------


def test_make_pattern_id_basic():
    assert _make_pattern_id("sleep_hours", "steps") == "corr_sleep_hours_steps"


def test_parse_pattern_id_basic():
    assert _parse_pattern_id("corr_sleep_hours_steps") == ("sleep_hours", "steps")


def test_parse_pattern_id_multiword_metrics():
    result = _parse_pattern_id("corr_hrv_ms_resting_heart_rate")
    assert result == ("hrv_ms", "resting_heart_rate")


def test_parse_pattern_id_invalid_format():
    assert _parse_pattern_id("invalid") is None


def test_parse_pattern_id_unknown_metric():
    # "unknown_metric" is not in _SIGNAL_METRIC_TO_DB_TYPE so returns None
    assert _parse_pattern_id("corr_unknown_metric_steps") is None


def test_parse_pattern_id_longest_match_first():
    # sleep_hours and sleep_quality share the "sleep" prefix.
    # sorted longest-first means sleep_hours/sleep_quality are tried before
    # any shorter hypothetical "sleep" key, so existing IDs parse correctly.
    assert _parse_pattern_id("corr_sleep_hours_steps") == ("sleep_hours", "steps")
    assert _parse_pattern_id("corr_sleep_quality_resting_heart_rate") == ("sleep_quality", "resting_heart_rate")


def test_make_headline_strong_positive():
    result = _make_headline("sleep_hours", "steps", 0.75)
    assert "strongly" in result


def test_make_headline_moderate_positive():
    result = _make_headline("sleep_hours", "steps", 0.5)
    assert "linked" in result


def test_make_headline_strong_negative():
    result = _make_headline("hrv_ms", "resting_heart_rate", -0.8)
    assert "less" in result


def test_make_headline_weak_correlation():
    result = _make_headline("sleep_hours", "steps", 0.3)
    assert "affect" in result.lower() or "may" in result.lower()


def test_make_body_lag_and_moderate():
    result = _make_body("sleep_hours", "steps", 0.6, 1)
    assert "following day" in result
    assert "moderate" in result


def test_make_body_strong_and_inverse():
    result = _make_body("hrv_ms", "active_calories", -0.75, 0)
    assert "strong" in result
    assert "inverse" in result


# ---------------------------------------------------------------------------
# Integration tests — endpoints
# ---------------------------------------------------------------------------


def test_trends_home_low_maturity_returns_empty_scaffold(client):
    """When the user has fewer than 7 days of data, the response should
    indicate not enough data and return no correlation cards."""
    from app.analytics.health_brief_builder import HealthBrief

    mock_brief = MagicMock(spec=HealthBrief)
    mock_brief.data_maturity_days = 3

    with patch(
        "app.api.v1.trends_routes.HealthBriefBuilder"
    ) as MockBuilder:
        instance = AsyncMock()
        instance.build = AsyncMock(return_value=mock_brief)
        MockBuilder.return_value = instance

        resp = client.get("/api/v1/trends/home", headers=AUTH_HEADER)

    assert resp.status_code == 200
    data = resp.json()
    assert data["has_enough_data"] is False
    assert data["correlation_highlights"] == []


def test_trends_home_returns_cards_when_signals_detected(client):
    """When the builder returns mature data and the detector finds a
    correlation signal, the response should include that card."""
    from app.analytics.health_brief_builder import HealthBrief
    from app.analytics.insight_signal_detector import InsightSignal

    mock_brief = MagicMock(spec=HealthBrief)
    mock_brief.data_maturity_days = 30

    signal = InsightSignal(
        signal_type="correlation_discovery",
        category="D",
        metrics=["sleep_hours", "steps"],
        values={"correlation": 0.72, "lag_days": 1},
        severity=3,
        actionable=False,
        focus_relevant=False,
        title_hint="sleep hours linked to steps",
    )

    with patch(
        "app.api.v1.trends_routes.HealthBriefBuilder"
    ) as MockBuilder, patch(
        "app.api.v1.trends_routes.InsightSignalDetector"
    ) as MockDetector:
        builder_instance = AsyncMock()
        builder_instance.build = AsyncMock(return_value=mock_brief)
        MockBuilder.return_value = builder_instance

        detector_instance = MagicMock()
        detector_instance.detect_correlations = MagicMock(return_value=[signal])
        MockDetector.return_value = detector_instance

        resp = client.get("/api/v1/trends/home", headers=AUTH_HEADER)

    assert resp.status_code == 200
    data = resp.json()
    assert data["has_enough_data"] is True
    assert data["has_correlations"] is True
    assert data["pattern_count"] == 1
    assert len(data["correlation_highlights"]) == 1
    highlight = data["correlation_highlights"][0]
    assert highlight["id"] == "corr_sleep_hours_steps"
    assert highlight["direction"] == "positive"
    assert highlight["category"] == "sleep"


def test_trends_pattern_expand_invalid_format_returns_404(client):
    """A pattern ID that cannot be parsed should return 404."""
    resp = client.get("/api/v1/trends/pattern/invalid_format/expand", headers=AUTH_HEADER)
    assert resp.status_code == 404


def test_trends_metrics_returns_metric_types_from_db(client, mock_db):
    """The metrics endpoint should return the list of metric types
    pulled from the user's daily_summaries rows in the database."""
    metric_types = ["active_calories", "hrv_ms", "sleep_duration", "steps"]
    mock_rows = [SimpleNamespace(metric_type=m) for m in metric_types]
    mock_db.execute.return_value.fetchall = MagicMock(return_value=mock_rows)

    resp = client.get("/api/v1/trends/metrics", headers=AUTH_HEADER)

    assert resp.status_code == 200
    data = resp.json()
    assert data["metrics"] == metric_types


def test_trends_home_mature_data_but_no_signals(client, mock_db):
    """Mature data with zero correlation signals: has_enough_data=True, has_correlations=False."""
    brief = _make_brief(data_maturity_days=30)
    with (
        patch("app.api.v1.trends_routes.HealthBriefBuilder") as mock_builder,
        patch("app.api.v1.trends_routes.InsightSignalDetector") as mock_detector,
    ):
        mock_builder.return_value.build = AsyncMock(return_value=brief)
        mock_detector.return_value.detect_correlations.return_value = []  # no signals at all

        response = client.get("/api/v1/trends/home", headers=AUTH_HEADER)

    assert response.status_code == 200
    data = response.json()
    assert data["has_enough_data"] is True
    assert data["has_correlations"] is False
    assert data["correlation_highlights"] == []
    assert data["pattern_count"] == 0


def test_trends_home_requires_auth():
    response = TestClient(app).get("/api/v1/trends/home")
    assert response.status_code in (401, 403)


def test_trends_metrics_requires_auth():
    response = TestClient(app).get("/api/v1/trends/metrics")
    assert response.status_code in (401, 403)


def test_trends_pattern_expand_requires_auth():
    response = TestClient(app).get("/api/v1/trends/pattern/corr_sleep_hours_steps/expand")
    assert response.status_code in (401, 403)


def test_trends_correlation_rejects_invalid_metric(client, mock_auth, mock_db):
    response = client.get(
        "/api/v1/trends/correlation?metric_a=evil_input&metric_b=steps&days=30",
        headers=AUTH_HEADER,
    )
    assert response.status_code == 400


def test_trends_correlation_uses_fixed_response_keys(client, mock_auth, mock_db):
    """Data points from the /correlation endpoint use a_value/b_value keys."""
    row1 = SimpleNamespace(date="2026-01-01", metric_a_value=7.5, metric_b_value=8000.0)
    row2 = SimpleNamespace(date="2026-01-02", metric_a_value=6.0, metric_b_value=6500.0)
    mock_db.execute.return_value.fetchall = MagicMock(return_value=[row1, row2])
    mock_db.execute.return_value.scalar_one_or_none = MagicMock(return_value=None)

    response = client.get(
        "/api/v1/trends/correlation?metric_a=sleep_hours&metric_b=steps&days=30",
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    data = response.json()
    assert len(data["data_points"]) == 2
    assert "a_value" in data["data_points"][0]
    assert "b_value" in data["data_points"][0]


def test_trends_home_discovered_at_is_null(client, mock_auth, mock_db):
    """Correlation highlights returned by the home endpoint have discovered_at == None."""
    from app.analytics.health_brief_builder import HealthBrief
    from app.analytics.insight_signal_detector import InsightSignal

    mock_brief = MagicMock(spec=HealthBrief)
    mock_brief.data_maturity_days = 30

    signal = InsightSignal(
        signal_type="correlation_discovery",
        category="D",
        metrics=["sleep_hours", "steps"],
        values={"correlation": 0.72, "lag_days": 1},
        severity=3,
        actionable=False,
        focus_relevant=False,
        title_hint="sleep hours linked to steps",
    )

    with patch(
        "app.api.v1.trends_routes.HealthBriefBuilder"
    ) as MockBuilder, patch(
        "app.api.v1.trends_routes.InsightSignalDetector"
    ) as MockDetector:
        builder_instance = AsyncMock()
        builder_instance.build = AsyncMock(return_value=mock_brief)
        MockBuilder.return_value = builder_instance

        detector_instance = MagicMock()
        detector_instance.detect_correlations = MagicMock(return_value=[signal])
        MockDetector.return_value = detector_instance

        resp = client.get("/api/v1/trends/home", headers=AUTH_HEADER)

    assert resp.status_code == 200
    data = resp.json()
    highlights = data["correlation_highlights"]
    assert len(highlights) >= 1
    assert all(h["discovered_at"] is None for h in highlights)
