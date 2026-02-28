"""
Zuralog Cloud Brain — LLM Client.

Async wrapper around the OpenAI SDK configured for OpenRouter.
Provides a model-agnostic interface for chat completions with
optional function-calling (tool use). Uses AsyncOpenAI for
built-in retries, streaming, and structured tool_call parsing.

The client is designed to be instantiated once during application
lifespan and shared across requests.
"""

import logging
from typing import Any

import sentry_sdk
from openai import AsyncOpenAI, APIError

from app.config import settings

logger = logging.getLogger(__name__)


class LLMClient:
    """Async LLM client wrapping OpenRouter via the OpenAI SDK.

    Uses AsyncOpenAI pointed at the OpenRouter base URL. Supports
    chat completions with optional tool definitions for function-calling.

    Attributes:
        model: The default model identifier (e.g. ``moonshotai/kimi-k2.5``).
        _client: The underlying AsyncOpenAI client instance.
    """

    def __init__(self, model: str | None = None) -> None:
        """Create a new LLM client.

        Args:
            model: Override the default model from settings.
                Defaults to ``settings.openrouter_model``.
        """
        self.model: str = model or settings.openrouter_model
        if not settings.openrouter_api_key:
            logger.warning("OPENROUTER_API_KEY is not set — LLM calls will fail with 401. Set it in cloud-brain/.env")
        self._client = AsyncOpenAI(
            api_key=settings.openrouter_api_key,
            base_url="https://openrouter.ai/api/v1",
            default_headers={
                "HTTP-Referer": settings.openrouter_referer,
                "X-Title": settings.openrouter_title,
            },
            max_retries=3,
            timeout=60.0,
        )

    async def chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        temperature: float = 0.7,
    ) -> Any:
        """Send a chat completion request to the LLM.

        Args:
            messages: The conversation history in OpenAI message format.
            tools: Optional list of tool definitions for function-calling.
            temperature: Sampling temperature (0.0-2.0). Defaults to 0.7.

        Returns:
            The full ChatCompletion response object from the OpenAI SDK.

        Raises:
            openai.APIError: On API communication failures (after retries).
        """
        kwargs: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
        }

        if tools:
            kwargs["tools"] = tools

        logger.debug(
            "LLM request: model=%s, messages=%d, tools=%s",
            self.model,
            len(messages),
            len(tools) if tools else 0,
        )

        try:
            response = await self._client.chat.completions.create(**kwargs)
        except APIError as e:
            sentry_sdk.capture_exception(e)
            raise

        logger.info(
            "LLM response: model=%s, tokens_in=%d, tokens_out=%d",
            self.model,
            response.usage.prompt_tokens if response.usage else 0,
            response.usage.completion_tokens if response.usage else 0,
        )

        return response

    async def stream_chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        temperature: float = 0.7,
    ) -> Any:
        """Stream a chat completion response from the LLM.

        Returns an async iterator of chat completion chunks for
        lower-latency token-by-token delivery.

        Args:
            messages: The conversation history in OpenAI message format.
            tools: Optional list of tool definitions for function-calling.
            temperature: Sampling temperature. Defaults to 0.7.

        Returns:
            An async stream of ChatCompletionChunk objects.
        """
        kwargs: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": True,
        }

        if tools:
            kwargs["tools"] = tools

        try:
            return await self._client.chat.completions.create(**kwargs)
        except APIError as e:
            sentry_sdk.capture_exception(e)
            raise
