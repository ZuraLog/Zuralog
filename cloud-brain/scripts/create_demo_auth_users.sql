-- create_demo_auth_users.sql
-- Run this in the Supabase SQL editor if the demo auth.users rows are ever lost.
-- The seed_demo_data.py script seeds the public schema only — it does NOT
-- touch auth.users. This file recreates those rows.
--
-- Password for both accounts: ZuraDemo2026!
-- IDs are fixed and must never change (all seed data references them).

INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, role, aud, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
(
  'a0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'demo-full@zuralog.dev',
  crypt('ZuraDemo2026!', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Demo Full"}',
  'authenticated', 'authenticated', NOW(), NOW(),
  '', '', '', ''
),
(
  'a0000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'demo-empty@zuralog.dev',
  crypt('ZuraDemo2026!', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Demo Empty"}',
  'authenticated', 'authenticated', NOW(), NOW(),
  '', '', '', ''
)
ON CONFLICT (id) DO NOTHING;
