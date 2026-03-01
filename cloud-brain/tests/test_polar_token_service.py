# tests/test_polar_token_service.py
"""Tests for PolarTokenService — OAuth 2.0 auth code flow, token lifecycle, and DB ops."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.polar_token_service import PolarTokenService


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
    return PolarTokenService()


# ---------------------------------------------------------------------------
# Build auth URL
# ---------------------------------------------------------------------------


class TestBuildAuthUrl:
    """Tests for Polar OAuth 2.0 authorization URL construction."""

    def test_points_to_polar_authorize_endpoint(self, service):
        """Auth URL uses the Polar Flow authorization endpoint."""
        url = service.build_auth_url(state="state-abc")
        assert url.startswith("https://flow.polar.com/oauth2/authorization")

    def test_contains_state(self, service):
        """Auth URL includes the state parameter."""
        url = service.build_auth_url(state="my-csrf-state")
        assert "state=my-csrf-state" in url

    def test_response_type_is_code(self, service):
        """Auth URL uses response_type=code."""
        url = service.build_auth_url(state="s")
        assert "response_type=code" in url

    def test_contains_client_id_from_settings(self, service):
        """Auth URL includes client_id from settings."""
        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "test-polar-client"
            mock_settings.polar_redirect_uri = "zuralog://oauth/polar"
            url = service.build_auth_url(state="s")
        assert "test-polar-client" in url

    def test_contains_redirect_uri_from_settings(self, service):
        """Auth URL includes redirect_uri from settings."""
        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "cid"
            mock_settings.polar_redirect_uri = "zuralog://oauth/polar"
            url = service.build_auth_url(state="s")
        assert "redirect_uri=" in url


# ---------------------------------------------------------------------------
# Redis state storage (anti-CSRF)
# ---------------------------------------------------------------------------


class TestStoreState:
    """Tests for CSRF state storage in Redis with user_id payload."""

    @pytest.mark.asyncio
    async def test_store_sets_key_with_600s_ttl(self, service):
        """store_state calls redis.setex with correct key, 600s TTL, and user_id value."""
        redis = AsyncMock()
        await service.store_state("csrf-state-xyz", "user-abc", redis)
        redis.setex.assert_called_once_with("polar:state:csrf-state-xyz", 600, "user-abc")

    @pytest.mark.asyncio
    async def test_store_uses_polar_prefix(self, service):
        """Key must use 'polar:state:' prefix (not oura or other providers)."""
        redis = AsyncMock()
        await service.store_state("abc", "user-123", redis)
        call_args = redis.setex.call_args
        key = call_args[0][0] if call_args[0] else call_args.args[0]
        assert key.startswith("polar:state:")

    @pytest.mark.asyncio
    async def test_store_saves_user_id_as_value(self, service):
        """store_state saves the user_id (not '1') as the Redis value."""
        redis = AsyncMock()
        await service.store_state("state-xyz", "user-999", redis)
        call_args = redis.setex.call_args
        value = call_args[0][2] if call_args[0] else call_args.args[2]
        assert value == "user-999"


# ---------------------------------------------------------------------------
# Redis state validation (anti-CSRF)
# ---------------------------------------------------------------------------


class TestValidateState:
    """Tests for CSRF state validation from Redis — returns user_id or None."""

    @pytest.mark.asyncio
    async def test_returns_user_id_when_state_found(self, service):
        """validate_state returns the stored user_id (decoded) when found."""
        redis = AsyncMock()
        redis.getdel.return_value = b"user-abc"
        result = await service.validate_state("valid-state", redis)
        assert result == "user-abc"

    @pytest.mark.asyncio
    async def test_returns_none_when_state_not_found(self, service):
        """validate_state returns None when state key is missing or expired."""
        redis = AsyncMock()
        redis.getdel.return_value = None
        result = await service.validate_state("missing-state", redis)
        assert result is None

    @pytest.mark.asyncio
    async def test_uses_atomic_getdel(self, service):
        """validate_state uses atomic GETDEL (not GET + DELETE) to prevent TOCTOU race."""
        redis = AsyncMock()
        redis.getdel.return_value = b"user-abc"
        await service.validate_state("used-state", redis)
        redis.getdel.assert_called_once_with("polar:state:used-state")
        # Must NOT use separate GET + DELETE calls
        redis.get.assert_not_called()
        redis.delete.assert_not_called()

    @pytest.mark.asyncio
    async def test_decodes_bytes_to_string(self, service):
        """validate_state decodes bytes returned from Redis to a plain string."""
        redis = AsyncMock()
        redis.getdel.return_value = b"user-decoded"
        result = await service.validate_state("some-state", redis)
        assert isinstance(result, str)
        assert result == "user-decoded"


# ---------------------------------------------------------------------------
# Code exchange
# ---------------------------------------------------------------------------


class TestExchangeCode:
    """Tests for exchanging an authorization code for Polar tokens."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_sends_basic_auth_header(self, mock_post, service):
        """exchange_code sends Authorization: Basic header (not POST body creds)."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "token_type": "Bearer",
            "expires_in": 31535999,
            "x_user_id": 12345,
        }
        mock_post.return_value = mock_response

        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "my-client"
            mock_settings.polar_client_secret = "my-secret"
            await service.exchange_code("code123")

        call_kwargs = mock_post.call_args
        headers = call_kwargs.kwargs.get("headers", {})
        assert "Authorization" in headers
        assert headers["Authorization"].startswith("Basic ")

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_sends_form_encoded_body(self, mock_post, service):
        """exchange_code sends form-encoded body with grant_type and code."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "token_type": "Bearer",
            "expires_in": 31535999,
            "x_user_id": 12345,
        }
        mock_post.return_value = mock_response

        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "cid"
            mock_settings.polar_client_secret = "csecret"
            await service.exchange_code("code-abc")

        call_kwargs = mock_post.call_args
        data = call_kwargs.kwargs.get("data", {})
        assert data.get("grant_type") == "authorization_code"
        assert data.get("code") == "code-abc"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_posts_to_polar_token_url(self, mock_post, service):
        """exchange_code POSTs to the correct Polar token URL."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "token_type": "Bearer",
            "expires_in": 31535999,
            "x_user_id": 12345,
        }
        mock_post.return_value = mock_response

        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "cid"
            mock_settings.polar_client_secret = "csecret"
            await service.exchange_code("c")

        call_args = mock_post.call_args
        url = call_args.args[0] if call_args.args else call_args.kwargs.get("url", "")
        assert "polarremote.com" in url
        assert "token" in url

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_returns_token_dict(self, mock_post, service):
        """exchange_code returns the parsed JSON response dict."""
        token_data = {
            "access_token": "polar-at-123",
            "token_type": "Bearer",
            "expires_in": 31535999,
            "x_user_id": 99999,
        }
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = token_data
        mock_post.return_value = mock_response

        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "cid"
            mock_settings.polar_client_secret = "csecret"
            result = await service.exchange_code("c")

        assert result == token_data

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_raises_on_non_2xx(self, mock_post, service):
        """exchange_code raises httpx.HTTPStatusError on non-2xx response."""
        import httpx

        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.raise_for_status.side_effect = httpx.HTTPStatusError(
            "Unauthorized", request=MagicMock(), response=mock_response
        )
        mock_post.return_value = mock_response

        with patch("app.services.polar_token_service.settings") as mock_settings:
            mock_settings.polar_client_id = "cid"
            mock_settings.polar_client_secret = "csecret"
            with pytest.raises(httpx.HTTPStatusError):
                await service.exchange_code("bad-code")


# ---------------------------------------------------------------------------
# Register user
# ---------------------------------------------------------------------------


class TestRegisterUser:
    """Tests for Polar AccessLink user registration."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_sends_bearer_token(self, mock_post, service):
        """register_user sends Authorization: Bearer header."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"polar-user-id": 12345, "member-id": "usr-1"}
        mock_post.return_value = mock_response

        await service.register_user("my-token", "usr-1")

        call_kwargs = mock_post.call_args
        headers = call_kwargs.kwargs.get("headers", {})
        assert headers.get("Authorization") == "Bearer my-token"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_posts_to_v3_users_endpoint(self, mock_post, service):
        """register_user POSTs to /v3/users on polaraccesslink.com."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"polar-user-id": 12345}
        mock_post.return_value = mock_response

        await service.register_user("token", "member-123")

        call_args = mock_post.call_args
        url = call_args.args[0] if call_args.args else call_args.kwargs.get("url", "")
        assert "polaraccesslink.com" in url
        assert "v3/users" in url

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_sends_member_id_in_body(self, mock_post, service):
        """register_user sends member-id in JSON request body."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"polar-user-id": 12345}
        mock_post.return_value = mock_response

        await service.register_user("token", "member-xyz")

        call_kwargs = mock_post.call_args
        json_body = call_kwargs.kwargs.get("json", {})
        assert json_body.get("member-id") == "member-xyz"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_returns_user_dict_on_200(self, mock_post, service):
        """register_user returns user dict on successful 200 response."""
        user_data = {"polar-user-id": 12345, "member-id": "usr-1"}
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = user_data
        mock_post.return_value = mock_response

        result = await service.register_user("token", "usr-1")
        assert result == user_data

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    @patch("httpx.AsyncClient.post")
    async def test_handles_409_already_registered(self, mock_post, mock_get, service):
        """register_user handles 409 (already registered) by fetching user info."""
        mock_post_response = MagicMock()
        mock_post_response.status_code = 409
        mock_post.return_value = mock_post_response

        mock_get_response = MagicMock()
        mock_get_response.status_code = 200
        mock_get_response.json.return_value = {"polar-user-id": 12345, "first-name": "John"}
        mock_get.return_value = mock_get_response

        # The 409 case calls _get_user_info; we need to make polar_user_id retrievable
        # For 409, we typically pass the x_user_id or look up from the conflict
        result = await service.register_user("token", "member-xyz")

        # Should not raise, should return some user dict (from _get_user_info)
        assert isinstance(result, dict)

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_get_user_info_returns_dict(self, mock_get, service):
        """_get_user_info returns user dict from GET /v3/users/{polar_user_id}."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"polar-user-id": 99999, "first-name": "Jane"}
        mock_get.return_value = mock_response

        result = await service._get_user_info("token", 99999)
        assert result.get("first-name") == "Jane"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get", side_effect=Exception("network error"))
    async def test_get_user_info_returns_empty_on_error(self, mock_get, service):
        """_get_user_info returns {} on any error (never raises)."""
        result = await service._get_user_info("token", 99999)
        assert result == {}


