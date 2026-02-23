"""
Zuralog Cloud Brain — Conversation and Message Models.

Stores chat history between users and the AI assistant. Each user
can have multiple conversations, and each conversation contains
an ordered sequence of messages with roles (user, assistant, system).
"""

import uuid

from sqlalchemy import DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class Conversation(Base):
    """A chat conversation between a user and the AI assistant.

    Attributes:
        id: Unique identifier (UUID).
        user_id: Foreign key to the users table.
        title: Optional conversation title (auto-generated or user-set).
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
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
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
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    conversation: Mapped["Conversation"] = relationship(
        "Conversation",
        back_populates="messages",
    )
