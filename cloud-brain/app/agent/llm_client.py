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
import os
from typing import Any

import openai
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
        api_key = settings.openrouter_api_key.get_secret_value()
        if not api_key:
            logger.warning("OPENROUTER_API_KEY is not set — LLM calls will fail with 401. Set it in cloud-brain/.env")

        # Fix 4.3 (M-10): Warn if HTTPX debug logging is enabled in production
        if os.getenv("HTTPX_LOG_LEVEL", "").lower() == "debug" and settings.app_env == "production":
            logger.error("HTTPX_LOG_LEVEL=debug in production will expose API keys in logs!")

        self._client = AsyncOpenAI(
            api_key=api_key,
            base_url="https://openrouter.ai/api/v1",
            default_headers={
                "HTTP-Referer": settings.openrouter_referer,
                "X-Title": settings.openrouter_title,
            },
            max_retries=3,
            timeout=60.0,
        )

    async def _call_with_model(
        self,
        model: str,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        temperature: float = 0.7,
        max_tokens: int | None = None,
        response_format: dict[str, Any] | None = None,
        reasoning: dict[str, Any] | None = None,
        plugins: list[dict[str, Any]] | None = None,
    ) -> Any:
        """Internal helper to call the LLM with a specific model.

        Args:
            model: The model identifier to use.
            messages: The conversation history in OpenAI message format.
            tools: Optional list of tool definitions for function-calling.
            temperature: Sampling temperature (0.0-2.0). Defaults to 0.7.
            max_tokens: Optional cap on the number of tokens in the response.
            response_format: Optional response format spec forwarded to the
                OpenAI SDK. Use ``{"type": "json_object"}`` to force JSON mode.
            reasoning: Optional OpenRouter unified reasoning control. Pass
                ``{"effort": "none"}`` to disable reasoning on reasoning-capable
                models (e.g. Gemini 3.1 Flash Lite, Kimi K2.5). This is critical for structured
                extraction — reasoning models otherwise spend their output
                tokens on hidden reasoning and return an empty content field.
            plugins: Optional list of OpenRouter plugins to enable for this
                request. Pass ``[{"id": "response-healing"}]`` to auto-repair
                malformed JSON (trailing commas, missing brackets, markdown
                fences) at the edge before the response reaches us.

        Returns:
            The full ChatCompletion response object from the OpenAI SDK.
        """
        kwargs: dict[str, Any] = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
        }

        if max_tokens is not None:
            kwargs["max_tokens"] = max_tokens

        if tools:
            kwargs["tools"] = tools

        if response_format is not None:
            kwargs["response_format"] = response_format

        # OpenRouter-specific fields ride through the OpenAI SDK's `extra_body`
        # escape hatch so they reach the OpenRouter endpoint unchanged.
        extra_body: dict[str, Any] = {}
        if reasoning is not None:
            extra_body["reasoning"] = reasoning
        if plugins is not None:
            extra_body["plugins"] = plugins
        if extra_body:
            kwargs["extra_body"] = extra_body

        response = await self._client.chat.completions.create(**kwargs)
        return response

    async def chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        temperature: float = 0.7,
        max_tokens: int | None = None,
        response_format: dict[str, Any] | None = None,
        reasoning: dict[str, Any] | None = None,
        plugins: list[dict[str, Any]] | None = None,
    ) -> Any:
        """Send a chat completion request to the LLM.

        Args:
            messages: The conversation history in OpenAI message format.
            tools: Optional list of tool definitions for function-calling.
            temperature: Sampling temperature (0.0-2.0). Defaults to 0.7.
            max_tokens: Optional cap on the number of tokens in the response.
            response_format: Optional response format spec forwarded to the
                OpenAI SDK. Use ``{"type": "json_object"}`` to force JSON mode
                on models that support it (e.g. MiniMax M2.7, Gemini 3.1).
            reasoning: Optional OpenRouter unified reasoning control. Pass
                ``{"effort": "none"}`` to disable reasoning on reasoning-capable
                models (e.g. Gemini 3.1 Flash Lite, Kimi K2.5). Critical for structured extraction
                — without this, reasoning models spend all output tokens on
                hidden reasoning and return empty content.
            plugins: Optional OpenRouter plugins array. Pass
                ``[{"id": "response-healing"}]`` to auto-repair malformed JSON
                at the edge (free; non-streaming only).

        Returns:
            The full ChatCompletion response object from the OpenAI SDK.

        Raises:
            openai.APIError: On API communication failures (after retries).
        """
        logger.debug(
            "LLM request: model=%s, messages=%d, tools=%s",
            self.model,
            len(messages),
            len(tools) if tools else 0,
        )

        try:
            response = await self._call_with_model(
                model=self.model,
                messages=messages,
                tools=tools,
                temperature=temperature,
                max_tokens=max_tokens,
                response_format=response_format,
                reasoning=reasoning,
                plugins=plugins,
            )
        except openai.APIStatusError as e:
            # Fix 4.2 (H-10): Fallback model on 429/503
            if e.status_code in (429, 503) and self.model != settings.openrouter_fallback_model:
                logger.warning(
                    f"Primary model {self.model} unavailable ({e.status_code}), "
                    f"falling back to {settings.openrouter_fallback_model}"
                )
                try:
                    response = await self._call_with_model(
                        model=settings.openrouter_fallback_model,
                        messages=messages,
                        tools=tools,
                        temperature=temperature,
                        max_tokens=max_tokens,
                        response_format=response_format,
                        reasoning=reasoning,
                        plugins=plugins,
                    )
                except APIError as fallback_exc:
                    sentry_sdk.set_tag("ai.error_type", "llm_failure")
                    sentry_sdk.set_tag("ai.model", settings.openrouter_fallback_model)
                    sentry_sdk.capture_exception(fallback_exc)
                    raise
            else:
                sentry_sdk.set_tag("ai.error_type", "llm_failure")
                sentry_sdk.set_tag("ai.model", self.model)
                sentry_sdk.capture_exception(e)
                raise
        except APIError as e:
            sentry_sdk.set_tag("ai.error_type", "llm_failure")
            sentry_sdk.set_tag("ai.model", self.model)
            sentry_sdk.capture_exception(e)
            raise

        logger.info(
            "LLM response: model=%s, tokens_in=%d, tokens_out=%d",
            self.model,
            # Fix 4.5 (L-4): Safe attribute access on usage
            getattr(response.usage, 'prompt_tokens', 0) if response.usage else 0,
            getattr(response.usage, 'completion_tokens', 0) if response.usage else 0,
        )

        return response

    async def stream_chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> Any:
        """Stream a chat completion response from the LLM.

        Returns an async iterator of chat completion chunks for
        lower-latency token-by-token delivery.

        Args:
            messages: The conversation history in OpenAI message format.
            tools: Optional list of tool definitions for function-calling.
            temperature: Sampling temperature. Defaults to 0.7.
            max_tokens: Maximum tokens in the response. Defaults to 4096.

        Returns:
            An async stream of ChatCompletionChunk objects.
        """
        kwargs: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": True,
            "max_tokens": max_tokens,  # Fix 4.1 (C-7): Always pass max_tokens
        }

        if tools:
            kwargs["tools"] = tools

        try:
            return await self._client.chat.completions.create(**kwargs)
        except openai.APIStatusError as e:
            # Fix 4.2 (H-10): Fallback model on 429/503
            if e.status_code in (429, 503) and self.model != settings.openrouter_fallback_model:
                logger.warning(
                    f"Primary model {self.model} unavailable ({e.status_code}), "
                    f"falling back to {settings.openrouter_fallback_model}"
                )
                try:
                    fallback_kwargs = dict(kwargs)
                    fallback_kwargs["model"] = settings.openrouter_fallback_model
                    return await self._client.chat.completions.create(**fallback_kwargs)
                except APIError as fallback_exc:
                    # Fix 4.4 (M-11): Log stream errors
                    logger.exception("stream_chat_error", extra={"model": settings.openrouter_fallback_model})
                    sentry_sdk.set_tag("ai.error_type", "llm_failure")
                    sentry_sdk.capture_exception(fallback_exc)
                    raise
            else:
                # Fix 4.4 (M-11): Log stream errors
                logger.exception("stream_chat_error", extra={"model": self.model})
                sentry_sdk.set_tag("ai.error_type", "llm_failure")
                sentry_sdk.set_tag("ai.model", self.model)
                sentry_sdk.capture_exception(e)
                raise
        except APIError as e:
            # Fix 4.4 (M-11): Log stream errors
            logger.exception("stream_chat_error", extra={"model": self.model})
            sentry_sdk.set_tag("ai.error_type", "llm_failure")
            sentry_sdk.set_tag("ai.model", self.model)
            sentry_sdk.capture_exception(e)
            raise
