"""Tests for WithingsSignatureService."""

from unittest.mock import MagicMock, patch

import pytest

from app.services.withings_signature_service import WithingsSignatureService


@pytest.fixture
def service():
    return WithingsSignatureService(
        client_id="test_client_id",
        client_secret="test_client_secret",
    )


class TestComputeSignature:
    """Test HMAC SHA-256 signature computation."""

    def test_signature_for_getnonce(self, service):
        """Signature for getnonce uses action,client_id,timestamp."""
        result = service.compute_signature(
            action="getnonce",
            client_id="test_client_id",
            timestamp=1234567890,
        )
        assert isinstance(result, str)
        assert len(result) == 64  # SHA-256 hex digest is always 64 chars

    def test_signature_for_api_call(self, service):
        """Signature for API calls uses action,client_id,nonce."""
        result = service.compute_signature(
            action="requesttoken",
            client_id="test_client_id",
            nonce="abc123nonce",
        )
        assert isinstance(result, str)
        assert len(result) == 64

    def test_signature_deterministic(self, service):
        """Same inputs produce same signature."""
        sig1 = service.compute_signature(
            action="getmeas",
            client_id="test_client_id",
            nonce="nonce1",
        )
        sig2 = service.compute_signature(
            action="getmeas",
            client_id="test_client_id",
            nonce="nonce1",
        )
        assert sig1 == sig2

    def test_different_nonce_different_signature(self, service):
        """Different nonces produce different signatures."""
        sig1 = service.compute_signature(
            action="getmeas",
            client_id="test_client_id",
            nonce="nonce1",
        )
        sig2 = service.compute_signature(
            action="getmeas",
            client_id="test_client_id",
            nonce="nonce2",
        )
        assert sig1 != sig2

    def test_raises_without_timestamp_or_nonce(self, service):
        """Must provide either timestamp or nonce."""
        with pytest.raises(ValueError):
            service.compute_signature(
                action="getmeas",
                client_id="test_client_id",
            )


class TestGetNonce:
    """Test nonce retrieval from Withings API."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_get_nonce_success(self, mock_post, service):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": 0,
            "body": {"nonce": "abc123nonce"},
        }
        mock_response.raise_for_status = MagicMock()
        mock_post.return_value = mock_response

        nonce = await service.get_nonce()
        assert nonce == "abc123nonce"
        mock_post.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_get_nonce_api_error(self, mock_post, service):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"status": 293, "error": "Invalid signature"}
        mock_response.raise_for_status = MagicMock()
        mock_post.return_value = mock_response

        with pytest.raises(Exception, match="Withings"):
            await service.get_nonce()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_get_nonce_network_error(self, mock_post, service):
        import httpx

        mock_post.side_effect = httpx.RequestError("Connection failed")

        with pytest.raises(httpx.RequestError):
            await service.get_nonce()


class TestPrepareSignedParams:
    """Test full signed params pipeline."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_prepare_signed_params_with_extras(self, mock_post, service):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": 0,
            "body": {"nonce": "fresh_nonce"},
        }
        mock_response.raise_for_status = MagicMock()
        mock_post.return_value = mock_response

        params = await service.prepare_signed_params(
            action="getmeas",
            extra_params={"startdate": 1000, "enddate": 2000},
        )

        assert params["action"] == "getmeas"
        assert params["client_id"] == "test_client_id"
        assert params["nonce"] == "fresh_nonce"
        assert len(params["signature"]) == 64
        assert params["startdate"] == 1000
        assert params["enddate"] == 2000

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_prepare_signed_params_no_extras(self, mock_post, service):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": 0,
            "body": {"nonce": "nonce_val"},
        }
        mock_response.raise_for_status = MagicMock()
        mock_post.return_value = mock_response

        params = await service.prepare_signed_params(action="requesttoken")

        assert "action" in params
        assert "client_id" in params
        assert "nonce" in params
        assert "signature" in params
