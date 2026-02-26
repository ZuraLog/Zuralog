/**
 * Supabase Database type definitions for the Zuralog website.
 *
 * These types match the actual waitlist_users table schema.
 * Last updated: 2026-02-24
 *
 * To regenerate via Supabase CLI:
 *   npx supabase gen types typescript --project-id enccjffwpnwkxfkhargr > src/types/database.ts
 */

export type Database = {
  public: {
    Tables: {
      waitlist_users: {
        Row: {
          id: string;
          email: string;
          referral_code: string;
          referred_by: string | null;
          display_name: string | null;
          show_name: boolean | null;
          queue_position: number | null;
          quiz_apps_used: string[] | null;
          quiz_frustration: string | null;
          quiz_goal: string | null;
          tier: string | null;
          created_at: string | null;
          updated_at: string | null;
          ip_address: string | null;
          user_agent: string | null;
        };
        Insert: {
          id?: string;
          email: string;
          referral_code: string;
          referred_by?: string | null;
          display_name?: string | null;
          show_name?: boolean | null;
          queue_position?: number | null;
          quiz_apps_used?: string[] | null;
          quiz_frustration?: string | null;
          quiz_goal?: string | null;
          tier?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
          ip_address?: string | null;
          user_agent?: string | null;
        };
        Update: {
          id?: string;
          email?: string;
          referral_code?: string;
          referred_by?: string | null;
          display_name?: string | null;
          show_name?: boolean | null;
          queue_position?: number | null;
          quiz_apps_used?: string[] | null;
          quiz_frustration?: string | null;
          quiz_goal?: string | null;
          tier?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
          ip_address?: string | null;
          user_agent?: string | null;
        };
      };
      support_contributions: {
        Row: {
          id: string;
          source: string;
          source_id: string | null;
          supporter_name: string;
          is_anonymous: boolean;
          amount: number;
          currency: string;
          message: string | null;
          contributed_at: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          source?: string;
          source_id?: string | null;
          supporter_name?: string;
          is_anonymous?: boolean;
          amount: number;
          currency?: string;
          message?: string | null;
          contributed_at?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          source?: string;
          source_id?: string | null;
          supporter_name?: string;
          is_anonymous?: boolean;
          amount?: number;
          currency?: string;
          message?: string | null;
          contributed_at?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
    };
    Views: {
      waitlist_stats: {
        Row: {
          total_signups: number | null;
          founding_members: number | null;
          total_referrals: number | null;
          signups_last_24h: number | null;
          latest_position: number | null;
        };
      };
      referral_leaderboard: {
        Row: {
          id: string | null;
          referral_code: string | null;
          display_name: string | null;
          show_name: boolean | null;
          referral_count: number | null;
          queue_position: number | null;
          created_at: string | null;
        };
      };
      support_stats: {
        Row: {
          total_supporters: number | null;
          total_funds_raised: number | null;
          highest_single_contribution: number | null;
        };
      };
      support_leaderboard: {
        Row: {
          supporter_name: string | null;
          total_contributed: number | null;
          contribution_count: number | null;
          latest_contribution: string | null;
        };
      };
    };
    Functions: {
      increment_referral_count: {
        Args: { user_id: string };
        Returns: void;
      };
    };
    Enums: Record<string, never>;
  };
};
