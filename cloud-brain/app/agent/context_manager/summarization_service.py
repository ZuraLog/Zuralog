"""
Zuralog Cloud Brain — Summarization Service.

Background service that summarizes the oldest messages in a conversation
when it grows beyond the rolling window threshold. The summary is stored
in conversations.summary and the summarized messages are flagged so they
are excluded from future history loads.

Designed to be called as a fire-and-forget asyncio task — never in the
critical path of a WebSocket response.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.agent.context_manager.token_counter import count_tokens
from app.agent.llm_client import LLMClient
from app.database import async_session
from app.models.conversation import Conversation, Message

logger = logging.getLogger(__name__)

# Minimum number of eligible (non-recent, non-summarized) messages
# required before triggering a summarization call. Below this threshold
# the LLM call is not worth the cost.
_MIN_ELIGIBLE_MESSAGES = 15

_SUMMARIZATION_SYSTEM_PROMPT = (
    "You are summarizing a fitness coaching conversation. "
    "Write a concise third-person summary (under 200 words) capturing: "
    "the user's stated goals, any fitness data mentioned (PRs, metrics, trends), "
    "key advice given by the coach, and important user context "
    "(injuries, preferences, history, program). "
    "Preserve facts. Discard pleasantries and generic back-and-forth."
)


async def summarize_oldest_messages(
    conversation_id: str,
    llm_client: LLMClient,
) -> None:
    """Summarize the oldest unsummarized messages in a conversation.

    Creates its own database session (safe for fire-and-forget tasks
    where the parent session may have already closed). All writes are
    committed in a single transaction.

    Args:
        conversation_id: The conversation to summarize.
        llm_client: The LLM client to use for summary generation.
    """
    async with async_session() as db:
        try:
            # Step 1: Find the IDs of the most recent 15 non-summarized messages.
            # These stay in the rolling window — we summarize everything older.
            recent_result = await db.execute(
                select(Message.id)
                .where(
                    Message.conversation_id == conversation_id,
                    Message.role.in_(["user", "assistant"]),
                    Message.is_summarized == False,  # noqa: E712
                )
                .order_by(Message.created_at.desc())
                .limit(15)
            )
            recent_ids = set(recent_result.scalars().all())

            # Step 2: Load all non-summarized messages NOT in the recent set.
            eligible_result = await db.execute(
                select(Message)
                .where(
                    Message.conversation_id == conversation_id,
                    Message.role.in_(["user", "assistant"]),
                    Message.is_summarized == False,  # noqa: E712
                    Message.id.not_in(recent_ids) if recent_ids else True,
                )
                .order_by(Message.created_at.asc())
            )
            to_summarize = eligible_result.scalars().all()

            if len(to_summarize) < _MIN_ELIGIBLE_MESSAGES:
                logger.debug(
                    "Summarization skipped for conv %s: only %d eligible messages (min %d)",
                    conversation_id,
                    len(to_summarize),
                    _MIN_ELIGIBLE_MESSAGES,
                )
                return

            # Step 3: Call the LLM to generate a summary.
            history = [
                {"role": m.role, "content": m.content or ""}
                for m in to_summarize
            ]
            response = await llm_client.chat(
                messages=[
                    {"role": "system", "content": _SUMMARIZATION_SYSTEM_PROMPT},
                    *history,
                    {"role": "user", "content": "Summarize this conversation."},
                ],
                temperature=0.3,
            )

            summary = (response.choices[0].message.content or "").strip()
            if not summary:
                logger.warning("LLM returned empty summary for conv %s — skipping", conversation_id)
                return

            token_count = count_tokens(summary)

            # Step 4: Persist summary + mark messages in a single transaction.
            conv_result = await db.execute(
                select(Conversation).where(Conversation.id == conversation_id)
            )
            conv = conv_result.scalar_one_or_none()
            if conv:
                conv.summary = summary
                conv.summary_updated_at = datetime.now(timezone.utc)
                conv.summary_token_count = token_count

            for msg in to_summarize:
                msg.is_summarized = True

            await db.commit()
            logger.info(
                "Summarized %d messages for conv %s (%d tokens)",
                len(to_summarize),
                conversation_id,
                token_count,
            )

        except Exception:
            logger.exception("Summarization failed for conversation %s", conversation_id)
