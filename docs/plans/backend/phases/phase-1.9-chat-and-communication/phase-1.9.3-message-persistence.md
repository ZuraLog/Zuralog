# Phase 1.9.3: Message Persistence

**Parent Goal:** Phase 1.9 Chat & Communication Layer
**Checklist:**
- [x] 1.9.1 WebSocket Endpoint
- [x] 1.9.2 Edge Agent WebSocket Client
- [x] 1.9.3 Message Persistence
- [ ] 1.9.4 Edge Agent Chat Repository
- [ ] 1.9.5 Chat UI in Harness
- [ ] 1.9.6 Push Notifications (FCM)
- [ ] 1.9.7 Edge Agent FCM Setup

---

## What
Define the database schema to store chat history and implement the logic to save messages during the WebSocket loop.

## Why
Users expect to see their past conversations when they reopen the app. The AI also needs this history for context.

## How
Use SQLAlchemy models `Conversation` and `Message`.

## Features
- **Indexing:** `user_id` and `created_at` for fast retrieval.
- **JSON Content:** Future-proof for rich messages (e.g., UI widgets in chat).

## Files
- Create: `cloud-brain/app/models/conversation.py`
- Modify: `cloud-brain/app/api/v1/chat.py` (to use persistence)

## Steps

1. **Create conversation models (`cloud-brain/app/models/conversation.py`)**

```python
from sqlalchemy import Column, String, DateTime, Text, ForeignKey, func, Integer
from sqlalchemy.orm import relationship
from cloudbrain.app.db.base import Base
import uuid

class Conversation(Base):
    __tablename__ = "conversations"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True) # ForeignKey("users.id")
    title = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    messages = relationship("Message", back_populates="conversation", order_by="Message.created_at")

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    conversation_id = Column(String, ForeignKey("conversations.id"), index=True)
    role = Column(String)  # 'user', 'assistant', 'system', 'tool'
    content = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    conversation = relationship("Conversation", back_populates="messages")
```

2. **Run Migrations (Concept)**
   - `alembic revision --autogenerate -m "Add chat models"`
   - `alembic upgrade head`

## Exit Criteria
- Models created.
- Migration script generated (conceptually).
