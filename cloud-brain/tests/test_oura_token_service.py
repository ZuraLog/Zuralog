# tests/test_oura_token_service.py
"""Tests for OuraTokenService — OAuth 2.0 auth code flow, token lifecycle, and DB ops."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.oura_token_service import OuraTokenService


@pytest.fixture
def mock_db():
    """Create an AsyncMock for SQLAlchemy AsyncSession."""
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = MagicMock()
    return db


@pytest.fixture
def service():
    return OuraTokenService()


# ---------------------------------------------------------------------------
# Build auth URL
# ---------------------------------------------------------------------------


class TestBuildAuthUrl:
    """Tests for Oura OAuth 2.0 authorization URL construction."""

    def test_contains_all_required_scopes(self, service):
        """Auth URL includes all 8 required Oura scopes."""
        url = service.build_auth_url(state="state-abc")
        required_scopes = [
            "email",
            "personal",
            "daily",
            "heartrate",
            "workout",
            "tag",
            "session",
            "spo2",
        ]
        for scope in required_scopes:
            assert scope in url, f"Scope '{scope}' missing from auth URL"

    def test_contains_state(self, service):
        """Auth URL includes the state parameter."""
        url = service.build_auth_url(state="my-csrf-state")
        assert "state=my-csrf-state" in url

    def test_response_type_is_code(self, service):
        """Auth URL uses response_type=code."""
        url = service.build_auth_url(state="s")
        assert "response_type=code" in url

    def test_points_to_oura_authorize_endpoint(self, service):
        """Auth URL uses the Oura authorization endpoint."""
        url = service.build_auth_url(state="s")
        assert url.startswith("https://cloud.ouraring.com/oauth/authorize")

    def test_no_pkce_params(self, service):
        """Auth URL must NOT contain PKCE parameters (Oura doesn't use PKCE)."""
        url = service.build_auth_url(state="s")
        assert "code_challenge" not in url
        assert "code_verifier" not in url

    def test_contains_client_id_from_settings(self, service):
        """Auth URL includes client_id from settings."""
        with patch("app.services.oura_token_service.settings") as mock_settings:
            mock_settings.oura_client_id = "test-oura-client"
            mock_settings.oura_redirect_uri = "zuralog://oauth/oura"
            url = service.build_auth_url(state="s")
        assert "test-oura-client" in url


# ---------------------------------------------------------------------------
# Redis state storage
# ---------------------------------------------------------------------------


class TestStoreState:
    """Tests for CSRF state storage in Redis."""

    @pytest.mark.asyncio
    async def test_store_sets_key_with_600s_ttl(self, service):
        """store_state calls redis.setex with correct key and 600s TTL."""
        redis = AsyncMock()
        await service.store_state("csrf-state-xyz", redis)
        redis.setex.assert_called_once_with("oura:state:csrf-state-xyz", 600, "1")

    @pytest.mark.asyncio
    async def test_store_uses_oura_prefix(self, service):
        """Key must use 'oura:state:' prefix (not fitbit or other providers)."""
        redis = AsyncMock()
        await service.store_state("abc", redis)
        call_args = redis.setex.call_args
        key = call_args[0][0] if call_args[0] else call_args.args[0]
        assert key.startswith("oura:state:")


class TestValidateState:
    """Tests for CSRF state validation from Redis (single-use)."""

    @pytest.mark.asyncio
    async def test_returns_true_when_state_found(self, service):
        """validate_state returns True when state key exists in Redis."""
        redis = AsyncMock()
        redis.getdel.return_value = b"1"
        result = await service.validate_state("valid-state", redis)
        assert result is True

    @pytest.mark.asyncio
    async def test_returns_false_when_state_not_found(self, service):
        """validate_state returns False when state key is missing or expired."""
        redis = AsyncMock()
        redis.getdel.return_value = None
        result = await service.validate_state("missing-state", redis)
        assert result is False

    @pytest.mark.asyncio
    async def test_uses_atomic_getdel(self, service):
        """validate_state uses atomic GETDEL (not GET + DELETE) to prevent TOCTOU race."""
        redis = AsyncMock()
        redis.getdel.return_value = b"1"
        await service.validate_state("used-state", redis)
        redis.getdel.assert_called_once_with("oura:state:used-state")
        # Must NOT use separate GET + DELETE calls
        redis.get.assert_not_called()
        redis.delete.assert_not_called()

    @pytest.mark.asyncio
    async def test_does_not_delete_when_not_found(self, service):
        """validate_state does NOT perform any delete when state was not found (GETDEL is atomic)."""
        redis = AsyncMock()
        redis.getdel.return_value = None
        await service.validate_state("missing", redis)
        redis.delete.assert_not_called()


# ---------------------------------------------------------------------------
# Code exchange
# ---------------------------------------------------------------------------


class TestExchangeCode:
    """Tests for exchanging an authorization code for Oura tokens."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_credentials_in_post_body(self, mock_post, service):
        """exchange_code sends client_id and client_secret in POST body (NOT Basic header)."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 86400,
            "token_type": "Bearer",
        }
        mock_post.return_value = mock_response

        await service.exchange_code(
            code="code123",
            client_id="my-client-id",
            client_secret="my-client-secret",
            redirect_uri="zuralog://oauth/oura",
        )

        call_kwargs = mock_post.call_args
        data = call_kwargs.kwargs.get("data", {})
        assert data.get("client_id") == "my-client-id"
        assert data.get("client_secret") == "my-client-secret"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_no_basic_auth_header(self, mock_post, service):
        """exchange_code must NOT use Authorization: Basic header (Oura uses POST body)."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        await service.exchange_code("c", "cid", "csecret", "uri")

        call_kwargs = mock_post.call_args
        headers = call_kwargs.kwargs.get("headers", {})
        auth_header = headers.get("Authorization", "")
        assert not auth_header.startswith("Basic "), "Oura must NOT use Basic auth header"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_posts_to_oura_token_url(self, mock_post, service):
        """exchange_code POSTs to the correct Oura token URL."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        await service.exchange_code("c", "cid", "cs", "uri")

        call_args = mock_post.call_args
        url = call_args.args[0] if call_args.args else call_args.kwargs.get("url", "")
        assert "ouraring.com" in url
        assert "token" in url

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_returns_token_dict(self, mock_post, service):
        """exchange_code returns the parsed JSON response dict."""
        token_data = {
            "access_token": "oura-at-123",
            "refresh_token": "oura-rt-456",
            "expires_in": 86400,
        }
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = token_data
        mock_post.return_value = mock_response

        result = await service.exchange_code("c", "cid", "cs", "uri")
        assert result == token_data

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_sends_authorization_code_grant_type(self, mock_post, service):
        """exchange_code uses grant_type=authorization_code."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        await service.exchange_code("code-abc", "cid", "cs", "uri")

        data = mock_post.call_args.kwargs.get("data", {})
        assert data.get("grant_type") == "authorization_code"
        assert data.get("code") == "code-abc"


# ---------------------------------------------------------------------------
# Save tokens
# ---------------------------------------------------------------------------


class TestSaveTokens:
    """Tests for persisting Oura OAuth tokens."""

    @pytest.mark.asyncio
    async def test_creates_new_integration(self, service, mock_db):
        """Creates a new row when no existing Oura integration exists."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        personal_info = {
            "id": "OURA-USR-1",
            "age": 30,
            "weight": 70.0,
            "height": 175.0,
            "biological_sex": "male",
            "email": "user@example.com",
        }

        with patch.object(service, "_fetch_personal_info", new_callable=AsyncMock, return_value=personal_info):
            token_response = {
                "access_token": "at-abc",
                "refresh_token": "rt-xyz",
                "expires_in": 86400,
            }
            await service.save_tokens(mock_db, "user-123", token_response)

        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_stores_oura_user_id_in_metadata(self, service, mock_db):
        """Stores oura_user_id (from personal_info['id']) in provider_metadata."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        personal_info = {
            "id": "OURA-ABC-123",
            "age": 25,
            "weight": 65.0,
            "height": 170.0,
            "biological_sex": "female",
            "email": "test@example.com",
        }

        with patch.object(service, "_fetch_personal_info", new_callable=AsyncMock, return_value=personal_info):
            await service.save_tokens(
                mock_db,
                "user-123",
                {
                    "access_token": "at",
                    "refresh_token": "rt",
                    "expires_in": 86400,
                },
            )

        added = mock_db.add.call_args[0][0]
        assert added.provider_metadata["oura_user_id"] == "OURA-ABC-123"
        assert added.provider_metadata["email"] == "test@example.com"
        assert added.provider_metadata["age"] == 25

    @pytest.mark.asyncio
    async def test_initializes_webhook_subscription_ids(self, service, mock_db):
        """New integrations get webhook_subscription_ids: [] in metadata."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        with patch.object(service, "_fetch_personal_info", new_callable=AsyncMock, return_value={}):
            await service.save_tokens(
                mock_db,
                "user-123",
                {
                    "access_token": "at",
                    "refresh_token": "rt",
                    "expires_in": 86400,
                },
            )

        added = mock_db.add.call_args[0][0]
        assert "webhook_subscription_ids" in added.provider_metadata
        assert added.provider_metadata["webhook_subscription_ids"] == []

    @pytest.mark.asyncio
    async def test_updates_existing_integration(self, service, mock_db):
        """Updates tokens in place when an Oura integration already exists."""
        existing = MagicMock()
        existing.access_token = "old-at"
        existing.provider_metadata = {"oura_user_id": "EXISTING-USR"}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        personal_info = {"id": "EXISTING-USR", "email": "user@example.com"}

        with patch.object(service, "_fetch_personal_info", new_callable=AsyncMock, return_value=personal_info):
            await service.save_tokens(
                mock_db,
                "user-123",
                {
                    "access_token": "new-at",
                    "refresh_token": "new-rt",
                    "expires_in": 86400,
                },
            )

        assert existing.access_token == "new-at"
        assert existing.refresh_token == "new-rt"
        mock_db.commit.assert_called_once()
        # db.add should NOT be called for an update
        mock_db.add.assert_not_called()

    @pytest.mark.asyncio
    async def test_update_merges_personal_info_into_existing_metadata(self, service, mock_db):
        """On UPDATE, personal info is merged into existing provider_metadata."""
        existing = MagicMock()
        existing.access_token = "old-at"
        existing.provider_metadata = {"oura_user_id": "USR-1", "webhook_subscription_ids": ["sub-1"]}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        personal_info = {"id": "USR-1", "age": 31, "email": "updated@example.com"}

        with patch.object(service, "_fetch_personal_info", new_callable=AsyncMock, return_value=personal_info):
            await service.save_tokens(
                mock_db,
                "user-123",
                {
                    "access_token": "new-at",
                    "refresh_token": "new-rt",
                    "expires_in": 86400,
                },
            )

        # Existing metadata keys like webhook_subscription_ids should be preserved
        assert existing.provider_metadata["webhook_subscription_ids"] == ["sub-1"]
        assert existing.provider_metadata["oura_user_id"] == "USR-1"

    @pytest.mark.asyncio
    async def test_save_tokens_graceful_on_personal_info_error(self, service, mock_db):
        """save_tokens succeeds even if _fetch_personal_info returns empty dict."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        with patch.object(service, "_fetch_personal_info", new_callable=AsyncMock, return_value={}):
            result = await service.save_tokens(
                mock_db,
                "user-123",
                {
                    "access_token": "at",
                    "refresh_token": "rt",
                    "expires_in": 86400,
                },
            )

        # Should not raise; DB operations should still complete
        mock_db.commit.assert_called_once()


# ---------------------------------------------------------------------------
# Get access token (with auto-refresh)
# ---------------------------------------------------------------------------


class TestGetAccessToken:
    """Tests for retrieving a valid access token with 30-min refresh buffer."""

    @pytest.mark.asyncio
    async def test_returns_token_when_not_expiring(self, service, mock_db):
        """Returns access_token directly when well within expiry window."""
        future = datetime.now(timezone.utc) + timedelta(hours=12)
        integration = MagicMock()
        integration.access_token = "valid-oura-token"
        integration.token_expires_at = future
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "valid-oura-token"

    @pytest.mark.asyncio
    async def test_returns_none_when_no_integration(self, service, mock_db):
        """Returns None when user has no active Oura integration."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-999")
        assert token is None

    @pytest.mark.asyncio
    @patch("app.services.oura_token_service.OuraTokenService.refresh_access_token")
    async def test_refreshes_within_30min_buffer(self, mock_refresh, service, mock_db):
        """Triggers refresh when token is within the 30-minute expiry buffer."""
        # Expiring in 15 minutes — within the 30-minute buffer
        near_expiry = datetime.now(timezone.utc) + timedelta(minutes=15)
        integration = MagicMock()
        integration.access_token = "expiring-token"
        integration.token_expires_at = near_expiry
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result
        mock_refresh.return_value = "refreshed-oura-token"

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "refreshed-oura-token"
        mock_refresh.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.services.oura_token_service.OuraTokenService.refresh_access_token")
    async def test_does_not_refresh_outside_buffer(self, mock_refresh, service, mock_db):
        """Does NOT refresh when token has more than 30 minutes remaining."""
        future = datetime.now(timezone.utc) + timedelta(minutes=45)
        integration = MagicMock()
        integration.access_token = "fresh-token"
        integration.token_expires_at = future
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "fresh-token"
        mock_refresh.assert_not_called()

    @pytest.mark.asyncio
    @patch("app.services.oura_token_service.OuraTokenService.refresh_access_token")
    async def test_refresh_buffer_is_30min_not_10min(self, mock_refresh, service, mock_db):
        """Buffer is 30 minutes (not Fitbit's 10 min); verify boundary precisely."""
        # Token expiring in exactly 29 min — must trigger refresh
        near_expiry = datetime.now(timezone.utc) + timedelta(minutes=29)
        integration = MagicMock()
        integration.access_token = "token"
        integration.token_expires_at = near_expiry
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result
        mock_refresh.return_value = "new-token"

        await service.get_access_token(mock_db, "user-123")
        mock_refresh.assert_called_once()


