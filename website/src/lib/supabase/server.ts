/**
 * Supabase server client for API routes and Server Components.
 *
 * Uses the service role key which bypasses Row Level Security.
 * NEVER expose the service role key to the browser — it is server-only.
 *
 * Used for:
 * - Waitlist signup mutations (POST /api/waitlist)
 * - Admin queries that need full table access
 * - Email sending confirmations
 *
 * @example
 * ```ts
 * // In an API route handler:
 * import { createServerClient } from '@/lib/supabase/server';
 *
 * export async function POST(request: Request) {
 *   const supabase = createServerClient();
 *   const { error } = await supabase.from('waitlist_users').insert({ email: '...' });
 * }
 * ```
 */
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/types/database';

/**
 * Creates a Supabase admin client with the service role key.
 * For server-side use only — API routes and Server Actions.
 *
 * @returns A typed Supabase admin client.
 * @throws If environment variables are not set.
 */
export function createServerClient() {
  return createSupabaseClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}
