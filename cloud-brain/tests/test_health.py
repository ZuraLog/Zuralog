"""
Life Logger Cloud Brain — Health Endpoint Tests.

Verifies the health check endpoint returns the expected response.
"""

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health_check_returns_200() -> None:
    """Health endpoint should return HTTP 200 with status 'healthy'."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_health_check_content_type() -> None:
    """Health endpoint should return JSON content type."""
    response = client.get("/health")
    assert "application/json" in response.headers["content-type"]