# ---------------------------------------------------------------------------
# Refresh access token
# ---------------------------------------------------------------------------


class TestRefreshAccessToken:
    """Tests for the Oura single-use refresh token flow."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_saves_new_tokens_atomically(self, mock_post, service, mock_db):
        """On success, new access AND refresh tokens are saved before returning."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "new-at",
            "refresh_token": "new-rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "old-rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result == "new-at"
        assert integration.access_token == "new-at"
        # Critical: new refresh token must be saved (single-use)
        assert integration.refresh_token == "new-rt"
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_uses_post_body_credentials(self, mock_post, service, mock_db):
        """Refresh request sends credentials in POST body (NOT Basic auth header)."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        with patch("app.services.oura_token_service.settings") as mock_settings:
            mock_settings.oura_client_id = "my-oura-client"
            mock_settings.oura_client_secret = "my-oura-secret"
            await service.refresh_access_token(mock_db, integration)

        call_kwargs = mock_post.call_args
        data = call_kwargs.kwargs.get("data", {})
        assert data.get("client_id") == "my-oura-client"
        assert data.get("client_secret") == "my-oura-secret"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_does_not_use_basic_auth(self, mock_post, service, mock_db):
        """Oura refresh must NOT use Authorization: Basic header."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        with patch("app.services.oura_token_service.settings"):
            await service.refresh_access_token(mock_db, integration)

        headers = mock_post.call_args.kwargs.get("headers", {})
        assert not headers.get("Authorization", "").startswith("Basic ")

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_401_marks_reconnect_error_message(self, mock_post, service, mock_db):
        """On 401, integration gets specific Oura reconnect error message and returns None."""
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.text = "Unauthorized"
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "bad-rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        assert integration.sync_status == "error"
        assert "reconnect" in integration.sync_error.lower() or "Oura" in integration.sync_error
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_non_200_failure_returns_none(self, mock_post, service, mock_db):
        """Non-401/non-200 failures return None and mark sync_status='error' in DB."""
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.text = "Server Error"
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        # Must mark error and commit so the bad state is visible
        assert integration.sync_status == "error"
        assert integration.sync_error is not None
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post", side_effect=__import__("httpx").RequestError("timeout"))
    async def test_network_error_returns_none_without_db_changes(self, mock_post, service, mock_db):
        """Network-level errors return None without touching the DB."""
        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        mock_db.commit.assert_not_called()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_resets_sync_status_to_idle_on_success(self, mock_post, service, mock_db):
        """On successful refresh, sync_status is reset to 'idle' (not left as 'error')."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "new-at",
            "refresh_token": "new-rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"
        integration.sync_status = "error"  # Simulating a previously broken state

        await service.refresh_access_token(mock_db, integration)
        assert integration.sync_status == "idle"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_clears_sync_error_on_success(self, mock_post, service, mock_db):
        """On successful refresh, sync_error is cleared."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "new-at",
            "refresh_token": "new-rt",
            "expires_in": 86400,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"
        integration.sync_error = "Previous error"

        await service.refresh_access_token(mock_db, integration)
        assert integration.sync_error is None


