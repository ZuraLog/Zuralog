-- Add memory_enabled preference to user_preferences table.
-- Default TRUE preserves existing behaviour for all current users.
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS memory_enabled BOOLEAN NOT NULL DEFAULT TRUE;
