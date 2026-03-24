"""User data export endpoint."""
import json
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_authenticated_user_id, get_db
from app.limiter import limiter
from app.models.conversation import Conversation
from app.models.user_preferences import UserPreferences

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
        .options(selectinload(Conversation.messages))
        .order_by(Conversation.created_at.desc())
    )
    conversations = result.scalars().all()

    # Preferences
    pref_result = await db.execute(
        select(UserPreferences).where(UserPreferences.user_id == user_id)
    )
    preferences = pref_result.scalar_one_or_none()

    # Memories (if available)
    memories = []
    memory_store = getattr(request.app.state, "memory_store", None)
    if memory_store is not None:
        try:
            raw = await memory_store.list_memories(user_id=user_id, limit=1000)
            memories = [
                {"id": str(m.get("id", "")), "text": m.get("text", ""), "metadata": m.get("metadata", {})}
                for m in (raw or [])
            ]
        except Exception:
            pass

    export_data = {
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "user_id": user_id,
        "conversations": [
            {
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
                    for m in sorted(c.messages, key=lambda x: x.created_at or datetime.min)
                ],
            }
            for c in conversations
        ],
        "preferences": {
            "coach_persona": preferences.coach_persona if preferences else None,
            "proactivity_level": preferences.proactivity_level if preferences else None,
            "response_length": preferences.response_length if preferences else None,
        },
        "memories": memories,
    }

    filename = f"zuralog-export-{datetime.now(timezone.utc).strftime('%Y-%m-%d')}.json"
    return Response(
        content=json.dumps(export_data, indent=2, default=str),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
