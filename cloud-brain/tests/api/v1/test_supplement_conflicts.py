from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from app.main import app
from app.api.deps import get_authenticated_user_id

client = TestClient(app)

def _auth_override():
    return "test-user-id"

app.dependency_overrides[get_authenticated_user_id] = _auth_override


def test_exact_duplicate_returns_conflict():
    """Exact match in existing_names → has_conflict=True, conflict_type='duplicate'. No LLM needed."""
    response = client.post(
        "/api/v1/supplements/check-conflicts",
        json={
            "name": "Vitamin D",
            "existing_names": ["Vitamin D", "Magnesium"],
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["has_conflict"] is True
    assert data["conflict_type"] == "duplicate"
    assert data["conflicting_name"] == "Vitamin D"


def test_no_conflict_in_existing_names():
    """Name not in existing_names and no LLM overlap → has_conflict=False."""
    with patch(
        "app.api.v1.supplements_routes._check_overlap_with_ai",
        new=AsyncMock(return_value={"has_overlap": False, "conflicting_name": None, "reason": None}),
    ):
        response = client.post(
            "/api/v1/supplements/check-conflicts",
            json={
                "name": "Zinc",
                "existing_names": ["Vitamin D", "Magnesium"],
            },
        )
    assert response.status_code == 200
    data = response.json()
    assert data["has_conflict"] is False


def test_requires_auth():
    """Unauthenticated request → 401."""
    app.dependency_overrides.pop(get_authenticated_user_id, None)
    try:
        response = client.post(
            "/api/v1/supplements/check-conflicts",
            json={"name": "Zinc", "existing_names": []},
        )
        assert response.status_code == 401
    finally:
        app.dependency_overrides[get_authenticated_user_id] = _auth_override


def test_llm_overlap_detected():
    """LLM returns has_overlap=True → has_conflict=True, conflict_type='overlap'."""
    with patch(
        "app.api.v1.supplements_routes._check_overlap_with_ai",
        new=AsyncMock(
            return_value={
                "has_overlap": True,
                "conflicting_name": "Fish Oil",
                "reason": "Both contain omega-3 fatty acids",
            }
        ),
    ):
        response = client.post(
            "/api/v1/supplements/check-conflicts",
            json={
                "name": "Omega-3",
                "existing_names": ["Fish Oil", "Vitamin D"],
            },
        )
    assert response.status_code == 200
    data = response.json()
    assert data["has_conflict"] is True
    assert data["conflict_type"] == "overlap"
    assert data["conflicting_name"] == "Fish Oil"
