"""
seed_demo_data.py — Zuralog demo account seeder
================================================
Creates and seeds two test accounts in Supabase directly via psycopg2:

  demo-full@zuralog.dev   — 30 days of realistic health data, 3 integrations,
                            goals, streaks, insights, chat history, reports.
                            Simulates an active power user.

  demo-empty@zuralog.dev  — Bare account, onboarding_complete=false.
                            Simulates a brand-new signup with zero data.

IDEMPOTENT: safe to run multiple times. All inserts use ON CONFLICT DO NOTHING
or DO UPDATE. Running again after adding new seed rows will insert only the new
data, leaving existing rows untouched.

RESET MODE: pass --reset to wipe all demo-account data and re-seed from scratch.

Usage
-----
  # From cloud-brain/ directory:
  uv run python scripts/seed_demo_data.py
  uv run python scripts/seed_demo_data.py --reset

Requirements
------------
  DATABASE_URL must be set in cloud-brain/.env (points to local Docker Postgres
  or the Supabase direct connection string).

  The Supabase auth.users rows must already exist. This script seeds only the
  public schema tables (it does NOT create auth users — those were created once
  manually in the Supabase dashboard). If you need to recreate the auth rows,
  run the SQL in cloud-brain/scripts/create_demo_auth_users.sql in the
  Supabase SQL editor.

Demo account credentials
------------------------
  Email:    demo-full@zuralog.dev    Password: ZuraDemo2026!
  Email:    demo-empty@zuralog.dev   Password: ZuraDemo2026!

  User IDs (fixed UUIDs, never change):
    FULL_USER_ID  = a0000000-0000-0000-0000-000000000001
    EMPTY_USER_ID = a0000000-0000-0000-0000-000000000002
"""

import argparse
import math
import os
import sys
from datetime import date, datetime, timedelta, timezone

import psycopg2
from psycopg2.extras import execute_values

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

FULL_ID = "a0000000-0000-0000-0000-000000000001"
EMPTY_ID = "a0000000-0000-0000-0000-000000000002"
FULL_EMAIL = "demo-full@zuralog.dev"
EMPTY_EMAIL = "demo-empty@zuralog.dev"

TODAY = date.today()
NOW = datetime.now(timezone.utc)


def days_ago(n: int) -> date:
    return TODAY - timedelta(days=n)


def ts_ago(**kwargs) -> datetime:
    return NOW - timedelta(**kwargs)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def get_connection() -> psycopg2.extensions.connection:
    # Try DATABASE_URL from env, then from cloud-brain/.env
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
        if os.path.exists(env_path):
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("DATABASE_URL="):
                        db_url = line.split("=", 1)[1].strip().strip('"').strip("'")
                        break
    if not db_url:
        sys.exit("ERROR: DATABASE_URL not set. Add it to cloud-brain/.env or export it.")
    return psycopg2.connect(db_url)


def reset_demo_data(cur):
    """Wipe all rows belonging to both demo accounts."""
    print("  Resetting demo data...")
    tables_with_user_id = [
        "quick_logs",
        "journal_entries",
        "achievements",
        "user_streaks",
        "user_preferences",
        "emergency_health_cards",
        "insights",
        "notification_logs",
        "reports",
        "user_goals",
        "integrations",
        "nutrition_entries",
        "sleep_records",
        "weight_measurements",
        "blood_pressure_records",
        "daily_health_metrics",
        "unified_activities",
    ]
    for tbl in tables_with_user_id:
        cur.execute(f"DELETE FROM {tbl} WHERE user_id IN (%s, %s)", (FULL_ID, EMPTY_ID))

    # messages → conversations (cascade not guaranteed)
    cur.execute(
        "DELETE FROM messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id IN (%s, %s))",
        (FULL_ID, EMPTY_ID),
    )
    cur.execute("DELETE FROM conversations WHERE user_id IN (%s, %s)", (FULL_ID, EMPTY_ID))
    cur.execute("DELETE FROM users WHERE id IN (%s, %s)", (FULL_ID, EMPTY_ID))
    print("  Reset complete.")


# ---------------------------------------------------------------------------
# Seed functions
# ---------------------------------------------------------------------------


