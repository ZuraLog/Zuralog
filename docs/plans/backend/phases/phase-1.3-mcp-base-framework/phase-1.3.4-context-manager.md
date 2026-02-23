# Phase 1.3.4: Context Manager (Pinecone Integration)

**Parent Goal:** Phase 1.3 MCP Base Framework
**Checklist:**
- [x] 1.3.1 MCP Server Base Class
- [x] 1.3.2 MCP Client (Orchestrator)
- [x] 1.3.3 Tool Schema Definitions
- [ ] 1.3.4 Context Manager (Pinecone Integration)
- [ ] 1.3.5 MCP Server Registry
- [ ] 1.3.6 MCP Integration Tests

---

## What
Implement the system for managing Long-Term Memory (LTM). This involves integrating Pinecone (vector database) to store and retrieve semantic context (e.g., "User prefers low-impact cardio") and User Profile configuration (e.g. "Coach Persona").

## Why
Standard LLM context windows are limit (and expensive). To give the AI a "Brain" that remembers the user's history and preferences over months, we need a Retrieval Augmented Generation (RAG) system. Pinecone efficiently retrieves only the relevant memories for the current conversation.

## How
We will use:
- **Pinecone SDK:** To store and query vector embeddings.
- **OpenAI Embeddings (Placeholder):** For the MVP, we might stub the embedding generation or use a simple locally mock, but the structure will support real embeddings.
- **Supabase/Postgres:** For structured profile data (Persona settings).

## Features
- **Semantic Recall:** AI remembers "I hurt my knee last week" when you ask for a run plan today.
- **Personalization:** Response style adjusts based on `coach_persona`.

## Files
- Create: `cloud-brain/app/agent/context_manager/memory_manager.py`
- Create: `cloud-brain/app/agent/context_manager/user_profile.py`

## Steps

1. **Create Pinecone client wrapper**

```python
from pinecone import Pinecone
from cloudbrain.app.config import settings

class MemoryManager:
    """Manages long-term user context via Pinecone."""
    
    def __init__(self):
        # Initialize only if key is present to allow offline dev without crashing
        if settings.pinecone_api_key:
            self._client = Pinecone(api_key=settings.pinecone_api_key)
            self._index = self._client.Index("zuralog-context")
        else:
            self._client = None
    
    async def add_context(self, user_id: str, text: str, metadata: dict):
        """Add a memory to the vector store."""
        if not self._client: return
        
        # In production, embed text with OpenAI
        # For MVP, we use simple metadata storage or placeholder vectors
        self._index.upsert(
            vectors=[{
                "id": f"{user_id}_{metadata.get('timestamp')}",
                "values": [0.0] * 1536,  # Placeholder - use embeddings in production
                "metadata": {"user_id": user_id, "text": text, **metadata}
            }]
        )
    
    async def get_context(self, user_id: str, query: str = "", limit: int = 5) -> list[dict]:
        """Retrieve relevant context for a user."""
        if not self._client: return []
        
        try:
            results = self._index.query(
                vector=[0.0] * 1536,
                filter={"user_id": {"$eq": user_id}},
                top_k=limit,
                include_metadata=True
            )
            return [match['metadata'] for match in results['matches']]
        except Exception:
            return []
```

2. **Create user profile manager**

```python
class UserProfile:
    """Manages user profile data."""
    
    def __init__(self, db):
        self.db = db
    
    async def get_profile(self, user_id: str) -> dict:
        """Get user profile with preferences."""
        # Query from Supabase/DB
        # For MVP returning stubbed structure matching DB schema
        return {
            "coach_persona": "tough_love",
            "goals": {"weight_loss": True, "weekly_runs": 3},
            "connected_apps": []
        }
```

## Exit Criteria
- Context manager compiles.
- Can connect to Pinecone instance using config (or handle missing config gracefully).
