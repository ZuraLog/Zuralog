"""
Zuralog Cloud Brain — Conversation and Message Models.

Stores chat history between users and the AI assistant. Each user
can have multiple conversations, and each conversation contains
an ordered sequence of messages with roles (user, assistant, system).
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class Conversation(Base):
    """A chat conversation between a user and the AI assistant.

    Attributes:
        id: Unique identifier (UUID).
        user_id: Foreign key to the users table.
        title: Optional conversation title (auto-generated or user-set).
        archived: Whether the conversation is archived (hidden from default list).
        deleted_at: Soft-delete timestamp. Non-null means the conversation is deleted.
        created_at: Timestamp of conversation creation.
        updated_at: Timestamp of last message addition.
        messages: Ordered list of messages in this conversation.
    """

    __tablename__ = "conversations"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    title: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
    )
    archived: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
        comment="True when the user has archived this conversation",
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Soft-delete timestamp; non-null means deleted",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
    summary: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Rolling LLM-generated summary of older messages",
    )
    summary_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="When the summary was last generated",
    )
    summary_token_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
        nullable=False,
        comment="Token count of the current summary (for budget tracking)",
    )

    messages: Mapped[list["Message"]] = relationship(
        "Message",
        back_populates="conversation",
        order_by="Message.created_at",
        cascade="all, delete-orphan",
    )


class Message(Base):
    """A single message within a conversation.

    Attributes:
        id: Unique identifier (UUID).
        conversation_id: Foreign key to the conversations table.
        role: Message author role — 'user', 'assistant', 'system', or 'tool'.
        content: The message text content.
        created_at: Timestamp of message creation.
        conversation: Back-reference to the parent conversation.
    """

    __tablename__ = "messages"
    __table_args__ = (Index("ix_messages_conv_created", "conversation_id", "created_at"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    conversation_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("conversations.id", ondelete="CASCADE"),
        index=True,
    )
    role: Mapped[str] = mapped_column(String)
    content: Mapped[str] = mapped_column(Text)
    attachments: Mapped[list[dict] | None] = mapped_column(JSONB, nullable=True)
    token_count: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Token count of this message's content (cl100k_base)",
    )
    is_summarized: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
        comment="True once this message has been included in a rolling summary",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    conversation: Mapped["Conversation"] = relationship(
        "Conversation",
        back_populates="messages",
    )
