"""
Life Logger Cloud Brain — Supabase Auth Service.

Handles authentication operations by calling the Supabase Auth REST API
directly via httpx. This avoids the heavy supabase-py SDK and its
transitive dependencies — we only need 4 HTTP endpoints.

All methods return structured data or raise HTTPExceptions with
appropriate status codes and messages.
"""

import httpx
from fastapi import HTTPException, status

from app.config import settings


class AuthService:
    """Service for Supabase Auth REST API interactions.

    Uses httpx.AsyncClient to communicate with Supabase GoTrue endpoints.
    The client is managed externally (via FastAPI lifespan) and injected
    to allow connection pooling and clean shutdown.

    Attributes:
        _client: The shared httpx async client.
        _base_url: Supabase project URL.
        _api_key: Supabase anonymous key for auth requests.
    """

    def __init__(self, client: httpx.AsyncClient) -> None:
        """Creates a new AuthService.

        Args:
            client: A shared httpx.AsyncClient instance.
        """
        self._client = client
        self._base_url = settings.supabase_url
        self._api_key = settings.supabase_anon_key

    def _auth_url(self, path: str) -> str:
        """Builds a full Supabase Auth API URL.

        Args:
            path: The endpoint path (e.g., '/signup', '/token').

        Returns:
            The full URL string.
        """
        return f"{self._base_url}/auth/v1{path}"

    def _headers(self, *, access_token: str | None = None) -> dict[str, str]:
        """Builds request headers for Supabase Auth calls.

        Args:
            access_token: Optional bearer token for authenticated requests.

        Returns:
            A dictionary of HTTP headers.
        """
        headers = {
            "apikey": self._api_key,
            "Content-Type": "application/json",
        }
        if access_token:
            headers["Authorization"] = f"Bearer {access_token}"
        return headers

    async def sign_up(self, email: str, password: str) -> dict:
        """Registers a new user with Supabase Auth.

        Args:
            email: The new user's email address.
            password: The new user's password.

        Returns:
            A dict with keys: user_id, access_token, refresh_token, expires_in.

        Raises:
            HTTPException: 400 if registration fails (e.g., email taken).
        """
        response = await self._client.post(
            self._auth_url("/signup"),
            headers=self._headers(),
            json={"email": email, "password": password},
        )

        if response.status_code != 200:
            detail = self._extract_error(response)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Registration failed: {detail}",
            )

        data = response.json()
        session = data.get("session")

        # Supabase returns the user object either nested under "user" (auto-confirm on)
        # or directly at the top level (email confirmation required).
        user = data.get("user") or data

        # Supabase may return a user without a session if email confirmation
        # is enabled. In that case, there are no tokens to return yet.
        if not session:
            return {
                "user_id": user["id"],
                "access_token": "",
                "refresh_token": "",
                "expires_in": 0,
            }

        return {
            "user_id": user["id"],
            "access_token": session["access_token"],
            "refresh_token": session["refresh_token"],
            "expires_in": session.get("expires_in", 3600),
        }

    async def sign_in(self, email: str, password: str) -> dict:
        """Authenticates an existing user with Supabase Auth.

        Args:
            email: The user's email address.
            password: The user's password.

        Returns:
            A dict with keys: user_id, access_token, refresh_token, expires_in.

        Raises:
            HTTPException: 401 if credentials are invalid.
        """
        response = await self._client.post(
            self._auth_url("/token?grant_type=password"),
            headers=self._headers(),
            json={"email": email, "password": password},
        )

        if response.status_code != 200:
            detail = self._extract_error(response)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid credentials: {detail}",
            )

        data = response.json()
        return {
            "user_id": data["user"]["id"],
            "access_token": data["access_token"],
            "refresh_token": data["refresh_token"],
            "expires_in": data.get("expires_in", 3600),
        }

    async def sign_out(self, access_token: str) -> None:
        """Invalidates a user's session with Supabase Auth.

        Calls Supabase logout with the user's own access token, NOT the
        service key. This correctly invalidates the user's session.

        Args:
            access_token: The user's current JWT access token.

        Raises:
            HTTPException: 400 if logout fails.
        """
        response = await self._client.post(
            self._auth_url("/logout"),
            headers=self._headers(access_token=access_token),
        )

        if response.status_code not in (200, 204):
            detail = self._extract_error(response)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Logout failed: {detail}",
            )

    async def refresh_session(self, refresh_token: str) -> dict:
        """Exchanges a refresh token for a new session.

        Args:
            refresh_token: The long-lived refresh token from a prior login.

        Returns:
            A dict with keys: user_id, access_token, refresh_token, expires_in.

        Raises:
            HTTPException: 401 if the refresh token is invalid or expired.
        """
        response = await self._client.post(
            self._auth_url("/token?grant_type=refresh_token"),
            headers=self._headers(),
            json={"refresh_token": refresh_token},
        )

        if response.status_code != 200:
            detail = self._extract_error(response)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token refresh failed: {detail}",
            )

        data = response.json()
        return {
            "user_id": data["user"]["id"],
            "access_token": data["access_token"],
            "refresh_token": data["refresh_token"],
            "expires_in": data.get("expires_in", 3600),
        }

    async def get_user(self, access_token: str) -> dict:
        """Retrieves and validates the user profile using their access token.

        Args:
            access_token: The user's current JWT access token.

        Returns:
            A dict containing the user's data from Supabase.

        Raises:
            HTTPException: 401 if the access token is invalid or expired.
        """
        response = await self._client.get(
            self._auth_url("/user"),
            headers=self._headers(access_token=access_token),
        )

        if response.status_code != 200:
            detail = self._extract_error(response)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token: {detail}",
            )

        return response.json()

    @staticmethod
    def _extract_error(response: httpx.Response) -> str:
        """Extracts a human-readable error message from a Supabase response.

        Supabase GoTrue returns errors in various formats; this method
        normalizes them into a single string.

        Args:
            response: The httpx response object.

        Returns:
            A descriptive error string.
        """
        try:
            data = response.json()
            # GoTrue v2 format
            if "error_description" in data:
                return data["error_description"]
            if "msg" in data:
                return data["msg"]
            if "message" in data:
                return data["message"]
            return str(data)
        except Exception:
            return f"HTTP {response.status_code}"
