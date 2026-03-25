"""
Zuralog Cloud Brain — Supabase Storage Service.

Wraps the Supabase Storage REST API via httpx for file upload,
signed URL generation, and deletion. Uses the service role key
so clients never need direct storage access.

All methods raise HTTPExceptions with appropriate status codes.
"""

import logging

import httpx
from fastapi import HTTPException, status

from app.config import settings

logger = logging.getLogger(__name__)


class StorageService:
    """Service for Supabase Storage REST API interactions.

    Uses httpx.AsyncClient to communicate with Supabase Storage endpoints.
    Authenticated with the service role key (not the anon key) so the
    backend can upload on behalf of any user without RLS restrictions.

    Attributes:
        _client: The shared httpx async client.
        _base_url: Supabase project URL.
        _service_key: Supabase service role key for storage requests.
    """

    def __init__(self, client: httpx.AsyncClient) -> None:
        """Creates a new StorageService.

        Args:
            client: A shared httpx.AsyncClient instance.
        """
        self._client = client
        self._base_url = settings.supabase_url.strip().rstrip("/")
        self._service_key = settings.supabase_service_key.get_secret_value().strip()

        if not self._base_url:
            logger.warning(
                "SUPABASE_URL is empty — all storage requests will fail. "
                "Set the SUPABASE_URL environment variable."
            )
        if not self._service_key:
            logger.warning(
                "SUPABASE_SERVICE_KEY is empty — all storage requests will fail. "
                "Set the SUPABASE_SERVICE_KEY environment variable."
            )

    def _storage_url(self, path: str) -> str:
        """Builds a full Supabase Storage API URL.

        Args:
            path: The endpoint path (e.g., '/object/bucket/file.jpg').

        Returns:
            The full URL string.
        """
        return f"{self._base_url}/storage/v1{path}"

    def _headers(self, *, content_type: str | None = None) -> dict[str, str]:
        """Builds request headers for Supabase Storage calls.

        Args:
            content_type: Optional Content-Type override for uploads.

        Returns:
            A dictionary of HTTP headers.
        """
        headers: dict[str, str] = {
            "Authorization": f"Bearer {self._service_key}",
            "apikey": self._service_key,
        }
        if content_type:
            headers["Content-Type"] = content_type
        return headers

    async def upload_file(
        self,
        bucket: str,
        path: str,
        content: bytes,
        content_type: str,
        upsert: bool = False,
    ) -> str:
        """Uploads a file to Supabase Storage.

        Args:
            bucket: The storage bucket name (e.g., 'chat-attachments').
            path: Object path within the bucket (e.g., 'user-id/uuid/photo.jpg').
            content: Raw file bytes.
            content_type: MIME type of the file (e.g., 'image/jpeg').
            upsert: When True, overwrite an existing object at the same path
                instead of failing with a conflict error. Sends the
                ``x-upsert: true`` header to the Supabase Storage API.

        Returns:
            The storage path ('{bucket}/{path}') for later retrieval.

        Raises:
            HTTPException: 502 on upload failure, 503 if unconfigured.
        """
        if not self._base_url:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Storage service unavailable: SUPABASE_URL not configured.",
            )

        url = self._storage_url(f"/object/{bucket}/{path}")
        headers = self._headers(content_type=content_type)
        if upsert:
            headers["x-upsert"] = "true"

        try:
            response = await self._client.post(url, headers=headers, content=content)
        except httpx.TimeoutException:
            logger.error("Storage upload timed out: %s/%s", bucket, path)
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="Storage upload timed out. Please try again.",
            )
        except httpx.HTTPError as exc:
            logger.error("Storage upload failed: %s — %s", url, exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Storage upload error: {type(exc).__name__}",
            )

        if response.status_code not in (200, 201):
            detail = self._extract_error(response)
            logger.error("Storage upload rejected (%d): %s", response.status_code, detail)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Storage upload failed: {detail}",
            )

        logger.info("Uploaded %s/%s (%d bytes)", bucket, path, len(content))
        return f"{bucket}/{path}"

    async def get_signed_url(self, bucket: str, path: str, expires_in: int = 3600) -> str:
        """Generates a time-limited signed URL for a stored file.

        Args:
            bucket: The storage bucket name.
            path: Object path within the bucket.
            expires_in: URL validity in seconds (default 1 hour).

        Returns:
            A fully qualified signed URL for the file.

        Raises:
            HTTPException: 502 on failure, 503 if unconfigured.
        """
        if not self._base_url:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Storage service unavailable: SUPABASE_URL not configured.",
            )

        url = self._storage_url(f"/object/sign/{bucket}/{path}")
        headers = self._headers(content_type="application/json")

        try:
            response = await self._client.post(
                url,
                headers=headers,
                json={"expiresIn": expires_in},
            )
        except httpx.HTTPError as exc:
            logger.error("Signed URL request failed: %s — %s", url, exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Storage signed URL error: {type(exc).__name__}",
            )

        if response.status_code != 200:
            detail = self._extract_error(response)
            logger.error("Signed URL rejected (%d): %s", response.status_code, detail)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Signed URL failed: {detail}",
            )

        data = response.json()
        signed_path = data.get("signedURL", "")
        return f"{self._base_url}/storage/v1{signed_path}"

    async def download_file(self, bucket: str, path: str) -> bytes:
        """Downloads a file's raw bytes from Supabase Storage.

        Uses the service key to access the file directly without a signed URL.

        Args:
            bucket: The storage bucket name.
            path: Object path within the bucket.

        Returns:
            The raw file bytes.

        Raises:
            HTTPException: 502 on failure, 503 if unconfigured.
        """
        if not self._base_url:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Storage service unavailable: SUPABASE_URL not configured.",
            )

        url = self._storage_url(f"/object/{bucket}/{path}")
        headers = self._headers()

        try:
            response = await self._client.get(url, headers=headers)
        except httpx.HTTPError as exc:
            logger.error("Storage download failed: %s — %s", url, exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Storage download error: {type(exc).__name__}",
            )

        if response.status_code != 200:
            detail = self._extract_error(response)
            logger.error("Storage download rejected (%d): %s", response.status_code, detail)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Storage download failed: {detail}",
            )

        return response.content

    async def delete_file(self, bucket: str, paths: list[str]) -> None:
        """Deletes one or more files from Supabase Storage.

        Args:
            bucket: The storage bucket name.
            paths: List of object paths within the bucket to delete.

        Raises:
            HTTPException: 502 on failure, 503 if unconfigured.
        """
        if not self._base_url:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Storage service unavailable: SUPABASE_URL not configured.",
            )

        url = self._storage_url(f"/object/{bucket}")
        headers = self._headers(content_type="application/json")

        try:
            response = await self._client.request(
                "DELETE",
                url,
                headers=headers,
                json={"prefixes": paths},
            )
        except httpx.HTTPError as exc:
            logger.error("Storage delete failed: %s — %s", url, exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Storage delete error: {type(exc).__name__}",
            )

        if response.status_code not in (200, 204):
            detail = self._extract_error(response)
            logger.warning("Storage delete rejected (%d): %s", response.status_code, detail)

        logger.info("Deleted %d file(s) from %s", len(paths), bucket)

    @staticmethod
    def _extract_error(response: httpx.Response) -> str:
        """Extracts a human-readable error from a Supabase Storage response.

        Args:
            response: The httpx response object.

        Returns:
            A descriptive error string.
        """
        try:
            data = response.json()
            if "message" in data:
                return data["message"]
            if "error" in data:
                return data["error"]
            if "statusCode" in data:
                return f"HTTP {data['statusCode']}: {data.get('error', 'Unknown')}"
            return str(data)
        except Exception:
            return f"HTTP {response.status_code}"