# ---------------------------------------------------------------------------
# Get integration
# ---------------------------------------------------------------------------


class TestGetIntegration:
    """Tests for fetching the Oura integration row."""

    @pytest.mark.asyncio
    async def test_returns_integration_when_found(self, service, mock_db):
        """Returns the Integration when one exists for the user."""
        integration = MagicMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        result = await service.get_integration(mock_db, "user-123")
        assert result is integration

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, service, mock_db):
        """Returns None when no Oura integration exists for the user."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.get_integration(mock_db, "user-999")
        assert result is None


# ---------------------------------------------------------------------------
# Disconnect
# ---------------------------------------------------------------------------


class TestDisconnect:
    """Tests for revoking an Oura integration."""

    @pytest.mark.asyncio
    async def test_disconnect_deactivates_integration(self, service, mock_db):
        """disconnect sets is_active=False, clears tokens, and commits."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = "some-token"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        with patch("httpx.AsyncClient.get", new_callable=AsyncMock):
            result = await service.disconnect(mock_db, "user-123")

        assert result is True
        assert integration.is_active is False
        assert integration.access_token is None
        assert integration.refresh_token is None
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_returns_false_when_not_found(self, service, mock_db):
        """disconnect returns False when no integration exists."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.disconnect(mock_db, "user-999")
        assert result is False

    @pytest.mark.asyncio
    async def test_disconnect_uses_get_revoke_not_post(self, service, mock_db):
        """Oura revoke is a GET request, NOT POST (unlike Fitbit)."""
        integration = MagicMock()
        integration.access_token = "token-to-revoke"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
            await service.disconnect(mock_db, "user-123")

        mock_get.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_revoke_url_contains_access_token(self, service, mock_db):
        """Revoke URL includes access_token as query param."""
        integration = MagicMock()
        integration.access_token = "my-access-token"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
            await service.disconnect(mock_db, "user-123")

        call_args = mock_get.call_args
        url = call_args.args[0] if call_args.args else call_args.kwargs.get("url", "")
        assert "my-access-token" in url
        assert "ouraring.com" in url

    @pytest.mark.asyncio
    async def test_disconnect_handles_missing_access_token(self, service, mock_db):
        """disconnect still deactivates integration even if access_token is None."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = None
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        # No HTTP call should be made if no token to revoke
        result = await service.disconnect(mock_db, "user-123")
        assert result is True
        assert integration.is_active is False


