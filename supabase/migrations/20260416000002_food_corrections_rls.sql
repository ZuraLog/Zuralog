-- Phase 2D: Correction learning — RLS for food_corrections
ALTER TABLE food_corrections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_own_corrections"
  ON food_corrections FOR INSERT
  WITH CHECK (user_id = auth.uid()::text);
