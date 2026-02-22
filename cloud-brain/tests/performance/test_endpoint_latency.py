"""
Life Logger Cloud Brain — Endpoint Latency Performance Tests.

Measures response latency for critical API endpoints and asserts that
each stays within the project-wide **p95 target of 200 ms**.  Timing
uses ``time.perf_counter`` for high-resolution monotonic measurements
— no external benchmarking dependencies required.

Uses the shared ``integration_client`` fixture from ``tests/conftest.py``
so that ``AuthService`` and the database session are replaced by mocks,
isolating framework overhead from external I/O.
"""

import time
from typing import Any, Tuple

import pytest
from fastapi.testclient import TestClient
from httpx import Response

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

LATENCY_THRESHOLD_MS: float = 200
"""Maximum acceptable p95 latency in milliseconds for any endpoint."""


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def _measure_latency(
    client: TestClient,
    method: str,
    path: str,
    **kwargs: Any,
) -> Tuple[Response, float]:
    """Execute an HTTP request and return the response with elapsed time.

    Wraps the request in a pair of ``time.perf_counter`` calls to
    produce a high-resolution latency measurement.

    Args:
        client: The FastAPI ``TestClient`` instance to use.
        method: HTTP method (``"GET"``, ``"POST"``, etc.).
        path: URL path (e.g. ``"/health"``).
        **kwargs: Extra keyword arguments forwarded to
            ``client.request`` (e.g. ``json=``, ``params=``).

    Returns:
        Tuple of (``httpx.Response``, latency in milliseconds).
    """
    start = time.perf_counter()
    response = client.request(method, path, **kwargs)
    elapsed_ms = (time.perf_counter() - start) * 1_000
    return response, elapsed_ms


# --------------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------------- #


class TestEndpointLatency:
    """Performance tests for critical API endpoint response times.

    Each test verifies that the endpoint responds within
    ``LATENCY_THRESHOLD_MS`` (200 ms), ensuring the FastAPI routing,
    Pydantic validation, and middleware pipeline stay fast.
    """

    @pytest.fixture(autouse=True)
    def _setup(self, integration_client):
        """Bind the shared integration_client fixture to instance attrs.

        Args:
            integration_client: Shared fixture providing
                ``(TestClient, mock_auth_service, mock_db)``.
        """
        self.client, _, _ = integration_client

    # ------------------------------------------------------------------ #
    # Individual endpoint latency
    # ------------------------------------------------------------------ #

    def test_health_check_latency(self) -> None:
        """GET /health must respond in < 200 ms.

        The health endpoint is the simplest route in the application
        and serves as a lower-bound latency reference.
        """
        response, latency_ms = _measure_latency(self.client, "GET", "/health")

        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert latency_ms < LATENCY_THRESHOLD_MS, (
            f"Health latency {latency_ms:.1f} ms exceeds {LATENCY_THRESHOLD_MS} ms threshold"
        )

    def test_auth_register_validation_latency(self) -> None:
        """POST /api/v1/auth/register with invalid data must respond in < 200 ms.

        Sends an empty JSON body so that Pydantic validation rejects it
        with HTTP 422.  Measures the combined cost of routing, schema
        validation, and error serialization.
        """
        response, latency_ms = _measure_latency(
            self.client,
            "POST",
            "/api/v1/auth/register",
            json={},
        )

        assert response.status_code == 422, f"Expected 422, got {response.status_code}"
        assert latency_ms < LATENCY_THRESHOLD_MS, (
            f"Auth register validation latency {latency_ms:.1f} ms exceeds {LATENCY_THRESHOLD_MS} ms threshold"
        )

    def test_openapi_schema_latency(self) -> None:
        """GET /openapi.json must respond in < 200 ms.

        The OpenAPI schema is generated once and cached by FastAPI.
        This test verifies schema generation does not regress in cost.
        """
        response, latency_ms = _measure_latency(
            self.client,
            "GET",
            "/openapi.json",
        )

        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert latency_ms < LATENCY_THRESHOLD_MS, (
            f"OpenAPI schema latency {latency_ms:.1f} ms exceeds {LATENCY_THRESHOLD_MS} ms threshold"
        )

    def test_analytics_validation_latency(self) -> None:
        """GET /api/v1/analytics/daily-summary without user_id must respond in < 200 ms.

        Omitting the required ``user_id`` query parameter triggers a
        422 validation error.  Verifies the analytics router + Pydantic
        validation pipeline stays within the latency budget.
        """
        response, latency_ms = _measure_latency(
            self.client,
            "GET",
            "/api/v1/analytics/daily-summary",
        )

        assert response.status_code == 422, f"Expected 422, got {response.status_code}"
        assert latency_ms < LATENCY_THRESHOLD_MS, (
            f"Analytics validation latency {latency_ms:.1f} ms exceeds {LATENCY_THRESHOLD_MS} ms threshold"
        )

    # ------------------------------------------------------------------ #
    # Sustained load — sequential requests
    # ------------------------------------------------------------------ #

    def test_concurrent_health_checks(self) -> None:
        """10 sequential GET /health requests must have p95 latency < 200 ms.

        Fires 10 sequential health-check requests and computes the
        95th-percentile latency.  This guards against per-request
        overhead accumulation (middleware state, GC pauses, etc.).
        """
        num_requests = 10
        latencies: list[float] = []

        for _ in range(num_requests):
            response, latency_ms = _measure_latency(
                self.client,
                "GET",
                "/health",
            )
            assert response.status_code == 200, f"Expected 200, got {response.status_code}"
            latencies.append(latency_ms)

        # p95 = value at the 95th percentile index
        latencies.sort()
        p95_index = int(len(latencies) * 0.95) - 1
        p95_latency = latencies[max(p95_index, 0)]

        assert p95_latency < LATENCY_THRESHOLD_MS, (
            f"p95 latency {p95_latency:.1f} ms exceeds "
            f"{LATENCY_THRESHOLD_MS} ms threshold "
            f"(all latencies: {[f'{l:.1f}' for l in latencies]})"
        )
