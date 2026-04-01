-- Phase 2: Context Management — conversation summaries and message token tracking
--
-- conversations: add rolling summary columns
ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS summary             TEXT,
  ADD COLUMN IF NOT EXISTS summary_updated_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS summary_token_count INTEGER DEFAULT 0 CHECK (summary_token_count >= 0);

-- messages: add per-message token count and summarization flag
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS token_count   INTEGER CHECK (token_count > 0),
  ADD COLUMN IF NOT EXISTS is_summarized BOOLEAN NOT NULL DEFAULT FALSE;

-- Partial index: only indexes non-summarized rows, which is the only query
-- pattern that filters on is_summarized. Much smaller than a full index at scale.
-- NOTE: must be applied OUTSIDE a transaction block (CONCURRENTLY).
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_messages_not_summarized
  ON messages (conversation_id, created_at DESC)
  WHERE is_summarized = FALSE;
