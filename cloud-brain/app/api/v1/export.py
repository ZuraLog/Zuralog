"""User data export endpoint."""
import json
import logging
from collections import defaultdict
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_authenticated_user_id, get_db
from app.limiter import limiter
from app.models.conversation import Conversation, Message
from app.models.user_preferences import UserPreferences

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/export")
@limiter.limit("1/hour")
async def export_user_data(
    request: Request,
    user_id: Annotated[str, Depends(get_authenticated_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Export all user data as a downloadable JSON file."""
    # Conversations + messages
    result = await db.execute(
        select(Conversation)
        .where(Conversation.user_id == user_id, Conversation.deleted_at.is_(None))
        .order_by(Conversation.created_at.desc())
        .limit(200)
    )
    conversations = result.scalars().all()

    # Preferences
    pref_result = await db.execute(
        select(UserPreferences).where(UserPreferences.user_id == user_id)
    )
    preferences = pref_result.scalar_one_or_none()

    # Memories (if available)
    memories = []
    memories_export_partial = False
    memory_store = getattr(request.app.state, "memory_store", None)
    if memory_store is not None:
        try:
            raw = await memory_store.list_memories(user_id=user_id, limit=1000)
            memories = [
                {"id": str(m.get("id", "")), "text": m.get("text", ""), "metadata": m.get("metadata", {})}
                for m in (raw or [])
            ]
        except Exception:
            logger.exception("Failed to export memories for user '%s'", user_id[:8])
            memories_export_partial = True

    conv_ids = [c.id for c in conversations]

    if not conv_ids:
        messages_by_conv: dict = {}
    else:
        row_num_col = func.row_number().over(
            partition_by=Message.conversation_id,
            order_by=Message.created_at.desc()
        ).label("rn")

        subq = (
            select(Message.id, row_num_col)
            .where(Message.conversation_id.in_(conv_ids))
            .subquery()
        )

        msg_result = await db.execute(
            select(Message)
            .join(subq, Message.id == subq.c.id)
            .where(subq.c.rn <= 200)
            .order_by(Message.created_at.asc())
        )
        messages = msg_result.scalars().all()

        messages_by_conv = defaultdict(list)
        for m in messages:
            messages_by_conv[str(m.conversation_id)].append(m)

    conversations_data = []
    for c in conversations:
        msgs = messages_by_conv.get(str(c.id), [])
        conversations_data.append({
            "id": str(c.id),
            "title": c.title,
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            "messages": [
                {
                    "role": m.role,
                    "content": m.content,
                    "created_at": m.created_at.isoformat() if m.created_at else None,
                }
                for m in msgs
            ],
        })

    export_data = {
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "conversations": conversations_data,
        "preferences": {
            "coach_persona": preferences.coach_persona if preferences else None,
            "proactivity_level": preferences.proactivity_level if preferences else None,
            "response_length": preferences.response_length if preferences else None,
        },
        "memories": memories,
        "memories_export_partial": memories_export_partial,
    }

    filename = f"zuralog-export-{datetime.now(timezone.utc).strftime('%Y-%m-%d')}.json"
    return Response(
        content=json.dumps(export_data, indent=2, default=str),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
