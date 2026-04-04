"""
Zuralog Cloud Brain — Memory Extraction Service.

Extracts lasting facts about a user from a completed conversation and
stores them in the memory store. Deduplicates against existing memories
using cosine similarity (threshold 0.92).

Designed to be called as a fire-and-forget asyncio task after each
assistant response — never in the critical response path.
"""

from __future__ import annotations

import json
import logging

from sqlalchemy import select

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.database import async_session
from app.models.conversation import Message
from app.utils.sanitize import is_memory_injection_attempt

logger = logging.getLogger(__name__)

# Facts with a similarity score above this threshold against an existing
# memory are treated as updates (delete + re-insert) rather than new entries.
_DEDUP_THRESHOLD = 0.92

_EXTRACTION_SYSTEM_PROMPT = (
    "Analyze this fitness coaching conversation. "
    "Extract facts about the user that should be remembered for future sessions. "
    "Return ONLY a JSON array of objects: "
    '[{"content": "fact as a complete sentence", "category": "one of: goal|injury|pr|preference|context|program"}]. '
    "Rules: only extract facts with lasting value; ignore greetings, thanks, and one-time questions; "
    "maximum 5 facts; respond with raw JSON only, no markdown fences."
)


async def extract_and_store_memories(
    conversation_id: str,
    user_id: str,
    llm_client: LLMClient,
    memory_store: MemoryStore,
) -> None:
    """Extract memorable facts from a conversation and store them.

    Creates its own database session. Safe for fire-and-forget use.
    Logs and swallows all exceptions — failure here must never affect
    the user-facing response.

    Args:
        conversation_id: The conversation to extract facts from.
        user_id: The user who owns the conversation.
        llm_client: The LLM client for fact extraction.
        memory_store: The memory store to write facts into.
    """
    try:
        async with async_session() as db:
            result = await db.execute(
                select(Message)
                .where(
                    Message.conversation_id == conversation_id,
                    Message.role.in_(["user", "assistant"]),
                )
                .order_by(Message.created_at.desc())
                .limit(20)
            )
            messages = list(reversed(result.scalars().all()))

        if not messages:
            return

        history = [{"role": m.role, "content": m.content or ""} for m in messages]

        # Call the LLM to extract facts.
        response = await llm_client.chat(
            messages=[
                {"role": "system", "content": _EXTRACTION_SYSTEM_PROMPT},
                *history,
                {"role": "user", "content": "Extract memorable facts as a JSON array."},
            ],
            temperature=0.2,
        )

        raw = (response.choices[0].message.content or "").strip()

        # Strip markdown code fences if the model added them.
        if raw.startswith("```"):
            parts = raw.split("```")
            raw = parts[1] if len(parts) > 1 else ""
            if raw.startswith("json"):
                raw = raw[4:].strip()

        facts: list[dict] = json.loads(raw)

    except Exception:
        logger.warning(
            "Memory extraction failed for conversation %s — skipping",
            conversation_id,
            exc_info=True,
        )
        return

    for fact in facts[:5]:
        content = str(fact.get("content", "")).strip()
        category = str(fact.get("category", "context")).strip()
        if not content:
            continue

        # Guard against adversarial memories extracted from crafted conversations.
        if is_memory_injection_attempt(content):
            logger.warning(
                "Blocking extracted memory with injection/bypass content for user %s: %.60s",
                user_id[:8],
                content[:60],
            )
            continue

        try:
            # Deduplication: check for a semantically similar existing memory.
            existing = await memory_store.query(user_id, content, limit=1)
            if existing and existing[0].score > _DEDUP_THRESHOLD:
                # Delete the near-duplicate and replace with the updated fact.
                await memory_store.delete(existing[0].id)
                logger.debug(
                    "Updating near-duplicate memory (score %.2f) for user %s",
                    existing[0].score,
                    user_id[:8],
                )

            await memory_store.add(
                user_id=user_id,
                content=content,
                category=category,
                source_conversation_id=conversation_id,
            )
        except Exception:
            logger.warning(
                "Failed to store memory fact for user %s: %s",
                user_id[:8],
                content[:50],
                exc_info=True,
            )
