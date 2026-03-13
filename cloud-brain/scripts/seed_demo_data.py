"""
seed_demo_data.py — Zuralog demo account seeder
================================================
Creates and seeds two test accounts in Supabase directly via psycopg2:

  demo-full@zuralog.dev   — 30 days of realistic health data, 5 integrations,
                            goals, streaks, insights, chat history, reports,
                            health score cache, devices, and usage logs.
                            Simulates an active power user with every table
                            populated.

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

Table coverage (23/23)
-----------------------
  users, user_preferences, integrations, user_goals, daily_health_metrics,
  sleep_records, weight_measurements, nutrition_entries, unified_activities,
  blood_pressure_records, user_streaks, achievements, insights, journal_entries,
  quick_logs, notification_logs, emergency_health_cards, conversations, messages,
  reports, health_scores, user_devices, usage_logs
"""

import argparse
import json
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
    # SQLAlchemy async URLs use postgresql+asyncpg:// — strip the driver suffix
    # so psycopg2 gets a plain postgresql:// DSN it can parse.
    db_url = db_url.replace("postgresql+asyncpg://", "postgresql://")
    return psycopg2.connect(db_url)


def reset_demo_data(cur):
    """Wipe all rows belonging to both demo accounts."""
    print("  Resetting demo data...")
    tables_with_user_id = [
        "usage_logs",
        "user_devices",
        "health_scores",
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
    """Seed fully-populated preferences for demo-full with every column set."""
    dashboard_layout = json.dumps(
        {
            "cards": [
                {"id": "health_score", "visible": True, "position": 0},
                {"id": "activity_rings", "visible": True, "position": 1},
                {"id": "steps", "visible": True, "position": 2},
                {"id": "sleep", "visible": True, "position": 3},
                {"id": "heart_rate", "visible": True, "position": 4},
                {"id": "hrv", "visible": True, "position": 5},
                {"id": "nutrition", "visible": True, "position": 6},
                {"id": "weight", "visible": True, "position": 7},
                {"id": "workouts", "visible": True, "position": 8},
            ]
        }
    )
    notification_settings = json.dumps(
        {
            "insights_enabled": True,
            "streak_alerts_enabled": True,
            "achievement_alerts_enabled": True,
            "morning_briefing_enabled": True,
            "goal_nudges_enabled": True,
            "integration_alerts_enabled": True,
            "weekly_report_enabled": True,
            "anomaly_alerts_enabled": True,
        }
    )
    goals = json.dumps(["fitness", "sleep", "weight_loss", "stress"])

    cur.execute(
        """
        INSERT INTO user_preferences
          (id, user_id, coach_persona, proactivity_level, response_length,
           suggested_prompts_enabled, voice_input_enabled,
           theme, haptic_enabled, tooltips_enabled, onboarding_complete,
           morning_briefing_enabled, morning_briefing_time,
           checkin_reminder_enabled, checkin_reminder_time,
           quiet_hours_enabled, quiet_hours_start, quiet_hours_end,
           wellness_checkin_card_visible, data_maturity_banner_dismissed,
           analytics_opt_out, goals, units_system, fitness_level,
           dashboard_layout, notification_settings,
           created_at, updated_at)
        VALUES (%s, %s,
          'balanced', 'medium', 'concise',
          true, true,
          'dark', true, false, true,
          true, '07:30',
          true, '20:00',
          true, '22:00', '07:00',
          true, true,
          false, %s, 'metric', 'active',
          %s, %s,
          NOW(), NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          coach_persona = EXCLUDED.coach_persona,
          proactivity_level = EXCLUDED.proactivity_level,
          response_length = EXCLUDED.response_length,
          suggested_prompts_enabled = EXCLUDED.suggested_prompts_enabled,
          voice_input_enabled = EXCLUDED.voice_input_enabled,
          theme = EXCLUDED.theme,
          fitness_level = EXCLUDED.fitness_level,
          goals = EXCLUDED.goals,
          dashboard_layout = EXCLUDED.dashboard_layout,
          notification_settings = EXCLUDED.notification_settings,
          updated_at = NOW()
    """,
        ("pref-demo-full-001", FULL_ID, goals, dashboard_layout, notification_settings),
    )
    print("  user_preferences: 1 row (fully populated)")


def seed_integrations(cur):
    """Seed 5 integrations: Strava, Fitbit, Apple Health, Withings, Polar."""
    rows = [
        (
            "int-demo-strava",
            FULL_ID,
            "strava",
            True,
            ts_ago(hours=2),
            "idle",
            json.dumps({"athlete_id": 12345678, "athlete_name": "Alex Johnson"}),
        ),
        (
            "int-demo-fitbit",
            FULL_ID,
            "fitbit",
            True,
            ts_ago(minutes=30),
            "idle",
            json.dumps({"user_id": "ABC123", "display_name": "Alex J."}),
        ),
        (
            "int-demo-apple",
            FULL_ID,
            "apple_health",
            True,
            ts_ago(hours=1),
            "idle",
            json.dumps({}),
        ),
        (
            "int-demo-withings",
            FULL_ID,
            "withings",
            True,
            ts_ago(hours=3),
            "idle",
            json.dumps({"userid": 98765432, "firstname": "Alex", "lastname": "Johnson"}),
        ),
        (
            "int-demo-polar",
            FULL_ID,
            "polar",
            True,
            ts_ago(hours=4),
            "idle",
            json.dumps({"polar_user_id": "polar-abc-001", "first_name": "Alex", "last_name": "Johnson"}),
        ),
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
    print(f"  integrations: {len(rows)} rows (Strava, Fitbit, Apple Health, Withings, Polar)")


def seed_goals(cur):
    rows = [
        ("goal-demo-steps", FULL_ID, "steps", 10000.0, "DAILY", True),
        ("goal-demo-sleep", FULL_ID, "sleep_hours", 8.0, "DAILY", True),
        ("goal-demo-workouts", FULL_ID, "workouts", 3.0, "WEEKLY", True),
        ("goal-demo-weight", FULL_ID, "weight_kg", 76.0, "LONG_TERM", True),
        ("goal-demo-calories", FULL_ID, "active_calories", 500.0, "DAILY", True),
        ("goal-demo-water", FULL_ID, "water_ml", 2000.0, "DAILY", True),
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
    """Seed 26 workouts: RUN, STRENGTH, WALK, CYCLE, SWIM."""
    rows = [
        # Runs (10)
        ("act-demo-run-01", FULL_ID, "strava", "strava-1001", "RUN", 2700, 6200.0, 480, ts_ago(days=28, hours=-7)),
        ("act-demo-run-02", FULL_ID, "strava", "strava-1004", "RUN", 3000, 7100.0, 530, ts_ago(days=25, hours=-7)),
        ("act-demo-run-03", FULL_ID, "strava", "strava-1006", "RUN", 2400, 5400.0, 420, ts_ago(days=23, hours=-6)),
        ("act-demo-run-04", FULL_ID, "strava", "strava-1009", "RUN", 3300, 8200.0, 610, ts_ago(days=20, hours=-7)),
        ("act-demo-run-05", FULL_ID, "strava", "strava-1011", "RUN", 2700, 6500.0, 490, ts_ago(days=18, hours=-6)),
        ("act-demo-run-06", FULL_ID, "strava", "strava-1014", "RUN", 3600, 9100.0, 670, ts_ago(days=14, hours=-7)),
        ("act-demo-run-07", FULL_ID, "strava", "strava-1016", "RUN", 2100, 4800.0, 370, ts_ago(days=11, hours=-6)),
        ("act-demo-run-08", FULL_ID, "strava", "strava-1019", "RUN", 3000, 7400.0, 550, ts_ago(days=7, hours=-7)),
        ("act-demo-run-09", FULL_ID, "strava", "strava-1021", "RUN", 2400, 5600.0, 440, ts_ago(days=4, hours=-6)),
        ("act-demo-run-10", FULL_ID, "strava", "strava-1023", "RUN", 3300, 8000.0, 600, ts_ago(days=1, hours=-7)),
        # Strength (9)
        ("act-demo-str-01", FULL_ID, "strava", "strava-1002", "STRENGTH", 3600, None, 380, ts_ago(days=27, hours=-18)),
        ("act-demo-str-02", FULL_ID, "strava", "strava-1005", "STRENGTH", 2700, None, 310, ts_ago(days=24, hours=-18)),
        ("act-demo-str-03", FULL_ID, "strava", "strava-1007", "STRENGTH", 4500, None, 440, ts_ago(days=22, hours=-17)),
        ("act-demo-str-04", FULL_ID, "strava", "strava-1010", "STRENGTH", 3000, None, 350, ts_ago(days=19, hours=-18)),
        ("act-demo-str-05", FULL_ID, "strava", "strava-1012", "STRENGTH", 3600, None, 400, ts_ago(days=17, hours=-17)),
        ("act-demo-str-06", FULL_ID, "strava", "strava-1015", "STRENGTH", 4500, None, 450, ts_ago(days=13, hours=-18)),
        ("act-demo-str-07", FULL_ID, "strava", "strava-1017", "STRENGTH", 3300, None, 380, ts_ago(days=10, hours=-17)),
        ("act-demo-str-08", FULL_ID, "strava", "strava-1020", "STRENGTH", 3600, None, 420, ts_ago(days=6, hours=-18)),
        ("act-demo-str-09", FULL_ID, "strava", "strava-1022", "STRENGTH", 3000, None, 360, ts_ago(days=3, hours=-17)),
        # Walks (4)
        ("act-demo-wlk-01", FULL_ID, "strava", "strava-1003", "WALK", 1800, 2800.0, 170, ts_ago(days=26, hours=-12)),
        ("act-demo-wlk-02", FULL_ID, "strava", "strava-1008", "WALK", 2100, 3200.0, 200, ts_ago(days=21, hours=-11)),
        ("act-demo-wlk-03", FULL_ID, "strava", "strava-1013", "WALK", 1500, 2200.0, 140, ts_ago(days=16, hours=-12)),
        ("act-demo-wlk-04", FULL_ID, "strava", "strava-1018", "WALK", 2400, 3600.0, 220, ts_ago(days=9, hours=-11)),
        # Cycling (2)
        ("act-demo-cyc-01", FULL_ID, "strava", "strava-2001", "CYCLE", 4200, 32500.0, 650, ts_ago(days=15, hours=-9)),
        ("act-demo-cyc-02", FULL_ID, "strava", "strava-2002", "CYCLE", 5400, 48000.0, 820, ts_ago(days=5, hours=-9)),
        # Swimming (1)
        ("act-demo-swm-01", FULL_ID, "fitbit", "fitbit-3001", "SWIM", 2700, 2000.0, 390, ts_ago(days=12, hours=-8)),
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
    print(f"  unified_activities: {len(rows)} rows (RUN, STRENGTH, WALK, CYCLE, SWIM)")


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
        ("ach-demo-streak30", FULL_ID, "streak_30", None),  # locked
        ("ach-demo-connected3", FULL_ID, "connected_3", ts_ago(days=27)),
        ("ach-demo-datarich", FULL_ID, "data_rich_30", ts_ago(days=1)),
        ("ach-demo-overach", FULL_ID, "overachiever", None),  # locked
        ("ach-demo-firstrun", FULL_ID, "first_run", ts_ago(days=28)),
        ("ach-demo-firstswim", FULL_ID, "first_swim", ts_ago(days=12)),
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
    """Seed one card of every insight type for thorough UI coverage."""
    rows = [
        # sleep_analysis
        (
            "ins-demo-001",
            FULL_ID,
            "sleep_analysis",
            "Sleep quality improved this week",
            "Your average sleep duration rose to 7h 42m — up from 6h 58m last week. Deep sleep phases increased by 12%. Keep it going by maintaining a consistent bedtime.",
            json.dumps(
                {
                    "data_points": [
                        {"label": "Mon", "value": 74},
                        {"label": "Tue", "value": 68},
                        {"label": "Wed", "value": 81},
                        {"label": "Thu", "value": 77},
                        {"label": "Fri", "value": 85},
                        {"label": "Sat", "value": 79},
                        {"label": "Sun", "value": 83},
                    ],
                    "chart_title": "Sleep quality this week",
                    "chart_unit": "score",
                    "sources": [{"name": "Apple Health", "icon_name": "apple_health"}],
                }
            ),
            1,
            ts_ago(hours=2),
            None,
            None,
        ),
        # activity_progress
        (
            "ins-demo-002",
            FULL_ID,
            "activity_progress",
            "Step count on track for weekly goal",
            "You're averaging 8,432 steps/day — 84% of your 10,000-step goal. Three strong days this week. A 20-minute walk today would put you over target.",
            json.dumps(
                {
                    "data_points": [
                        {"label": "Mon", "value": 9200},
                        {"label": "Tue", "value": 7800},
                        {"label": "Wed", "value": 11200},
                        {"label": "Thu", "value": 6500},
                        {"label": "Fri", "value": 8900},
                        {"label": "Sat", "value": 8100},
                        {"label": "Sun", "value": 7400},
                    ],
                    "chart_title": "Daily steps this week",
                    "chart_unit": "steps",
                    "sources": [{"name": "Apple Health", "icon_name": "apple_health"}],
                }
            ),
            2,
            ts_ago(hours=5),
            None,
            None,
        ),
        # correlation_discovery
        (
            "ins-demo-003",
            FULL_ID,
            "correlation_discovery",
            "HRV improves after Zone 2 runs",
            "Over the past 3 weeks, your HRV is consistently 8–12% higher the day after runs under 150 bpm average heart rate. Your body responds well to aerobic base work.",
            json.dumps(
                {
                    "data_points": [
                        {"label": "Week 1", "value": 47},
                        {"label": "Week 2", "value": 51},
                        {"label": "Week 3", "value": 54},
                    ],
                    "chart_title": "Avg HRV by week (ms)",
                    "chart_unit": "ms",
                    "sources": [
                        {"name": "Apple Health", "icon_name": "apple_health"},
                        {"name": "Strava", "icon_name": "strava"},
                    ],
                }
            ),
            3,
            ts_ago(days=1),
            ts_ago(hours=20),
            None,
        ),
        # goal_nudge
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
        # nutrition_summary
        (
            "ins-demo-005",
            FULL_ID,
            "nutrition_summary",
            "Protein intake on target this week",
            "You hit your 130g protein target on 5 of 7 days. Average daily intake: 134g. Consider spacing protein more evenly — large dinner spikes can reduce overnight recovery.",
            json.dumps(
                {
                    "data_points": [
                        {"label": "Mon", "value": 142},
                        {"label": "Tue", "value": 118},
                        {"label": "Wed", "value": 139},
                        {"label": "Thu", "value": 127},
                        {"label": "Fri", "value": 145},
                        {"label": "Sat", "value": 130},
                        {"label": "Sun", "value": 137},
                    ],
                    "chart_title": "Daily protein (g)",
                    "chart_unit": "g",
                    "sources": [{"name": "Apple Health", "icon_name": "apple_health"}],
                }
            ),
            3,
            ts_ago(days=3),
            ts_ago(days=2),
            None,
        ),
        # anomaly_alert
        (
            "ins-demo-006",
            FULL_ID,
            "anomaly_alert",
            "Resting heart rate spike detected",
            "Your RHR jumped to 74 bpm yesterday — 11 bpm above your 7-day average of 63. This can indicate fatigue, dehydration, or early illness. Consider a rest day and monitor hydration.",
            json.dumps(
                {
                    "data_points": [
                        {"label": "7 days ago", "value": 64},
                        {"label": "6 days ago", "value": 63},
                        {"label": "5 days ago", "value": 62},
                        {"label": "4 days ago", "value": 63},
                        {"label": "3 days ago", "value": 64},
                        {"label": "Yesterday", "value": 74},
                    ],
                    "chart_title": "Resting heart rate (bpm)",
                    "chart_unit": "bpm",
                    "sources": [{"name": "Apple Health", "icon_name": "apple_health"}],
                    "anomaly": {"expected": 63, "actual": 74, "threshold": 10},
                }
            ),
            1,
            ts_ago(hours=8),
            None,
            None,
        ),
        # streak_milestone
        (
            "ins-demo-007",
            FULL_ID,
            "streak_milestone",
            "12-day engagement streak",
            "You've opened Zuralog 12 days in a row — your longest run this month. Consistency is the foundation of lasting change. Keep the habit going.",
            json.dumps(
                {
                    "streak_type": "engagement",
                    "current_count": 12,
                    "longest_count": 21,
                }
            ),
            2,
            ts_ago(days=1, hours=-2),
            ts_ago(days=1),
            None,
        ),
        # welcome (unread, for new-ish users — still useful as a historical card)
        (
            "ins-demo-008",
            FULL_ID,
            "welcome",
            "Welcome to Zuralog, Alex!",
            "Your data is in. I'm already seeing patterns worth exploring — your sleep and HRV are closely linked. Ask me anything or check your first insights above.",
            json.dumps({}),
            5,
            ts_ago(days=28),
            ts_ago(days=27),
            None,
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
    print(f"  insights: {len(rows)} rows (all 8 types covered)")


def seed_journals(cur):
    """Seed 30 days of journal entries — one per day."""
    notes_pool = [
        "Good workout this morning. Felt energised all day.",
        "Busy day at work. Skipped lunch.",
        "Best sleep in weeks. Run felt effortless.",
        "Tired — late meeting ran long. Early night.",
        "Solid day. Hit step goal easily.",
        "Rest day. Stretched and walked. Feel recovered.",
        "Stressful presentation but it went well.",
        "Good zone 2 run. HRV should be up tomorrow.",
        "Social evening — stayed up later than planned.",
        "Morning swim. Felt sluggish at first, strong finish.",
        "Clean eating day. Mood noticeably better.",
        "Missed workout — life got in the way. Back tomorrow.",
        "Great strength session. New PB on deadlift.",
        "Weather was perfect for a long run.",
        "Hydration off — had a headache mid-afternoon.",
        "Early morning cycle. Legs felt heavy.",
        "Productive work day. Evening walk helped unwind.",
        "Surprisingly good energy on low sleep.",
        "Mindfulness session + light walk. Very restorative.",
        "Heavy lifting day — left feeling strong.",
        "Family dinner, relaxed evening.",
        "Core and mobility work. Long overdue.",
        "Back-to-back meetings. Stress levels elevated.",
        "Interval run — tough but satisfying.",
        "Light activity only. Slight knee discomfort.",
        "Perfect sleep. Dreams vivid. Feel refreshed.",
        "High step count from city exploration.",
        "Fasted morning workout. Not for me.",
        "Busy day — skipped lunch again.",
        "Feeling strong. Ready for the week.",
    ]
    tags_pool = [
        '["gym","productive","good-mood"]',
        '["busy","work","stress"]',
        '["run","great-sleep","relaxed"]',
        '["tired","late-night"]',
        '["steps","active"]',
        '["rest","recovery"]',
        '["work","stress","win"]',
        '["run","zone2","hrv"]',
        '["social","late-night"]',
        '["swim","sluggish"]',
        '["nutrition","mood"]',
        '["missed","rest"]',
        '["strength","pb"]',
        '["run","weather","great"]',
        '["hydration","headache"]',
        '["cycle","tired"]',
        '["work","walk","calm"]',
        '["energy","sleep"]',
        '["mindfulness","walk"]',
        '["strength","heavy"]',
        '["family","relaxed"]',
        '["mobility","core"]',
        '["meetings","stress"]',
        '["intervals","run"]',
        '["light","knee"]',
        '["sleep","dreams"]',
        '["steps","city"]',
        '["fasted","workout"]',
        '["busy","skipped-lunch"]',
        '["strong","motivated"]',
    ]
    rows = []
    for i in range(30):
        d = days_ago(29 - i)
        dow = d.weekday()
        day = d.day
        mood = 5 + (day * 3 + dow) % 5  # 5–9
        energy = 5 + (day * 7 + dow * 2) % 5  # 5–9
        stress = 1 + (day * 5 + dow * 3) % 5  # 1–5
        sleep_q = 5 + (day * 11 + dow) % 5  # 5–9
        rows.append(
            (
                f"jnl-demo-{d.strftime('%Y%m%d')}",
                FULL_ID,
                d,
                mood,
                energy,
                stress,
                sleep_q,
                notes_pool[i % len(notes_pool)],
                tags_pool[i % len(tags_pool)],
            )
        )
    execute_values(
        cur,
        """
        INSERT INTO journal_entries (id, user_id, date, mood, energy, stress, sleep_quality, notes, tags)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  journal_entries: {len(rows)} rows (30 days)")


def seed_quick_logs(cur):
    """Seed ~4 quick logs per day across 7 days (water, mood, energy, stress)."""
    rows = []
    for day_offset in range(7):
        base = ts_ago(days=day_offset)
        d = days_ago(day_offset)
        day = d.day
        # Water: 3× per day
        rows.append((f"qlog-water-{d.strftime('%Y%m%d')}-a", FULL_ID, "water", 250.0, base - timedelta(hours=1)))
        rows.append((f"qlog-water-{d.strftime('%Y%m%d')}-b", FULL_ID, "water", 250.0, base - timedelta(hours=4)))
        rows.append((f"qlog-water-{d.strftime('%Y%m%d')}-c", FULL_ID, "water", 500.0, base - timedelta(hours=8)))
        # Mood: 1× per day
        rows.append(
            (f"qlog-mood-{d.strftime('%Y%m%d')}", FULL_ID, "mood", float(5 + (day * 3) % 5), base - timedelta(hours=6))
        )
        # Energy: 1× per day
        rows.append(
            (
                f"qlog-energy-{d.strftime('%Y%m%d')}",
                FULL_ID,
                "energy",
                float(5 + (day * 7) % 5),
                base - timedelta(hours=5),
            )
        )
        # Stress: every other day
        if day_offset % 2 == 0:
            rows.append(
                (
                    f"qlog-stress-{d.strftime('%Y%m%d')}",
                    FULL_ID,
                    "stress",
                    float(1 + (day * 5) % 5),
                    base - timedelta(hours=3),
                )
            )

    execute_values(
        cur,
        """
        INSERT INTO quick_logs (id, user_id, metric_type, value, logged_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  quick_logs: {len(rows)} rows (7 days, water/mood/energy/stress)")


def seed_notifications(cur):
    """Seed 10 notification_logs using only valid NOTIFICATION_TYPES values:
    insight, anomaly, streak, achievement, reminder, briefing, integration_alert.
    """
    rows = [
        (
            "notif-demo-001",
            FULL_ID,
            "Your health score improved!",
            "Your score jumped 4 points to 76 — great week.",
            "briefing",
            None,
            ts_ago(hours=1),
            None,
        ),
        (
            "notif-demo-002",
            FULL_ID,
            "New insight: Sleep trend",
            "Your sleep quality improved 12% this week. Tap to view.",
            "insight",
            "zuralog://insight/ins-demo-001",
            ts_ago(hours=3),
            None,
        ),
        (
            "notif-demo-003",
            FULL_ID,
            "12-day streak — keep going!",
            "You've opened Zuralog 12 days in a row. Don't break it.",
            "streak",
            None,
            ts_ago(days=1),
            ts_ago(hours=22),
        ),
        (
            "notif-demo-004",
            FULL_ID,
            "Resting heart rate trending down",
            "Your RHR dropped to 63 bpm — a strong cardio signal.",
            "anomaly",
            None,
            ts_ago(days=2),
            ts_ago(days=2),
        ),
        (
            "notif-demo-005",
            FULL_ID,
            "Achievement unlocked: First Integration",
            "You connected your first data source. Data is the foundation of insight.",
            "achievement",
            None,
            ts_ago(days=28),
            ts_ago(days=28),
        ),
        (
            "notif-demo-006",
            FULL_ID,
            "Daily goal reminder: Steps",
            "You're at 6,200 steps — 62% of your daily goal. A quick walk gets you there.",
            "reminder",
            None,
            ts_ago(days=3),
            ts_ago(days=3),
        ),
        (
            "notif-demo-007",
            FULL_ID,
            "Weekly briefing: Strong week",
            "8 workouts, 58,000 steps, average sleep 7h 24m. Full report in the app.",
            "briefing",
            "zuralog://report/rpt-demo-weekly",
            ts_ago(days=7),
            ts_ago(days=7),
        ),
        (
            "notif-demo-008",
            FULL_ID,
            "Fitbit sync error",
            "We couldn't sync your Fitbit data. Tap to reconnect.",
            "integration_alert",
            "zuralog://integrations/fitbit",
            ts_ago(days=5),
            ts_ago(days=5),
        ),
        (
            "notif-demo-009",
            FULL_ID,
            "HRV spike detected",
            "Your HRV dropped 20% overnight — possible stress or poor recovery. Rest day recommended.",
            "anomaly",
            None,
            ts_ago(days=4),
            None,
        ),
        (
            "notif-demo-010",
            FULL_ID,
            "Achievement unlocked: Data Rich",
            "30 days of continuous health data. Your AI coach now has full context.",
            "achievement",
            None,
            ts_ago(days=1),
            None,
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
    """Seed emergency health card.

    The local DB schema (from migration b2c3d4e5f6a7) has both `id` (PK) and
    `user_id` columns. The SQLAlchemy model later changed to use `user_id` as
    the PK, but migrations were not retroactively updated. We use the actual
    DB layout — insert `id` as a surrogate varchar PK and `user_id` separately.
    We ON CONFLICT on `id` to remain idempotent.
    """
    cur.execute(
        """
        INSERT INTO emergency_health_cards
          (id, user_id, blood_type, allergies, medications, conditions,
           emergency_contacts)
        VALUES (
          %s, %s, 'O+',
          '["Penicillin", "Shellfish"]',
          '["Vitamin D 2000IU daily", "Fish oil 1g daily"]',
          '["Mild asthma (exercise-induced)"]',
          '[{"name":"Sarah Johnson","relationship":"Partner","phone":"+1-555-0100"},{"name":"Michael Johnson","relationship":"Father","phone":"+1-555-0199"}]'
        )
        ON CONFLICT (id) DO UPDATE SET
          blood_type = EXCLUDED.blood_type,
          allergies = EXCLUDED.allergies,
          medications = EXCLUDED.medications,
          conditions = EXCLUDED.conditions,
          emergency_contacts = EXCLUDED.emergency_contacts
    """,
        ("ehc-demo-001", FULL_ID),
    )
    print("  emergency_health_cards: 1 row (fully populated)")


def seed_conversations(cur):
    """Seed 2 conversations with realistic message threads."""
    # Conversation 1: Health check-in (older)
    cur.execute(
        """
        INSERT INTO conversations (id, user_id, title, created_at, updated_at)
        VALUES (%s, %s, 'Health check-in', %s, %s)
        ON CONFLICT (id) DO NOTHING
    """,
        ("conv-demo-001", FULL_ID, ts_ago(days=3), ts_ago(days=3)),
    )

    # Conversation 2: Training plan (more recent)
    cur.execute(
        """
        INSERT INTO conversations (id, user_id, title, archived, created_at, updated_at)
        VALUES (%s, %s, 'Training plan for next month', false, %s, %s)
        ON CONFLICT (id) DO NOTHING
    """,
        ("conv-demo-002", FULL_ID, ts_ago(days=1), ts_ago(hours=2)),
    )

    msgs = [
        # Conversation 1
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
        # Conversation 2
        (
            "msg-demo-005",
            "conv-demo-002",
            "user",
            "Can you build me a 4-week training plan to improve my 5K time?",
            ts_ago(days=1),
        ),
        (
            "msg-demo-006",
            "conv-demo-002",
            "assistant",
            "Based on your current fitness (VO2max ~39.5, Zone 2 base established), here's a 4-week 5K plan:\n\n**Week 1–2 — Base building**\n• 3× easy runs (30–35 min at conversational pace)\n• 1× strides session (8×20s at mile effort with 90s recovery)\n• 1× strength session\n\n**Week 3 — Quality**\n• 2× easy runs\n• 1× tempo run (20 min at comfortably hard effort)\n• 1× 400m intervals (6–8 reps)\n• 1× strength session\n\n**Week 4 — Taper**\n• 3× easy runs (shorter)\n• Race day or time trial\n\nYour current HRV trend suggests you can handle this load. Want me to schedule specific sessions?",
            ts_ago(hours=23),
        ),
        ("msg-demo-007", "conv-demo-002", "user", "Yes, schedule it. I prefer morning runs.", ts_ago(hours=22)),
        (
            "msg-demo-008",
            "conv-demo-002",
            "assistant",
            "Perfect. I've outlined a week 1 schedule based on your morning preference and existing workout pattern:\n\n• **Monday** 7am — Easy 30 min run\n• **Wednesday** 7am — Easy 35 min run + 8 strides\n• **Thursday** 6pm — Strength session (existing habit)\n• **Friday** 7am — Easy 30 min run\n• **Sunday** — Rest or light walk\n\nI'll track your progress against this and flag if load or recovery signals change. How does Monday morning feel?",
            ts_ago(hours=2),
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
    print(f"  conversations: 2, messages: {len(msgs)}")


def seed_reports(cur):
    month_start = date(TODAY.year, TODAY.month, 1) - timedelta(days=1)
    prev_month_start = date(month_start.year, month_start.month, 1)

    rows = [
        (
            "rpt-demo-weekly",
            FULL_ID,
            "weekly",
            days_ago(7),
            days_ago(1),
            json.dumps(
                {
                    "category_summaries": [
                        {
                            "category": "activity",
                            "category_label": "Activity",
                            "average_score": 78,
                            "delta_vs_prior": 5.2,
                            "key_metric": "Avg Steps",
                            "key_metric_value": "8,432/day",
                        },
                        {
                            "category": "sleep",
                            "category_label": "Sleep",
                            "average_score": 71,
                            "delta_vs_prior": -2.1,
                            "key_metric": "Avg Duration",
                            "key_metric_value": "7.4 hrs",
                        },
                        {
                            "category": "heart",
                            "category_label": "Heart",
                            "average_score": 84,
                            "delta_vs_prior": 3.8,
                            "key_metric": "Avg HRV",
                            "key_metric_value": "54 ms",
                        },
                        {
                            "category": "nutrition",
                            "category_label": "Nutrition",
                            "average_score": 72,
                            "delta_vs_prior": 1.4,
                            "key_metric": "Avg Calories",
                            "key_metric_value": "1,890 kcal",
                        },
                    ],
                    "top_correlations": [
                        {
                            "metric_a": "Zone 2 runs",
                            "metric_b": "HRV next day",
                            "correlation": 0.74,
                            "direction": "positive",
                        },
                    ],
                    "ai_recommendations": [
                        "Shift bedtime 30 min earlier on weeknights",
                        "Maintain Zone 2 pace on Tuesday runs for continued HRV gains",
                    ],
                    "trend_directions": [
                        {"metric_label": "Daily Steps", "direction": "up", "change_percent": 6.2},
                        {"metric_label": "Sleep Duration", "direction": "down", "change_percent": -2.1},
                        {"metric_label": "HRV", "direction": "up", "change_percent": 12.5},
                    ],
                }
            ),
        ),
        (
            "rpt-demo-monthly",
            FULL_ID,
            "monthly",
            prev_month_start,
            month_start,
            json.dumps(
                {
                    "category_summaries": [
                        {
                            "category": "activity",
                            "category_label": "Activity",
                            "average_score": 75,
                            "delta_vs_prior": 8.1,
                            "key_metric": "Total Workouts",
                            "key_metric_value": "14 sessions",
                        },
                        {
                            "category": "sleep",
                            "category_label": "Sleep",
                            "average_score": 69,
                            "delta_vs_prior": 1.4,
                            "key_metric": "Avg Duration",
                            "key_metric_value": "7.2 hrs",
                        },
                        {
                            "category": "heart",
                            "category_label": "Heart",
                            "average_score": 81,
                            "delta_vs_prior": 6.2,
                            "key_metric": "Avg RHR",
                            "key_metric_value": "64 bpm",
                        },
                    ],
                    "top_correlations": [],
                    "ai_recommendations": [
                        "Great month for cardiovascular fitness — RHR down 4 bpm",
                        "Consider adding one strength session per week",
                    ],
                    "trend_directions": [
                        {"metric_label": "Resting HR", "direction": "down", "change_percent": -5.9},
                        {"metric_label": "Body Weight", "direction": "down", "change_percent": -1.1},
                        {"metric_label": "HRV", "direction": "up", "change_percent": 18.2},
                    ],
                }
            ),
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


def seed_health_scores(cur):
    """Seed 30 days of cached health scores — exercises the health_scores table."""
    rows = []
    for i in range(30):
        d = days_ago(29 - i)
        day = d.day
        age = i  # 0=oldest, 29=today

        # Overall score trends upward slightly over 30 days
        score = int(62 + age * 0.4 + math.sin(day / 2) * 4)
        # Keys match the live HealthScoreCalculator's contributing_metrics
        sub_scores = {
            "sleep": int(65 + math.sin(day / 3) * 8),
            "hrv": int(55 + age * 0.4 + math.sin(day / 2) * 6),
            "resting_hr": int(70 + age * 0.3 + math.cos(day) * 4),
            "activity": int(60 + age * 0.5 + math.sin(day) * 5),
            "sleep_consistency": int(60 + math.sin(day / 4) * 6),
            "steps": int(58 + age * 0.3 + math.cos(day / 3) * 5),
        }
        commentaries = ["Activity", "Sleep quality", "Heart health", "HRV trend", "Recovery", "Step count"]
        commentary = commentaries[(day + age) % len(commentaries)]

        rows.append(
            (
                FULL_ID,
                d.strftime("%Y-%m-%d"),
                score,
                json.dumps(sub_scores),
                commentary,
            )
        )

    execute_values(
        cur,
        """
        INSERT INTO health_scores (user_id, score_date, score, sub_scores_json, commentary)
        VALUES %s
        ON CONFLICT (user_id, score_date) DO UPDATE SET
          score = EXCLUDED.score,
          sub_scores_json = EXCLUDED.sub_scores_json,
          commentary = EXCLUDED.commentary
    """,
        rows,
    )
    print(f"  health_scores: {len(rows)} rows (30 days)")


def seed_user_devices(cur):
    """Seed 2 device registrations (iOS + Android) for demo-full."""
    rows = [
        (
            "dev-demo-ios-001",
            FULL_ID,
            "fcm-token-demo-ios-abc123xyz456def789ghi012jkl345mno678pqr901stu234vwx",
            "ios",
            ts_ago(minutes=5),
        ),
        (
            "dev-demo-android-001",
            FULL_ID,
            "fcm-token-demo-android-abc123xyz456def789ghi012jkl345mno678pqr901stu2",
            "android",
            ts_ago(days=3),
        ),
    ]
    execute_values(
        cur,
        """
        INSERT INTO user_devices (id, user_id, fcm_token, platform, last_seen_at)
        VALUES %s
        ON CONFLICT (id) DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at
    """,
        rows,
    )
    print(f"  user_devices: {len(rows)} rows (ios + android)")


def seed_usage_logs(cur):
    """Seed 20 LLM usage log entries across the last 28 days."""
    models = ["moonshotai/kimi-k2.5", "moonshotai/kimi-k2.5", "moonshotai/kimi-k2.5", "openai/gpt-4o-mini"]
    rows = []
    for i in range(20):
        # Spread across 28 days, roughly every 1–2 days
        days_offset = i * 1.4
        hours_offset = (i * 7) % 12
        rows.append(
            (
                f"ulog-demo-{i:03d}",
                FULL_ID,
                models[i % len(models)],
                800 + (i * 127) % 1200,  # input_tokens: 800–2000
                150 + (i * 83) % 450,  # output_tokens: 150–600
                ts_ago(days=int(days_offset), hours=hours_offset),
            )
        )

    execute_values(
        cur,
        """
        INSERT INTO usage_logs (id, user_id, model, input_tokens, output_tokens, created_at)
        VALUES %s ON CONFLICT (id) DO NOTHING
    """,
        rows,
    )
    print(f"  usage_logs: {len(rows)} rows (20 LLM calls)")


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
        seed_health_scores(cur)
        seed_user_devices(cur)
        seed_usage_logs(cur)

        conn.commit()
        print("\nDone. Both accounts are ready.")
        print("\n  Login credentials (both accounts):")
        print("  Password: ZuraDemo2026!")
        print(f"  Full account:  {FULL_EMAIL}")
        print(f"  Empty account: {EMPTY_EMAIL}")
        print()
        print("  Tables seeded (23/23):")
        print("    users, user_preferences, integrations, user_goals,")
        print("    daily_health_metrics, sleep_records, weight_measurements,")
        print("    nutrition_entries, unified_activities, blood_pressure_records,")
        print("    user_streaks, achievements, insights, journal_entries,")
        print("    quick_logs, notification_logs, emergency_health_cards,")
        print("    conversations, messages, reports, health_scores,")
        print("    user_devices, usage_logs")

    except Exception as e:
        conn.rollback()
        print(f"\nERROR: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
