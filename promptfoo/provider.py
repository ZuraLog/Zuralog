"""
PromptFoo custom provider for the Zura AI coach system prompt.

Calls the OpenRouter API directly (OpenAI-compatible) with the assembled
system prompt so tests exercise the real prompt without going through the
WebSocket layer.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Path setup — add cloud-brain root so we can import app modules
# ---------------------------------------------------------------------------

_CLOUD_BRAIN = Path(__file__).resolve().parent.parent / "cloud-brain"
if str(_CLOUD_BRAIN) not in sys.path:
    sys.path.insert(0, str(_CLOUD_BRAIN))

from app.agent.prompts.system import build_system_prompt  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_API_BASE = "https://openrouter.ai/api/v1"
_MODEL = "moonshotai/kimi-k2.5"
_DEFAULT_PERSONA = "balanced"
_DEFAULT_PROACTIVITY = "medium"


# ---------------------------------------------------------------------------
# Provider entry point
# ---------------------------------------------------------------------------


def call_api(prompt: str, options: dict, context: dict) -> dict:
    """PromptFoo custom provider.

    Args:
        prompt: The user message string injected by PromptFoo.
        options: Provider config dict; may contain a ``config`` key with
            provider-specific settings (e.g. ``model`` to override the default).
        context: Test variables dict; may include ``persona`` and
            ``proactivity`` keys to override the defaults.

    Returns:
        ``{"output": str}`` on success, ``{"error": str}`` on failure.
    """
    api_key = os.environ.get("OPENROUTER_API_KEY", "")
    if not api_key:
        return {"error": "OPENROUTER_API_KEY environment variable is not set."}

    model = options.get("config", {}).get("model", _MODEL)

    vars_ = context.get("vars", {})
    persona = vars_.get("persona", _DEFAULT_PERSONA)
    proactivity = vars_.get("proactivity", _DEFAULT_PROACTIVITY)
    system_prompt = build_system_prompt(persona=persona, proactivity=proactivity)

    try:
        import httpx

        with httpx.Client(timeout=60.0) as client:
            response = client.post(
                f"{_API_BASE}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://zuralog.com",
                    "X-Title": "Zuralog PromptFoo Tests",
                },
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.0,
                    "max_tokens": 512,
                },
            )
            response.raise_for_status()
            data = response.json()
            output = data["choices"][0]["message"]["content"]
            return {"output": output}

    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc)}
