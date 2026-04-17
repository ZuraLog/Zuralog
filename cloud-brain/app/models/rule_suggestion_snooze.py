"""Zuralog Cloud Brain — Rule Suggestion Snooze Model.

Tracks per-user dismissals of AI-generated rule suggestions. Each row
carries an ``occurrences_remaining`` counter that is decremented every
time the user logs another meal; when it reaches zero the suggestion is
eligible to surface again.

The unique constraint on (user_id, question_id, answer_value) makes the
dismiss endpoint a clean upsert target.
"""

import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class RuleSuggestionSnooze(Base):
    __tablename__ = "rule_suggestion_snooze"
    __table_args__ = (
        sa.UniqueConstraint(
            "user_id",
            "question_id",
            "answer_value",
            name="uq_rule_suggestion_snooze_user_question_answer",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[str] = mapped_column(
        sa.String,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    question_id: Mapped[str] = mapped_column(sa.String(20), nullable=False)
    answer_value: Mapped[str] = mapped_column(sa.String(50), nullable=False)
    occurrences_remaining: Mapped[int] = mapped_column(
        sa.Integer, nullable=False, server_default=sa.text("10")
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
