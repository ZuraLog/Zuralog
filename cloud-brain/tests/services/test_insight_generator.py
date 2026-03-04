"""
Tests for the Insight API routes (GET /api/v1/insights, PATCH /api/v1/insights/{id}).

Validates pagination, type filtering, read/dismiss actions, and auth
enforcement. All database access is mocked — no real DB is required.

Coverage:
    test_insight_list_pagination        — Returns correct page slice.
    test_insight_filter_by_type         — Type query-param filter works.
    test_mark_read_sets_timestamp       — PATCH action=read sets read_at.
    test_mark_dismissed_hides_from_list — Dismissed insights excluded from GET.
    test_auth_required                  — 401/403 without a Bearer token.
"""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.database import get_db
from app.main import app
from app.models.insight import Insight
from app.services.auth_service import AuthService

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

USER_ID = "test-insight-user-001"
AUTH_HEADERS = {"Authorization": "Bearer test-insight-token"}

# A fixed "now" used when checking timestamps
_NOW = datetime(2026, 3, 4, 12, 0, 0, tzinfo=timezone.utc)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_insight(
    insight_id: str = "insight-001",
    insight_type: str = "sleep_analysis",
    priority: int = 3,
    dismissed: bool = False,
    read: bool = False,
) -> MagicMock:
    """Return a MagicMock shaped like an Insight ORM row.

    Args:
        insight_id: UUID string for the insight.
        insight_type: Insight type string (e.g. ``sleep_analysis``).
        priority: Integer priority (1–10).
        dismissed: Whether ``dismissed_at`` is set.
        read: Whether ``read_at`` is set.

    Returns:
        MagicMock with all Insight column attributes populated.
    """
    row = MagicMock(spec=Insight)
    row.id = insight_id
    row.user_id = USER_ID
    row.type = insight_type
    row.title = f"Test {insight_type} card"
    row.body = "Mocked body text for testing."
    row.data = {"source": "mock"}
    row.reasoning = None
    row.priority = priority
    row.created_at = _NOW
    row.read_at = _NOW if read else None
    row.dismissed_at = _NOW if dismissed else None
    return row


# ---------------------------------------------------------------------------
# Shared fixture — TestClient with mocked auth and DB
# ---------------------------------------------------------------------------


@pytest.fixture()
def mock_auth() -> AsyncMock:
    """Mock AuthService that always authenticates as USER_ID."""
    svc = AsyncMock(spec=AuthService)
    svc.get_user.return_value = {"id": USER_ID}
    return svc


@pytest.fixture()
def mock_db() -> AsyncMock:
    """Bare AsyncMock for the SQLAlchemy session."""
    return AsyncMock()


@pytest.fixture()
def client(mock_auth, mock_db):
    """TestClient with overridden auth and DB dependencies.

    Yields:
        tuple: (TestClient, mock_auth, mock_db)
    """
    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_auth, mock_db

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Helpers for wiring DB mock responses
# ---------------------------------------------------------------------------


def _mock_db_list(mock_db: AsyncMock, rows: list, total: int) -> None:
    """Wire mock_db.execute to return total (count) then rows (scalars).

    The GET endpoint issues two queries: a COUNT then a SELECT. We chain
    two side-effect values to cover both calls in order.

    Args:
        mock_db: The mock AsyncSession.
        rows: ORM row mocks that scalars().all() should return.
        total: Integer to return from the COUNT query scalar_one().
    """
    count_result = MagicMock()
    count_result.scalar_one.return_value = total

    rows_result = MagicMock()
    rows_result.scalars.return_value.all.return_value = rows

    mock_db.execute = AsyncMock(side_effect=[count_result, rows_result])


def _mock_db_get(mock_db: AsyncMock, row) -> None:
    """Wire mock_db.execute to return a single row for scalar_one_or_none.

    Args:
        mock_db: The mock AsyncSession.
        row: The ORM row mock (or None) to return.
    """
    result = MagicMock()
    result.scalar_one_or_none.return_value = row
    mock_db.execute = AsyncMock(return_value=result)
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()


# ---------------------------------------------------------------------------
# test_insight_list_pagination
# ---------------------------------------------------------------------------


