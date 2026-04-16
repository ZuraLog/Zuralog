-- Phase 2A: Nutrition feature — Row-Level Security policies
--
-- Covers: meals, meal_foods, food_cache, nutrition_daily_summaries
--
-- The FastAPI backend uses the service role key and bypasses RLS.
-- These policies protect direct client access via the Supabase JS client.
-- auth.uid() returns the Supabase Auth UID; cast to text to match the
-- users.id column type (VARCHAR).

-- Required for the GIN trigram index on food_cache.name
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── meals ────────────────────────────────────────────────────────────
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_meals_select"
  ON meals FOR SELECT
  USING (user_id = auth.uid()::text);

CREATE POLICY "users_own_meals_insert"
  ON meals FOR INSERT
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY "users_own_meals_update"
  ON meals FOR UPDATE
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY "users_own_meals_delete"
  ON meals FOR DELETE
  USING (user_id = auth.uid()::text);

-- ── meal_foods ───────────────────────────────────────────────────────
ALTER TABLE meal_foods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_meal_foods_select"
  ON meal_foods FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_foods.meal_id
        AND meals.user_id = auth.uid()::text
    )
  );

CREATE POLICY "users_own_meal_foods_insert"
  ON meal_foods FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_foods.meal_id
        AND meals.user_id = auth.uid()::text
    )
  );

CREATE POLICY "users_own_meal_foods_update"
  ON meal_foods FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_foods.meal_id
        AND meals.user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_foods.meal_id
        AND meals.user_id = auth.uid()::text
    )
  );

CREATE POLICY "users_own_meal_foods_delete"
  ON meal_foods FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_foods.meal_id
        AND meals.user_id = auth.uid()::text
    )
  );

-- ── food_cache ───────────────────────────────────────────────────────
ALTER TABLE food_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_read_food_cache"
  ON food_cache FOR SELECT
  TO authenticated
  USING (true);

-- ── nutrition_daily_summaries ────────────────────────────────────────
ALTER TABLE nutrition_daily_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_nutrition_summaries_select"
  ON nutrition_daily_summaries FOR SELECT
  USING (user_id = auth.uid()::text);