def seed_users(cur):
    cur.execute(
        """
        INSERT INTO users (id, email, display_name, nickname, birthday, gender,
                           onboarding_complete, coach_persona, subscription_tier,
                           created_at, updated_at)
        VALUES
          (%s, %s, 'Alex Johnson', 'Alex', '1991-08-14', 'male',
           true, 'balanced', 'pro', NOW(), NOW()),
          (%s, %s, 'New User', NULL, NULL, NULL,
           false, 'balanced', 'free', NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET
          display_name = EXCLUDED.display_name,
          onboarding_complete = EXCLUDED.onboarding_complete,
          subscription_tier = EXCLUDED.subscription_tier,
          updated_at = NOW()
    """,
        (FULL_ID, FULL_EMAIL, EMPTY_ID, EMPTY_EMAIL),
    )
    print("  users: 2 rows")


def seed_preferences(cur):
    cur.execute(
        """
        INSERT INTO user_preferences
          (id, user_id, coach_persona, proactivity_level, theme, haptic_enabled,
           tooltips_enabled, onboarding_complete, morning_briefing_enabled,
           morning_briefing_time, units_system, created_at, updated_at)
        VALUES (%s, %s, 'balanced', 'medium', 'dark', true, false, true,
                true, '07:30', 'metric', NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET updated_at = NOW()
    """,
        ("pref-demo-full-001", FULL_ID),
    )
    print("  user_preferences: 1 row")


def seed_integrations(cur):
    rows = [
        (
            "int-demo-strava",
            FULL_ID,
            "strava",
            True,
            ts_ago(hours=2),
            "idle",
            '{"athlete_id": 12345678, "athlete_name": "Alex Johnson"}',
        ),
        (
            "int-demo-fitbit",
            FULL_ID,
            "fitbit",
            True,
            ts_ago(minutes=30),
            "idle",
            '{"user_id": "ABC123", "display_name": "Alex J."}',
        ),
        ("int-demo-apple", FULL_ID, "apple_health", True, ts_ago(hours=1), "idle", "{}"),
    ]
    execute_values(
        cur,
        """
        INSERT INTO integrations (id, user_id, provider, is_active, last_synced_at, sync_status, provider_metadata)
        VALUES %s
        ON CONFLICT (id) DO UPDATE SET
          is_active = EXCLUDED.is_active,
          last_synced_at = EXCLUDED.last_synced_at,
          sync_status = EXCLUDED.sync_status
    """,
        rows,
    )
    print(f"  integrations: {len(rows)} rows")


def seed_goals(cur):
    rows = [
        ("goal-demo-steps", FULL_ID, "steps", 10000.0, "DAILY", True),
        ("goal-demo-sleep", FULL_ID, "sleep_hours", 8.0, "DAILY", True),
        ("goal-demo-workouts", FULL_ID, "workouts", 3.0, "WEEKLY", True),
        ("goal-demo-weight", FULL_ID, "weight_kg", 76.0, "LONG_TERM", True),
    ]
    execute_values(
        cur,
        """
        INSERT INTO user_goals (id, user_id, metric, target_value, period, is_active)
        VALUES %s
        ON CONFLICT (id) DO UPDATE SET target_value = EXCLUDED.target_value
    """,
        rows,
    )
    print(f"  user_goals: {len(rows)} rows")


