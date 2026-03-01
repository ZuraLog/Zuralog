"""Withings HMAC SHA-256 request signing service.

Withings requires every API call to include a signature computed from
a fresh nonce. This is unique among ZuraLog's integrations.

Flow per API call:
1. POST /v2/signature (action=getnonce) -> get transient nonce
2. Compute HMAC-SHA256(client_secret, "action,client_id,nonce")
3. Include action, client_id, nonce, signature in the API request body
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import time
from typing import Any

import httpx

logger = logging.getLogger(__name__)

_SIGNATURE_URL = "https://wbsapi.withings.net/v2/signature"


class WithingsSignatureService:
    """Handles HMAC SHA-256 nonce+signature for Withings API calls."""

    def __init__(self, client_id: str, client_secret: str) -> None:
        self._client_id = client_id
        self._client_secret = client_secret

    def compute_signature(
        self,
        action: str,
        client_id: str,
        timestamp: int | None = None,
        nonce: str | None = None,
    ) -> str:
        """Compute HMAC-SHA256 signature.

        For getnonce requests: concatenate action,client_id,timestamp
        For API requests: concatenate action,client_id,nonce
        """
        if timestamp is not None:
            data = f"{action},{client_id},{timestamp}"
        elif nonce is not None:
            data = f"{action},{client_id},{nonce}"
        else:
            raise ValueError("Either timestamp or nonce must be provided")

        return hmac.new(
            self._client_secret.encode("utf-8"),
            data.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    async def get_nonce(self) -> str:
        """Fetch a fresh nonce from Withings signature endpoint.

        Each nonce is single-use and transient.
        """
        timestamp = int(time.time())
        signature = self.compute_signature(
            action="getnonce",
            client_id=self._client_id,
            timestamp=timestamp,
        )

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                _SIGNATURE_URL,
                data={
                    "action": "getnonce",
                    "client_id": self._client_id,
                    "timestamp": timestamp,
                    "signature": signature,
                },
            )
            response.raise_for_status()

        body = response.json()
        if body.get("status") != 0:
            raise Exception(
                f"Withings getnonce failed: status={body.get('status')}, error={body.get('error', 'unknown')}"
            )

        return body["body"]["nonce"]

    async def prepare_signed_params(
        self,
        action: str,
        extra_params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Full pipeline: get nonce, compute signature, merge params.

        Returns a dict ready to be sent as POST form data to Withings.
        """
        nonce = await self.get_nonce()
        signature = self.compute_signature(
            action=action,
            client_id=self._client_id,
            nonce=nonce,
        )

        params: dict[str, Any] = {
            "action": action,
            "client_id": self._client_id,
            "nonce": nonce,
            "signature": signature,
        }
        if extra_params:
            params.update(extra_params)

        return params
