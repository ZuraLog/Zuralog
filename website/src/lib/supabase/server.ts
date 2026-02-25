/**
 * Supabase server client for API routes. Server-side only.
 */
import { createClient as createSupabaseClient } from '@supabase/supabase-js';

export function createServerClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}
