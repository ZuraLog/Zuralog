"""Tests for WithingsTokenService."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.withings_token_service import WithingsTokenService


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = MagicMock()
    return db


@pytest.fixture
def mock_signature_service():
    svc = AsyncMock()
    svc.prepare_signed_params = AsyncMock(
        return_value={
            "action": "requesttoken",
            "client_id": "test_client_id",
            "nonce": "test_nonce",
            "signature": "a" * 64,
        }
    )
    return svc


@pytest.fixture
def service():
    return WithingsTokenService()


class TestBuildAuthUrl:
    @patch("app.services.withings_token_service.settings")
    def test_builds_correct_url(self, mock_settings, service):
        mock_settings.withings_client_id = "test_client_id"
        mock_settings.withings_redirect_uri = "https://api.zuralog.com/api/v1/integrations/withings/callback"

        url = service.build_auth_url(state="test_state_123")

        assert "account.withings.com/oauth2_user/authorize2" in url
        assert "client_id=test_client_id" in url
        assert "response_type=code" in url
        assert "state=test_state_123" in url
        assert "redirect_uri=" in url

    @patch("app.services.withings_token_service.settings")
    def test_includes_scopes(self, mock_settings, service):
        mock_settings.withings_client_id = "cid"
        mock_settings.withings_redirect_uri = "https://example.com/callback"

        url = service.build_auth_url(state="s")

        assert "user.metrics" in url
        assert "user.activity" in url


class TestStoreState:
    @pytest.mark.asyncio
    async def test_stores_state_with_user_id(self, service):
        mock_redis = AsyncMock()

        await service.store_state("state123", "user_uuid_abc", mock_redis)

        mock_redis.setex.assert_called_once_with("withings:state:state123", 600, "user_uuid_abc")


class TestValidateState:
    @pytest.mark.asyncio
    async def test_valid_state_returns_user_id(self, service):
        mock_redis = AsyncMock()
        mock_redis.getdel.return_value = b"user_uuid_abc"

        result = await service.validate_state("state123", mock_redis)

        assert result == "user_uuid_abc"
        mock_redis.getdel.assert_called_once_with("withings:state:state123")

    @pytest.mark.asyncio
    async def test_invalid_state_returns_none(self, service):
        mock_redis = AsyncMock()
        mock_redis.getdel.return_value = None

        result = await service.validate_state("bad_state", mock_redis)

        assert result is None


class TestExchangeCode:
    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_exchange_success(self, mock_post, service, mock_signature_service):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": 0,
            "body": {
                "userid": "12345",
                "access_token": "access_abc",
                "refresh_token": "refresh_xyz",
                "scope": "user.metrics,user.activity",
                "expires_in": 10800,
                "token_type": "Bearer",
            },
        }
        mock_response.raise_for_status = MagicMock()
        mock_post.return_value = mock_response

        result = await service.exchange_code(
            code="auth_code_123",
            signature_service=mock_signature_service,
            redirect_uri="https://api.zuralog.com/callback",
        )

        assert result["access_token"] == "access_abc"
        assert result["refresh_token"] == "refresh_xyz"
        assert result["userid"] == "12345"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_exchange_withings_error(self, mock_post, service, mock_signature_service):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"status": 293, "error": "Invalid params"}
        mock_response.raise_for_status = MagicMock()
        mock_post.return_value = mock_response

        with pytest.raises(Exception, match="Withings"):
            await service.exchange_code(
                code="bad_code",
                signature_service=mock_signature_service,
                redirect_uri="https://example.com",
            )


class TestSaveTokens:
    @pytest.mark.asyncio
    async def test_creates_new_integration(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {
            "userid": "12345",
            "access_token": "access_abc",
            "refresh_token": "refresh_xyz",
            "expires_in": 10800,
            "scope": "user.metrics,user.activity",
        }

        integration = await service.save_tokens(mock_db, "user_uuid", token_response)

        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()
        added_obj = mock_db.add.call_args[0][0]
        assert added_obj.provider == "withings"
        assert added_obj.access_token == "access_abc"

    @pytest.mark.asyncio
    async def test_updates_existing_integration(self, service, mock_db):
        existing = MagicMock()
        existing.provider_metadata = {"withings_user_id": "12345"}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        token_response = {
            "userid": "12345",
            "access_token": "new_access",
            "refresh_token": "new_refresh",
            "expires_in": 10800,
            "scope": "user.metrics,user.activity",
        }

        await service.save_tokens(mock_db, "user_uuid", token_response)

        assert existing.access_token == "new_access"
        assert existing.refresh_token == "new_refresh"
        assert existing.sync_status == "idle"
        mock_db.commit.assert_called_once()


class TestGetAccessToken:
    @pytest.mark.asyncio
    async def test_returns_valid_token(self, service, mock_db):
        integration = MagicMock()
        integration.access_token = "valid_token"
        integration.token_expires_at = datetime.now(timezone.utc) + timedelta(hours=2)
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user_uuid")
        assert token == "valid_token"

    @pytest.mark.asyncio
    @patch.object(WithingsTokenService, "refresh_access_token")
    async def test_refreshes_expiring_token(self, mock_refresh, service, mock_db):
        integration = MagicMock()
        integration.access_token = "old_token"
        integration.token_expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result
        mock_refresh.return_value = "refreshed_token"

        token = await service.get_access_token(mock_db, "user_uuid")

        assert token == "refreshed_token"
        mock_refresh.assert_called_once()

    @pytest.mark.asyncio
    async def test_returns_none_for_inactive(self, service, mock_db):
        integration = MagicMock()
        integration.is_active = False

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user_uuid")
        assert token is None


class TestRefreshAccessToken:
    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    @patch("app.services.withings_token_service.settings")
    async def test_refresh_success(self, mock_settings, mock_post, service, mock_db):
        mock_settings.withings_client_id = "cid"
        mock_settings.withings_client_secret = "csecret"

        # Call 1: getnonce (from WithingsSignatureService.get_nonce)
        nonce_response = MagicMock()
        nonce_response.status_code = 200
        nonce_response.json.return_value = {"status": 0, "body": {"nonce": "test_nonce"}}
        nonce_response.raise_for_status = MagicMock()

        # Call 2: requesttoken (the actual refresh)
        token_response = MagicMock()
        token_response.status_code = 200
        token_response.json.return_value = {
            "status": 0,
            "body": {
                "userid": "12345",
                "access_token": "new_access",
                "refresh_token": "new_refresh",
                "expires_in": 10800,
            },
        }
        token_response.raise_for_status = MagicMock()

        mock_post.side_effect = [nonce_response, token_response]

        integration = MagicMock()
        integration.refresh_token = "old_refresh"
        integration.provider_metadata = {"withings_user_id": "12345"}

        result = await service.refresh_access_token(mock_db, integration)

        assert result == "new_access"
        assert integration.access_token == "new_access"
        assert integration.refresh_token == "new_refresh"
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    @patch("app.services.withings_token_service.settings")
    async def test_refresh_failure_marks_error(self, mock_settings, mock_post, service, mock_db):
        mock_settings.withings_client_id = "cid"
        mock_settings.withings_client_secret = "csecret"

        # Call 1: getnonce
        nonce_response = MagicMock()
        nonce_response.status_code = 200
        nonce_response.json.return_value = {"status": 0, "body": {"nonce": "test_nonce"}}
        nonce_response.raise_for_status = MagicMock()

        # Call 2: requesttoken returns error
        error_response = MagicMock()
        error_response.status_code = 200
        error_response.json.return_value = {"status": 401, "error": "Invalid token"}
        error_response.raise_for_status = MagicMock()

        mock_post.side_effect = [nonce_response, error_response]

        integration = MagicMock()
        integration.refresh_token = "expired_refresh"
        integration.provider_metadata = {}

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        assert integration.sync_status == "error"


class TestDisconnect:
    @pytest.mark.asyncio
    async def test_disconnect_deactivates(self, service, mock_db):
        integration = MagicMock()
        integration.access_token = "token"
        integration.is_active = True
        integration.provider_metadata = {"withings_user_id": "12345"}

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        result = await service.disconnect(mock_db, "user_uuid")

        assert result is True
        assert integration.is_active is False
        assert integration.access_token == ""
        assert integration.refresh_token == ""
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_no_integration(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.disconnect(mock_db, "user_uuid")
        assert result is False
