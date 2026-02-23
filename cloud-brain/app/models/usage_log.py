"""
Zuralog Cloud Brain — Usage Log Model.

Tracks per-request LLM token consumption for cost analysis.
"""

import uuid

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class UsageLog(Base):
    """A single LLM usage record.

    Attributes:
        id: Unique record identifier.
        user_id: The user who made the request.
        model: The LLM model used.
        input_tokens: Prompt tokens consumed.
        output_tokens: Completion tokens generated.
        created_at: Timestamp of the API call.
    """

    __tablename__ = "usage_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, index=True)
    model: Mapped[str] = mapped_column(String)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