# ---------------------------------------------------------------------------
# Save tokens
# ---------------------------------------------------------------------------


class TestSaveTokens:
    """Tests for persisting Polar OAuth tokens and metadata."""

    @pytest.mark.asyncio
    async def test_creates_new_integration(self, service, mock_db):
        """Creates a new row when no existing Polar integration exists."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {
            "access_token": "at-abc",
            "token_type": "Bearer",
            "expires_in": 31535999,
            "x_user_id": 12345,
        }
        user_info = {
            "first-name": "John",
            "last-name": "Doe",
            "registration-date": "2024-01-01",
            "weight": 75.0,
            "height": 180,
            "gender": "MALE",
            "birthdate": "1990-01-01",
        }

        await service.save_tokens(mock_db, "user-123", token_response, user_info)

        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_new_integration_has_correct_provider(self, service, mock_db):
        """New integration is created with provider='polar'."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {"access_token": "at", "expires_in": 31535999, "x_user_id": 1}
        user_info = {}

        await service.save_tokens(mock_db, "user-123", token_response, user_info)

        added = mock_db.add.call_args[0][0]
        assert added.provider == "polar"

    @pytest.mark.asyncio
    async def test_stores_metadata_from_user_info(self, service, mock_db):
        """Stores polar_user_id and user profile fields in provider_metadata."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {"access_token": "at", "expires_in": 31535999, "x_user_id": 99999}
        user_info = {
            "first-name": "Jane",
            "last-name": "Smith",
            "weight": 60.0,
            "height": 165,
            "gender": "FEMALE",
            "birthdate": "1995-06-15",
            "registration-date": "2024-01-01",
        }

        await service.save_tokens(mock_db, "user-123", token_response, user_info)

        added = mock_db.add.call_args[0][0]
        meta = added.provider_metadata
        assert meta["polar_user_id"] == 99999
        assert meta["first_name"] == "Jane"
        assert meta["last_name"] == "Smith"
        assert meta["weight"] == 60.0
        assert meta["gender"] == "FEMALE"

    @pytest.mark.asyncio
    async def test_token_expires_at_computed_correctly(self, service, mock_db):
        """token_expires_at is set to now + expires_in seconds."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {"access_token": "at", "expires_in": 3600, "x_user_id": 1}
        user_info = {}

        before = datetime.now(timezone.utc)
        await service.save_tokens(mock_db, "user-123", token_response, user_info)
        after = datetime.now(timezone.utc)

        added = mock_db.add.call_args[0][0]
        expected_min = before + timedelta(seconds=3600)
        expected_max = after + timedelta(seconds=3600)
        assert expected_min <= added.token_expires_at <= expected_max

    @pytest.mark.asyncio
    async def test_refresh_token_is_none(self, service, mock_db):
        """Polar has no refresh tokens — refresh_token is always None."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {"access_token": "at", "expires_in": 31535999, "x_user_id": 1}

        await service.save_tokens(mock_db, "user-123", token_response, {})

        added = mock_db.add.call_args[0][0]
        assert added.refresh_token is None

    @pytest.mark.asyncio
    async def test_updates_existing_integration(self, service, mock_db):
        """Updates tokens in place when a Polar integration already exists."""
        existing = MagicMock()
        existing.access_token = "old-at"
        existing.provider_metadata = {"polar_user_id": 12345}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        token_response = {"access_token": "new-at", "expires_in": 31535999, "x_user_id": 12345}

        await service.save_tokens(mock_db, "user-123", token_response, {})

        assert existing.access_token == "new-at"
        mock_db.commit.assert_called_once()
        # db.add should NOT be called for an update
        mock_db.add.assert_not_called()

    @pytest.mark.asyncio
    async def test_sets_is_active_true_and_resets_error(self, service, mock_db):
        """save_tokens sets is_active=True, sync_status='idle', sync_error=None."""
        existing = MagicMock()
        existing.sync_status = "error"
        existing.sync_error = "Previous error"
        existing.is_active = False
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        token_response = {"access_token": "at", "expires_in": 31535999, "x_user_id": 1}

        await service.save_tokens(mock_db, "user-123", token_response, {})

        assert existing.is_active is True
        assert existing.sync_status == "idle"
        assert existing.sync_error is None


# ---------------------------------------------------------------------------
# Get access token
# ---------------------------------------------------------------------------


class TestGetAccessToken:
    """Tests for retrieving a valid Polar access token."""

    @pytest.mark.asyncio
    async def test_returns_token_when_not_expired(self, service, mock_db):
        """Returns access_token when integration is valid and not expired."""
        future = datetime.now(timezone.utc) + timedelta(days=30)
        integration = MagicMock()
        integration.access_token = "valid-polar-token"
        integration.token_expires_at = future
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "valid-polar-token"

    @pytest.mark.asyncio
    async def test_returns_none_when_no_integration(self, service, mock_db):
        """Returns None when user has no active Polar integration."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-999")
        assert token is None

    @pytest.mark.asyncio
    async def test_returns_none_when_expired(self, service, mock_db):
        """Returns None when the access token has expired (Polar has no refresh)."""
        past = datetime.now(timezone.utc) - timedelta(days=1)
        integration = MagicMock()
        integration.access_token = "expired-token"
        integration.token_expires_at = past
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token is None

    @pytest.mark.asyncio
    async def test_returns_token_when_expires_at_is_none(self, service, mock_db):
        """Returns token when token_expires_at is None (no expiry set = treat as valid)."""
        integration = MagicMock()
        integration.access_token = "token"
        integration.token_expires_at = None
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        # When no expiry set, we delegate to get_integration; with no expiry we
        # should not blindly return the token — service returns None for safety.
        # Note: The spec says "returns None if token_expires_at < now (expired)"
        # so None expiry is treated as: not expired → return token. Let's verify
        # the actual spec behavior: returns access_token otherwise.
        # We'll test None expiry as returning the token (not expired).
        token = await service.get_access_token(mock_db, "user-123")
        # None expiry → no expiry check → return token
        assert token == "token"


