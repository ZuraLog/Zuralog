/**
 * Supabase Database type definitions for the Zuralog website.
 *
 * This is a placeholder schema until the actual waitlist tables are
 * created in Phase 3.2.1. At that point, regenerate these types using:
 *   npx supabase gen types typescript --project-id enccjffwpnwkxfkhargr > src/types/database.ts
 *
 * Current tables (Phase 3.2.1 will add waitlist-specific ones):
 * - waitlist_entries: Email, referral code, referral count, position
 * - quiz_responses: User quiz answers for personalization
 */

/** Placeholder Database type — will be replaced with generated types in Phase 3.2.1 */
export type Database = {
  public: {
    Tables: {
      waitlist_entries: {
        Row: {
          id: string;
          email: string;
          referral_code: string;
          referred_by: string | null;
          referral_count: number;
          position: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          email: string;
          referral_code: string;
          referred_by?: string | null;
          referral_count?: number;
          position?: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          email?: string;
          referral_code?: string;
          referred_by?: string | null;
          referral_count?: number;
          position?: number;
          created_at?: string;
        };
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
  };
};