# ---------------------------------------------------------------------------
# Fetch personal info (private helper)
# ---------------------------------------------------------------------------


class TestFetchPersonalInfo:
    """Tests for the _fetch_personal_info private helper."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_returns_personal_info_dict(self, mock_get, service):
        """_fetch_personal_info returns parsed personal info from Oura API."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "id": "OURA-123",
            "age": 28,
            "weight": 72.5,
            "height": 178.0,
            "biological_sex": "male",
            "email": "user@example.com",
        }
        mock_get.return_value = mock_response

        result = await service._fetch_personal_info("test-access-token")

        assert result["id"] == "OURA-123"
        assert result["age"] == 28
        assert result["email"] == "user@example.com"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_sends_bearer_token(self, mock_get, service):
        """_fetch_personal_info uses Authorization: Bearer header."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {"id": "USR-1"}
        mock_get.return_value = mock_response

        await service._fetch_personal_info("my-bearer-token")

        call_kwargs = mock_get.call_args
        headers = call_kwargs.kwargs.get("headers", {})
        assert headers.get("Authorization") == "Bearer my-bearer-token"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_calls_v2_personal_info_endpoint(self, mock_get, service):
        """_fetch_personal_info calls the correct Oura v2 personal_info endpoint."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {}
        mock_get.return_value = mock_response

        await service._fetch_personal_info("token")

        call_args = mock_get.call_args
        url = call_args.args[0] if call_args.args else call_args.kwargs.get("url", "")
        assert "personal_info" in url
        assert "v2" in url

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get", side_effect=Exception("network error"))
    async def test_returns_empty_dict_on_error(self, mock_get, service):
        """_fetch_personal_info returns {} on any error (never raises)."""
        result = await service._fetch_personal_info("token")
        assert result == {}

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_returns_empty_dict_on_http_error(self, mock_get, service):
        """_fetch_personal_info returns {} when API returns error status."""
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.raise_for_status.side_effect = Exception("401")
        mock_get.return_value = mock_response

        result = await service._fetch_personal_info("bad-token")
        assert result == {}