def test_insight_list_pagination(client):
    """GET /insights returns the requested page slice and correct has_more flag.

    Scenario:
        - 5 total insights for the user.
        - Requesting limit=2, offset=0 → first 2 returned, has_more=True.
        - Requesting limit=2, offset=4 → last 1 returned, has_more=False.
    """
    test_client, _, mock_db = client

    page1 = [_make_insight(f"ins-{i}") for i in range(2)]
    _mock_db_list(mock_db, page1, total=5)

    resp = test_client.get("/api/v1/insights?limit=2&offset=0", headers=AUTH_HEADERS)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 5
    assert len(body["insights"]) == 2
    assert body["has_more"] is True

    # Page 3 (last page)
    page3 = [_make_insight("ins-4")]
    _mock_db_list(mock_db, page3, total=5)

    resp2 = test_client.get("/api/v1/insights?limit=2&offset=4", headers=AUTH_HEADERS)

    assert resp2.status_code == 200
    body2 = resp2.json()
    assert len(body2["insights"]) == 1
    assert body2["has_more"] is False


# ---------------------------------------------------------------------------
# test_insight_filter_by_type
# ---------------------------------------------------------------------------


def test_insight_filter_by_type(client):
    """GET /insights?type=sleep_analysis returns only sleep_analysis cards.

    The route passes the type parameter directly to the WHERE clause.  We
    verify the response payload contains only the expected type values and
    that total reflects the filtered count.
    """
    test_client, _, mock_db = client

    sleep_rows = [
        _make_insight("s-1", insight_type="sleep_analysis"),
        _make_insight("s-2", insight_type="sleep_analysis"),
    ]
    _mock_db_list(mock_db, sleep_rows, total=2)

    resp = test_client.get("/api/v1/insights?type=sleep_analysis", headers=AUTH_HEADERS)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2
    assert all(i["type"] == "sleep_analysis" for i in body["insights"])


# ---------------------------------------------------------------------------
# test_mark_read_sets_timestamp
# ---------------------------------------------------------------------------


def test_mark_read_sets_timestamp(client):
    """PATCH action=read sets read_at on the insight row.

    We verify that ``read_at`` in the response is non-null after the action
    and that the response HTTP status is 200.
    """
    test_client, _, mock_db = client

    insight = _make_insight("ins-read-001", read=False)
    _mock_db_get(mock_db, insight)

    # Patch datetime.now inside the route so the timestamp is predictable.
    with patch(
        "app.api.v1.insight_routes.datetime",
        wraps=datetime,
    ) as mock_dt:
        mock_dt.now.return_value = _NOW
        resp = test_client.patch(
            "/api/v1/insights/ins-read-001",
            json={"action": "read"},
            headers=AUTH_HEADERS,
        )

    assert resp.status_code == 200
    # The mock insight's read_at was set by the route handler
    assert insight.read_at == _NOW


# ---------------------------------------------------------------------------
# test_mark_dismissed_hides_from_list
# ---------------------------------------------------------------------------


def test_mark_dismissed_hides_from_list(client):
    """PATCH action=dismiss sets dismissed_at; dismissed cards excluded from GET.

    Step 1: Dismiss an insight via PATCH.
    Step 2: GET /insights returns 0 items (mock simulates DB filtering).
    """
    test_client, _, mock_db = client

    # Step 1: Dismiss
    insight = _make_insight("ins-dismiss-001", dismissed=False)
    _mock_db_get(mock_db, insight)

    with patch(
        "app.api.v1.insight_routes.datetime",
        wraps=datetime,
    ) as mock_dt:
        mock_dt.now.return_value = _NOW
        dismiss_resp = test_client.patch(
            "/api/v1/insights/ins-dismiss-001",
            json={"action": "dismiss"},
            headers=AUTH_HEADERS,
        )

    assert dismiss_resp.status_code == 200
    assert insight.dismissed_at == _NOW

    # Step 2: GET should exclude dismissed (DB returns 0 rows because the
    # WHERE dismissed_at IS NULL filter is applied — we mock that here).
    _mock_db_list(mock_db, [], total=0)

    list_resp = test_client.get("/api/v1/insights", headers=AUTH_HEADERS)

    assert list_resp.status_code == 200
    body = list_resp.json()
    assert body["total"] == 0
    assert body["insights"] == []
    assert body["has_more"] is False


# ---------------------------------------------------------------------------
# test_auth_required
# ---------------------------------------------------------------------------


def test_auth_required():
    """GET /api/v1/insights without a Bearer token returns 403.

    FastAPI's HTTPBearer scheme returns 403 (not 401) when the
    Authorization header is entirely absent.
    """
    # Use a standalone client with no dependency overrides so the real
    # auth guard fires.
    with TestClient(app, raise_server_exceptions=False) as c:
        resp = c.get("/api/v1/insights")

    # HTTPBearer returns 403 when no credentials are provided.
    assert resp.status_code == 403
