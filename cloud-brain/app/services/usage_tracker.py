"""
Zuralog Cloud Brain — Usage Tracker Service.

Tracks per-request LLM token consumption by parsing the 'usage'
field from OpenAI-compatible API responses.
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.usage_log import UsageLog

logger = logging.getLogger(__name__)


class UsageTracker:
    """Tracks LLM token usage per request.

    Attributes:
        _session: The async database session.
    """

    def __init__(self, session: AsyncSession) -> None:
        """Create a new UsageTracker.

        Args:
            session: An async SQLAlchemy session.
        """
        self._session = session

    async def track(
        self,
        user_id: str,
        model: str,
        input_tokens: int,
        output_tokens: int,
    ) -> None:
        """Record a single LLM usage event.

        Args:
            user_id: The user who triggered the request.
            model: The LLM model identifier.
            input_tokens: Prompt tokens consumed.
            output_tokens: Completion tokens generated.
        """
        log = UsageLog(
            user_id=user_id,
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )
        self._session.add(log)
        await self._session.commit()
        logger.info(
            "Usage tracked: user=%s model=%s in=%d out=%d",
            user_id,
            model,
            input_tokens,
            output_tokens,
        )

    async def track_from_response(self, user_id: str, response: Any) -> None:
        """Extract usage from an OpenAI response and record it.

        Args:
            user_id: The user who triggered the request.
            response: The ChatCompletion response from the OpenAI SDK.
        """
        usage = getattr(response, "usage", None)
        model = getattr(response, "model", "unknown")
        input_tokens = getattr(usage, "prompt_tokens", 0) if usage else 0
        output_tokens = getattr(usage, "completion_tokens", 0) if usage else 0
        await self.track(user_id, model, input_tokens, output_tokens)