# ---------------------------------------------------------------------------
# Get integration
# ---------------------------------------------------------------------------


class TestGetIntegration:
    """Tests for fetching the active Polar integration row."""

    @pytest.mark.asyncio
    async def test_returns_integration_when_found(self, service, mock_db):
        """Returns the active Integration when one exists."""
        integration = MagicMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        result = await service.get_integration(mock_db, "user-123")
        assert result is integration

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, service, mock_db):
        """Returns None when no active Polar integration exists for the user."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.get_integration(mock_db, "user-999")
        assert result is None


# ---------------------------------------------------------------------------
# Disconnect
# ---------------------------------------------------------------------------


class TestDisconnect:
    """Tests for deactivating a Polar integration."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.delete", new_callable=AsyncMock)
    async def test_disconnect_deactivates_integration(self, mock_delete, service, mock_db):
        """disconnect sets is_active=False, clears access_token, and commits."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = "some-token"
        integration.provider_metadata = {"polar_user_id": 12345}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        result = await service.disconnect(mock_db, "user-123")

        assert result is True
        assert integration.is_active is False
        assert integration.access_token is None
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
    @patch("httpx.AsyncClient.delete", new_callable=AsyncMock)
    async def test_disconnect_calls_polar_delete_api(self, mock_delete, service, mock_db):
        """disconnect calls DELETE on the Polar API for the user."""
        integration = MagicMock()
        integration.access_token = "token"
        integration.provider_metadata = {"polar_user_id": 99999}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        await service.disconnect(mock_db, "user-123")

        mock_delete.assert_called_once()
        call_args = mock_delete.call_args
        url = call_args.args[0] if call_args.args else call_args.kwargs.get("url", "")
        assert "polaraccesslink.com" in url
        assert "99999" in url

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.delete", side_effect=Exception("network error"))
    async def test_disconnect_swallows_delete_exception(self, mock_delete, service, mock_db):
        """disconnect continues even if Polar DELETE API call raises an exception."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = "token"
        integration.provider_metadata = {"polar_user_id": 12345}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        # Should not raise; exception is swallowed (best-effort)
        result = await service.disconnect(mock_db, "user-123")

        assert result is True
        assert integration.is_active is False
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_sets_sync_status_idle(self, service, mock_db):
        """disconnect resets sync_status to 'idle' on deactivation."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = None
        integration.provider_metadata = {}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        await service.disconnect(mock_db, "user-123")

        assert integration.sync_status == "idle"
