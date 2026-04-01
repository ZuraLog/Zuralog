-- Phase 3: pgvector long-term user memories
-- Replaces Pinecone as the semantic memory backend.

-- Enable pgvector extension (safe to run multiple times)
CREATE EXTENSION IF NOT EXISTS vector;

-- Long-term user memory table.
-- user_id is TEXT to match the users.id column type (VARCHAR/String in SQLAlchemy).
CREATE TABLE IF NOT EXISTS user_memories (
  id                    TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content               TEXT NOT NULL,
  category              TEXT NOT NULL
    CHECK (category IN ('goal', 'injury', 'pr', 'preference', 'context', 'program')),
  embedding             VECTOR(1536),
  source_conversation_id TEXT REFERENCES conversations(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index for fast approximate nearest-neighbour search.
-- m=16 controls the number of bi-directional links per node (higher = better recall, more memory).
-- ef_construction=128 controls build-time search quality (higher = slower build, better index quality).
-- m=16 is appropriate because queries are always filtered by user_id first, keeping the effective
-- search space small. ef_construction=128 (vs the default 64) improves long-term index quality
-- with negligible write cost since memories are written infrequently.
-- If this index ever needs rebuilding on a live table, use CREATE INDEX CONCURRENTLY.
CREATE INDEX IF NOT EXISTS ix_user_memories_embedding
  ON user_memories
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 128);

-- Index for the user_id filter applied on every query.
CREATE INDEX IF NOT EXISTS ix_user_memories_user_id
  ON user_memories (user_id);

-- Auto-update updated_at on every row change.
CREATE OR REPLACE FUNCTION set_updated_at()
  RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_memories_updated_at
  BEFORE UPDATE ON user_memories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Row-level security: users can only access their own memories.
-- Note: the server-side FastAPI service uses the service role key and bypasses RLS.
-- This policy protects direct client access (e.g. Supabase JS client).
-- auth.uid() returns the Firebase UID from the JWT sub claim, cast to text for comparison.
ALTER TABLE user_memories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_memories"
  ON user_memories
  FOR ALL
  USING (user_id = auth.uid()::text);