def seed_daily_health_metrics(cur):
    rows = []
    for i in range(30):
        d = days_ago(29 - i)
        dow = d.weekday()
        day = d.day
        age = i  # 0 = oldest, 29 = today

        rows.append(
            (
                f"dhm-demo-{d.strftime('%Y%m%d')}",
                FULL_ID,
                "apple_health",
                d.strftime("%Y-%m-%d"),
                7000 + (dow * 400 + (day * 157) % 5000),  # steps
                350 + (day * 83 + dow * 29) % 200,  # active_calories
                round(68.0 - age * 0.2 + math.sin(day) * 1.5, 1),  # resting_heart_rate
                round(44.0 + age * 0.5 + math.cos(day) * 3.0, 1),  # hrv_ms
                round(39.5 + math.sin(day / 3) * 1.5, 1),  # vo2_max
                round(5000 + (dow * 500 + (day * 211) % 4000), 0),  # distance_meters
                5 + (day * 3) % 10,  # flights_climbed
                round(20.0 - age * 0.05, 1),  # body_fat_percentage
                round(14.0 + math.sin(day / 2) * 1.5, 1),  # respiratory_rate
                round(98.0 + math.sin(day) * 0.8, 1),  # oxygen_saturation
                round(72.0 + math.sin(day / 2) * 4.0, 1),  # heart_rate_avg
            )
        )

    execute_values(
        cur,
        """
        INSERT INTO daily_health_metrics
          (id, user_id, source, date, steps, active_calories, resting_heart_rate,
           hrv_ms, vo2_max, distance_meters, flights_climbed, body_fat_percentage,
           respiratory_rate, oxygen_saturation, heart_rate_avg)
        VALUES %s
        ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  daily_health_metrics: {len(rows)} rows")


def seed_sleep(cur):
    rows = []
    for i in range(30):
        d = days_ago(29 - i)
        dow = d.weekday()
        day = d.day
        weekend_bonus = 0.4 if dow >= 5 else 0.0
        hours = round(7.4 + math.sin(day / 2) * 0.9 + weekend_bonus, 1)
        quality = 68 + (day * 7 + dow * 3) % 17
        rows.append(
            (f"slp-demo-{d.strftime('%Y%m%d')}", FULL_ID, "apple_health", d.strftime("%Y-%m-%d"), hours, quality)
        )

    execute_values(
        cur,
        """
        INSERT INTO sleep_records (id, user_id, source, date, hours, quality_score)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  sleep_records: {len(rows)} rows")


def seed_weight(cur):
    rows = [
        ("wgt-demo-w1", FULL_ID, "apple_health", days_ago(28).strftime("%Y-%m-%d"), 78.8),
        ("wgt-demo-w2", FULL_ID, "apple_health", days_ago(21).strftime("%Y-%m-%d"), 78.6),
        ("wgt-demo-w3", FULL_ID, "apple_health", days_ago(14).strftime("%Y-%m-%d"), 78.3),
        ("wgt-demo-w4", FULL_ID, "apple_health", days_ago(7).strftime("%Y-%m-%d"), 78.1),
        ("wgt-demo-w5", FULL_ID, "apple_health", TODAY.strftime("%Y-%m-%d"), 77.9),
    ]
    execute_values(
        cur,
        """
        INSERT INTO weight_measurements (id, user_id, source, date, weight_kg)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  weight_measurements: {len(rows)} rows")


def seed_nutrition(cur):
    rows = []
    for i in range(30):
        d = days_ago(29 - i)
        dow = d.weekday()
        day = d.day
        rows.append(
            (
                f"nut-demo-{d.strftime('%Y%m%d')}",
                FULL_ID,
                "apple_health",
                d.strftime("%Y-%m-%d"),
                1750 + (day * 47 + dow * 61) % 350,
                round(130.0 + math.sin(day) * 15, 1),
                round(200.0 + math.cos(day) * 25, 1),
                round(62.0 + math.sin(day / 2) * 10, 1),
            )
        )
    execute_values(
        cur,
        """
        INSERT INTO nutrition_entries (id, user_id, source, date, calories, protein_grams, carbs_grams, fat_grams)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  nutrition_entries: {len(rows)} rows")


def seed_activities(cur):
    rows = [
        ("act-demo-run-01", FULL_ID, "strava", "strava-1001", "RUN", 2700, 6200.0, 480, ts_ago(days=28, hours=-7)),
        ("act-demo-str-01", FULL_ID, "strava", "strava-1002", "STRENGTH", 3600, None, 380, ts_ago(days=27, hours=-18)),
        ("act-demo-wlk-01", FULL_ID, "strava", "strava-1003", "WALK", 1800, 2800.0, 170, ts_ago(days=26, hours=-12)),
        ("act-demo-run-02", FULL_ID, "strava", "strava-1004", "RUN", 3000, 7100.0, 530, ts_ago(days=25, hours=-7)),
        ("act-demo-str-02", FULL_ID, "strava", "strava-1005", "STRENGTH", 2700, None, 310, ts_ago(days=24, hours=-18)),
        ("act-demo-run-03", FULL_ID, "strava", "strava-1006", "RUN", 2400, 5400.0, 420, ts_ago(days=23, hours=-6)),
        ("act-demo-str-03", FULL_ID, "strava", "strava-1007", "STRENGTH", 4500, None, 440, ts_ago(days=22, hours=-17)),
        ("act-demo-wlk-02", FULL_ID, "strava", "strava-1008", "WALK", 2100, 3200.0, 200, ts_ago(days=21, hours=-11)),
        ("act-demo-run-04", FULL_ID, "strava", "strava-1009", "RUN", 3300, 8200.0, 610, ts_ago(days=20, hours=-7)),
        ("act-demo-str-04", FULL_ID, "strava", "strava-1010", "STRENGTH", 3000, None, 350, ts_ago(days=19, hours=-18)),
        ("act-demo-run-05", FULL_ID, "strava", "strava-1011", "RUN", 2700, 6500.0, 490, ts_ago(days=18, hours=-6)),
        ("act-demo-str-05", FULL_ID, "strava", "strava-1012", "STRENGTH", 3600, None, 400, ts_ago(days=17, hours=-17)),
        ("act-demo-wlk-03", FULL_ID, "strava", "strava-1013", "WALK", 1500, 2200.0, 140, ts_ago(days=16, hours=-12)),
        ("act-demo-run-06", FULL_ID, "strava", "strava-1014", "RUN", 3600, 9100.0, 670, ts_ago(days=14, hours=-7)),
        ("act-demo-str-06", FULL_ID, "strava", "strava-1015", "STRENGTH", 4500, None, 450, ts_ago(days=13, hours=-18)),
        ("act-demo-run-07", FULL_ID, "strava", "strava-1016", "RUN", 2100, 4800.0, 370, ts_ago(days=11, hours=-6)),
        ("act-demo-str-07", FULL_ID, "strava", "strava-1017", "STRENGTH", 3300, None, 380, ts_ago(days=10, hours=-17)),
        ("act-demo-wlk-04", FULL_ID, "strava", "strava-1018", "WALK", 2400, 3600.0, 220, ts_ago(days=9, hours=-11)),
        ("act-demo-run-08", FULL_ID, "strava", "strava-1019", "RUN", 3000, 7400.0, 550, ts_ago(days=7, hours=-7)),
        ("act-demo-str-08", FULL_ID, "strava", "strava-1020", "STRENGTH", 3600, None, 420, ts_ago(days=6, hours=-18)),
        ("act-demo-run-09", FULL_ID, "strava", "strava-1021", "RUN", 2400, 5600.0, 440, ts_ago(days=4, hours=-6)),
        ("act-demo-str-09", FULL_ID, "strava", "strava-1022", "STRENGTH", 3000, None, 360, ts_ago(days=3, hours=-17)),
        ("act-demo-run-10", FULL_ID, "strava", "strava-1023", "RUN", 3300, 8000.0, 600, ts_ago(days=1, hours=-7)),
    ]
    execute_values(
        cur,
        """
        INSERT INTO unified_activities
          (id, user_id, source, original_id, activity_type, duration_seconds,
           distance_meters, calories, start_time)
        VALUES %s
        ON CONFLICT (source, original_id) DO NOTHING
    """,
        rows,
    )
    print(f"  unified_activities: {len(rows)} rows")


def seed_blood_pressure(cur):
    rows = [
        ("bp-demo-001", FULL_ID, "withings", days_ago(21).strftime("%Y-%m-%d"), ts_ago(days=21), 122.0, 80.0, 67.0),
        ("bp-demo-002", FULL_ID, "withings", days_ago(14).strftime("%Y-%m-%d"), ts_ago(days=14), 119.0, 78.0, 65.0),
        ("bp-demo-003", FULL_ID, "withings", days_ago(7).strftime("%Y-%m-%d"), ts_ago(days=7), 120.0, 79.0, 64.0),
        ("bp-demo-004", FULL_ID, "withings", TODAY.strftime("%Y-%m-%d"), ts_ago(hours=1), 118.0, 77.0, 63.0),
    ]
    execute_values(
        cur,
        """
        INSERT INTO blood_pressure_records
          (id, user_id, source, date, measured_at, systolic_mmhg, diastolic_mmhg, heart_rate_bpm)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  blood_pressure_records: {len(rows)} rows")


def seed_streaks(cur):
    rows = [
        ("str-demo-engagement", FULL_ID, "engagement", 12, 21, TODAY, 1),
        ("str-demo-steps", FULL_ID, "steps", 8, 30, TODAY, 1),
        ("str-demo-workouts", FULL_ID, "workouts", 4, 8, TODAY, 1),
        ("str-demo-checkin", FULL_ID, "checkin", 3, 14, TODAY, 2),
    ]
    execute_values(
        cur,
        """
        INSERT INTO user_streaks
          (id, user_id, streak_type, current_count, longest_count, last_activity_date, freeze_count)
        VALUES %s
        ON CONFLICT (id) DO UPDATE SET
          current_count = EXCLUDED.current_count,
          last_activity_date = EXCLUDED.last_activity_date
    """,
        rows,
    )
    print(f"  user_streaks: {len(rows)} rows")


def seed_achievements(cur):
    rows = [
        ("ach-demo-streak7", FULL_ID, "streak_7", ts_ago(days=5)),
        ("ach-demo-firstgoal", FULL_ID, "first_goal", ts_ago(days=20)),
        ("ach-demo-firstint", FULL_ID, "first_integration", ts_ago(days=28)),
        ("ach-demo-firstchat", FULL_ID, "first_chat", ts_ago(days=25)),
        ("ach-demo-streak30", FULL_ID, "streak_30", None),
        ("ach-demo-connected3", FULL_ID, "connected_3", ts_ago(days=27)),
        ("ach-demo-datarich", FULL_ID, "data_rich_30", ts_ago(days=1)),
        ("ach-demo-overach", FULL_ID, "overachiever", None),
    ]
    execute_values(
        cur,
        """
        INSERT INTO achievements (id, user_id, achievement_key, unlocked_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  achievements: {len(rows)} rows")


def seed_insights(cur):
    rows = [
        (
            "ins-demo-001",
            FULL_ID,
            "sleep_analysis",
            "Sleep quality improved this week",
            "Your average sleep duration rose to 7h 42m — up from 6h 58m last week. Deep sleep phases increased by 12%. Keep it going by maintaining a consistent bedtime.",
            '{"data_points":[{"label":"Mon","value":74},{"label":"Tue","value":68},{"label":"Wed","value":81},{"label":"Thu","value":77},{"label":"Fri","value":85},{"label":"Sat","value":79},{"label":"Sun","value":83}],"chart_title":"Sleep quality this week","chart_unit":"score","sources":[{"name":"Apple Health","icon_name":"apple_health"}]}',
            1,
            ts_ago(hours=2),
            None,
            None,
        ),
        (
            "ins-demo-002",
            FULL_ID,
            "activity_progress",
            "Step count on track for weekly goal",
            "You're averaging 8,432 steps/day — 84% of your 10,000-step goal. Three strong days this week. A 20-minute walk today would put you over target.",
            '{"data_points":[{"label":"Mon","value":9200},{"label":"Tue","value":7800},{"label":"Wed","value":11200},{"label":"Thu","value":6500},{"label":"Fri","value":8900},{"label":"Sat","value":8100},{"label":"Sun","value":7400}],"chart_title":"Daily steps this week","chart_unit":"steps","sources":[{"name":"Apple Health","icon_name":"apple_health"}]}',
            2,
            ts_ago(hours=5),
            None,
            None,
        ),
        (
            "ins-demo-003",
            FULL_ID,
            "correlation_discovery",
            "HRV improves after Zone 2 runs",
            "Over the past 3 weeks, your HRV is consistently 8–12% higher the day after runs under 150 bpm average heart rate. Your body responds well to aerobic base work.",
            '{"data_points":[{"label":"Week 1","value":47},{"label":"Week 2","value":51},{"label":"Week 3","value":54}],"chart_title":"Avg HRV by week (ms)","chart_unit":"ms","sources":[{"name":"Apple Health","icon_name":"apple_health"},{"name":"Strava","icon_name":"strava"}]}',
            3,
            ts_ago(days=1),
            ts_ago(hours=20),
            None,
        ),
        (
            "ins-demo-004",
            FULL_ID,
            "goal_nudge",
            "Resting heart rate trending down",
            "Your RHR dropped from 68 to 63 bpm over 14 days — a strong cardiovascular adaptation signal. Consistent Zone 2 cardio is working.",
            None,
            4,
            ts_ago(days=2),
            ts_ago(days=2),
            ts_ago(days=1),
        ),
    ]
    execute_values(
        cur,
        """
        INSERT INTO insights (id, user_id, type, title, body, data, priority, created_at, read_at, dismissed_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  insights: {len(rows)} rows")


def seed_journals(cur):
    rows = [
        (
            "jnl-demo-t0",
            FULL_ID,
            TODAY,
            8,
            7,
            3,
            8,
            "Good workout this morning. Felt energised all day.",
            '["gym","productive","good-mood"]',
        ),
        (
            "jnl-demo-t1",
            FULL_ID,
            days_ago(1),
            6,
            5,
            5,
            6,
            "Busy day at work. Skipped lunch.",
            '["busy","work","stress"]',
        ),
        (
            "jnl-demo-t2",
            FULL_ID,
            days_ago(2),
            9,
            9,
            2,
            9,
            "Best sleep in weeks. Run felt effortless.",
            '["run","great-sleep","relaxed"]',
        ),
    ]
    execute_values(
        cur,
        """
        INSERT INTO journal_entries (id, user_id, date, mood, energy, stress, sleep_quality, notes, tags)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  journal_entries: {len(rows)} rows")


def seed_quick_logs(cur):
    rows = [
        ("qlog-demo-001", FULL_ID, "water", 250.0, ts_ago(hours=6)),
        ("qlog-demo-002", FULL_ID, "mood", 8.0, ts_ago(hours=7)),
        ("qlog-demo-003", FULL_ID, "water", 250.0, ts_ago(hours=2)),
        ("qlog-demo-004", FULL_ID, "energy", 7.0, ts_ago(hours=1)),
        ("qlog-demo-005", FULL_ID, "water", 500.0, ts_ago(days=1)),
    ]
    execute_values(
        cur,
        """
        INSERT INTO quick_logs (id, user_id, metric_type, value, logged_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  quick_logs: {len(rows)} rows")


def seed_notifications(cur):
    rows = [
        (
            "notif-demo-001",
            FULL_ID,
            "Your health score improved!",
            "Your score jumped 4 points to 76 — great week.",
            "health_score",
            None,
            ts_ago(hours=1),
            None,
        ),
        (
            "notif-demo-002",
            FULL_ID,
            "New insight: Sleep trend",
            "Your sleep quality improved 12% this week. Tap to view.",
            "new_insight",
            "zuralog://insight/ins-demo-001",
            ts_ago(hours=3),
            None,
        ),
        (
            "notif-demo-003",
            FULL_ID,
            "12-day streak — keep going!",
            "You've opened Zuralog 12 days in a row. Don't break it.",
            "streak_milestone",
            None,
            ts_ago(days=1),
            ts_ago(hours=22),
        ),
        (
            "notif-demo-004",
            FULL_ID,
            "Resting heart rate trending down",
            "Your RHR dropped to 63 bpm — a strong cardio signal.",
            "health_trend",
            None,
            ts_ago(days=2),
            ts_ago(days=2),
        ),
    ]
    execute_values(
        cur,
        """
        INSERT INTO notification_logs (id, user_id, title, body, type, deep_link, sent_at, read_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  notification_logs: {len(rows)} rows")


def seed_emergency_card(cur):
    cur.execute(
        """
        INSERT INTO emergency_health_cards
          (id, user_id, blood_type, allergies, medications, conditions, emergency_contacts)
        VALUES (%s, %s, 'O+', '["Penicillin"]', '[]', '[]',
                '[{"name":"Sarah Johnson","relationship":"Partner","phone":"+1-555-0100"}]')
        ON CONFLICT (id) DO NOTHING
    """,
        ("ehc-demo-001", FULL_ID),
    )
    print("  emergency_health_cards: 1 row")


def seed_conversations(cur):
    cur.execute(
        """
        INSERT INTO conversations (id, user_id, title, created_at, updated_at)
        VALUES (%s, %s, 'Health check-in', %s, %s)
        ON CONFLICT (id) DO NOTHING
    """,
        ("conv-demo-001", FULL_ID, ts_ago(days=3), ts_ago(days=3)),
    )

    msgs = [
        ("msg-demo-001", "conv-demo-001", "user", "How was my sleep this week?", ts_ago(days=3)),
        (
            "msg-demo-002",
            "conv-demo-001",
            "assistant",
            "Your sleep averaged 7h 22m this week — 38 minutes below your 8-hour goal. Your best night was Wednesday at 8.1 hours. The pattern shows you fall short on weeknights. Try shifting your bedtime 30 minutes earlier on Tuesday and Thursday first.",
            ts_ago(days=3, seconds=-10),
        ),
        ("msg-demo-003", "conv-demo-001", "user", "What's driving my HRV improvement?", ts_ago(days=3, minutes=-1)),
        (
            "msg-demo-004",
            "conv-demo-001",
            "assistant",
            "Your HRV climbed from 48ms to 54ms over the past 2 weeks — a 12% gain. The clearest driver is your Zone 2 running: three more runs this month at a conversational pace. Low-intensity aerobic work is the most reliable HRV improver. Keep the pace easy and the trend should continue.",
            ts_ago(days=3, seconds=-70),
        ),
    ]
    execute_values(
        cur,
        """
        INSERT INTO messages (id, conversation_id, role, content, created_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        msgs,
    )
    print("  conversations: 1, messages: 4")


def seed_reports(cur):
    from datetime import date

    month_start = date(TODAY.year, TODAY.month, 1) - timedelta(days=1)
    prev_month_start = date(month_start.year, month_start.month, 1)

    rows = [
        (
            "rpt-demo-weekly",
            FULL_ID,
            "weekly",
            days_ago(7),
            days_ago(1),
            '{"category_summaries":[{"category":"activity","category_label":"Activity","average_score":78,"delta_vs_prior":5.2,"key_metric":"Avg Steps","key_metric_value":"8,432/day"},{"category":"sleep","category_label":"Sleep","average_score":71,"delta_vs_prior":-2.1,"key_metric":"Avg Duration","key_metric_value":"7.4 hrs"},{"category":"heart","category_label":"Heart","average_score":84,"delta_vs_prior":3.8,"key_metric":"Avg HRV","key_metric_value":"54 ms"}],"top_correlations":[{"metric_a":"Zone 2 runs","metric_b":"HRV next day","correlation":0.74,"direction":"positive"}],"ai_recommendations":["Shift bedtime 30 min earlier on weeknights","Maintain Zone 2 pace on Tuesday runs for continued HRV gains"],"trend_directions":[{"metric_label":"Daily Steps","direction":"up","change_percent":6.2},{"metric_label":"Sleep Duration","direction":"down","change_percent":-2.1},{"metric_label":"HRV","direction":"up","change_percent":12.5}]}',
        ),
        (
            "rpt-demo-monthly",
            FULL_ID,
            "monthly",
            prev_month_start,
            month_start,
            '{"category_summaries":[{"category":"activity","category_label":"Activity","average_score":75,"delta_vs_prior":8.1,"key_metric":"Total Workouts","key_metric_value":"14 sessions"},{"category":"sleep","category_label":"Sleep","average_score":69,"delta_vs_prior":1.4,"key_metric":"Avg Duration","key_metric_value":"7.2 hrs"},{"category":"heart","category_label":"Heart","average_score":81,"delta_vs_prior":6.2,"key_metric":"Avg RHR","key_metric_value":"64 bpm"}],"top_correlations":[],"ai_recommendations":["Great month for cardiovascular fitness — RHR down 4 bpm","Consider adding one strength session per week"],"trend_directions":[{"metric_label":"Resting HR","direction":"down","change_percent":-5.9},{"metric_label":"Body Weight","direction":"down","change_percent":-1.1},{"metric_label":"HRV","direction":"up","change_percent":18.2}]}',
        ),
    ]
    execute_values(
        cur,
        """
        INSERT INTO reports (id, user_id, type, period_start, period_end, data)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  reports: {len(rows)} rows")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="Seed Zuralog demo accounts")
    parser.add_argument("--reset", action="store_true", help="Wipe all demo data before re-seeding")
    args = parser.parse_args()

    print("\nZuralog demo data seeder")
    print("========================")
    print(f"  demo-full  -> {FULL_ID}  ({FULL_EMAIL})")
    print(f"  demo-empty -> {EMPTY_ID} ({EMPTY_EMAIL})")
    print()

    conn = get_connection()
    conn.autocommit = False
    cur = conn.cursor()

    try:
        if args.reset:
            reset_demo_data(cur)

        print("Seeding demo-full account...")
        seed_users(cur)
        seed_preferences(cur)
        seed_integrations(cur)
        seed_goals(cur)
        seed_daily_health_metrics(cur)
        seed_sleep(cur)
        seed_weight(cur)
        seed_nutrition(cur)
        seed_activities(cur)
        seed_blood_pressure(cur)
        seed_streaks(cur)
        seed_achievements(cur)
        seed_insights(cur)
        seed_journals(cur)
        seed_quick_logs(cur)
        seed_notifications(cur)
        seed_emergency_card(cur)
        seed_conversations(cur)
        seed_reports(cur)

        conn.commit()
        print("\nDone. Both accounts are ready.")
        print("\n  Login credentials (both accounts):")
        print("  Password: ZuraDemo2026!")
        print(f"  Full account:  {FULL_EMAIL}")
        print(f"  Empty account: {EMPTY_EMAIL}")

    except Exception as e:
        conn.rollback()
        print(f"\nERROR: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
