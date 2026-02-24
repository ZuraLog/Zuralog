/**
 * Supabase browser client for client-side components.
 *
 * Uses the @supabase/ssr createBrowserClient to handle cookies correctly
 * in Next.js App Router. Safe to call from Client Components.
 *
 * The anon key is safe to expose to the browser — Row Level Security (RLS)
 * on the database enforces access control.
 *
 * @example
 * ```tsx
 * 'use client';
 * import { createClient } from '@/lib/supabase/client';
 *
 * const supabase = createClient();
 * const { data } = await supabase.from('waitlist').select('*');
 * ```
 */
import { createBrowserClient } from '@supabase/ssr';
import type { Database } from '@/types/database';

/**
 * Creates a Supabase client for use in browser (client) components.
 *
 * @returns A typed Supabase browser client.
 * @throws If environment variables are not set.
 */
export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
