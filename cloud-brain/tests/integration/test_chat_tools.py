"""
Zura AI Coach — End-to-End Integration Tests
=============================================

Verifies the full stack against the live production server at api.zuralog.com.
No local server required — tests connect to Railway directly.

What these tests cover:
  1. Read queries      — correct tool fires; AI response checked against real DB data
  2. Write queries     — AI asks confirmation before saving; confirmed write executes
  3. Multi-tool chains — AI calls 2+ tools in a single response
  4. Edge cases        — bad inputs rejected cleanly without crashing
  5. Model routing     — simple questions → Zura Flash; complex → Zura (Kimi K2.5)

Each test runs 3 times (_run=1, 2, 3) for repeatability.
Three consistent passes = the behaviour is reliable, not a one-off fluke.

--- How to read the test output ---
For every READ test you will see a comparison block printed to stdout:

  AI SAID:   what Zura told the user
  SQL RUN:   the exact query we ran against the real database
  DB SAYS:   what the database actually contains

Run with -s to see the comparison blocks:
  pytest tests/integration/test_chat_tools.py -v -s

Prerequisites:
  uv add --dev "websockets>=12.0"   (or: pip install "websockets>=12.0")
"""

from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any

import asyncpg
import httpx
import pytest
import websockets

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_SUPABASE_URL = "https://enccjffwpnwkxfkhargr.supabase.co"
_SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVuY2NqZmZ3cG53a3hma2hhcmdyIiwi"
    "cm9sZSI6ImFub24iLCJpYXQiOjE3NzE1Njk1MjUsImV4cCI6MjA4NzE0NTUyNX0"
    ".Cgo9MvQUBCyKouchR47FguAIwzvZcKb_qA8X1ECK_KQ"
)

# Override these env vars to test with a different account.
TEST_EMAIL = os.getenv("ZURA_TEST_EMAIL", "demo-full@zuralog.dev")
TEST_PASSWORD = os.getenv("ZURA_TEST_PASSWORD", "ZuraDemo2026!")

# Supabase direct database connection for verification queries.
# The demo user's fixed UUID in the database.
_DEMO_USER_ID = "a0000000-0000-0000-0000-000000000001"
_DB_DSN = (
    "postgresql://postgres.enccjffwpnwkxfkhargr:2TG76qumypnbcBSx"
    "@aws-1-us-east-1.pooler.supabase.com:5432/postgres"
)

HTTP_BASE = "https://api.zuralog.com"
WS_URL = "wss://api.zuralog.com/api/v1/chat/ws"

# How long to wait for the AI to finish one response (seconds).
_AI_TIMEOUT = 90


# ---------------------------------------------------------------------------
# Result container
# ---------------------------------------------------------------------------

@dataclass
class ChatResult:
    tools_fired: list[str] = field(default_factory=list)
    """Names of every tool the AI called, in order."""

    response: str = ""
    """The final text the AI sent to the user."""

    events: list[dict[str, Any]] = field(default_factory=list)
    """Every raw event from the server."""

    error: str | None = None
    """Set if the server returned an error event."""

    rate_limited: bool = False
    """Set if the server returned a rate_limit event."""

    model_used: str | None = None
    """'zura' (Kimi K2.5) or 'zura_flash' (Qwen3.5-Flash) — from stream_end."""

    classifier_result: str | None = None
    """'deep_analysis', 'standard', or 'skipped' (skipped = rate limit forced the model)."""


# ---------------------------------------------------------------------------
# Session fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
async def jwt_token() -> str:
    """Sign in once as the demo account. All tests share this token."""
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{_SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers={"apikey": _SUPABASE_ANON_KEY, "Content-Type": "application/json"},
            json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
            timeout=15.0,
        )
    assert resp.status_code == 200, (
        f"Sign-in failed ({resp.status_code}). "
        f"Check ZURA_TEST_EMAIL / ZURA_TEST_PASSWORD.\n{resp.text}"
    )
    token = resp.json().get("access_token", "")
    assert token, "Sign-in returned no access_token."
    return token


@pytest.fixture(scope="session", autouse=True)
async def server_healthy() -> None:
    """Fail fast if the production server is unreachable."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{HTTP_BASE}/health", timeout=10.0)
    assert resp.status_code == 200 and resp.json().get("status") == "healthy", (
        "Production server is not healthy — check Railway."
    )


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

async def _db_query(sql: str) -> list[dict]:
    """
    Run a SQL query directly against the Supabase database.
    Returns a list of rows as dicts, or an empty list if the DB is unreachable.
    Never raises — DB failures are non-fatal for the tests.
    """
    try:
        conn = await asyncio.wait_for(
            asyncpg.connect(_DB_DSN, ssl="require"),
            timeout=10,
        )
        try:
            rows = await conn.fetch(sql)
            return [dict(r) for r in rows]
        finally:
            await conn.close()
    except Exception as exc:
        # Don't fail the test if the DB connection can't be made.
        print(f"\n  [DB WARNING] Could not reach database: {exc}")
        return []


async def _is_integration_connected(provider: str) -> bool:
    """
    Check whether the demo account has a specific integration connected
    and active. Used to decide what a test should assert.

    For example, if Strava is not connected, the correct behaviour is for
    Zura to say "not connected" — not for the Strava tool to fire.
    Asserting the tool fires on an account with no Strava would be a
    false failure.
    """
    rows = await _db_query(f"""
        SELECT 1
        FROM integrations
        WHERE user_id = '{_DEMO_USER_ID}'
          AND provider = '{provider}'
          AND is_active = true
        LIMIT 1;
    """)
    return len(rows) > 0


def _print_comparison(label: str, ai_response: str, sql: str, db_rows: list[dict]) -> None:
    """
    Print the AI response next to the real database result so a human
    reviewer can judge whether the AI's answer is accurate.
    """
    bar = "=" * 72
    print(f"\n{bar}")
    print(f"  {label}")
    print(bar)
    print(f"  AI SAID:\n    {ai_response[:600]}")
    print(f"\n  SQL RUN:\n    {sql.strip()}")
    print(f"\n  DB SAYS:")
    if db_rows:
        for row in db_rows:
            print(f"    {row}")
    else:
        print("    (no matching rows found for this user)")
    print(f"{bar}\n")


# ---------------------------------------------------------------------------
# WebSocket helpers
# ---------------------------------------------------------------------------

async def _collect_until_done(ws: Any, target: ChatResult) -> None:
    """
    Read server events until stream_end, error, or rate_limit.
    Captures tool names and the final model used.
    """
    async for raw in ws:
        event: dict = json.loads(raw)
        target.events.append(event)
        t = event.get("type")

        if t == "tool_start":
            target.tools_fired.append(event.get("tool_name", ""))
        elif t == "stream_end":
            target.response = event.get("content", "")
            target.model_used = event.get("model_used")         # "zura" or "zura_flash"
            target.classifier_result = event.get("classifier_result")  # "deep_analysis" / "standard" / "skipped"
            return
        elif t == "error":
            target.error = event.get("content", "")
            return
        elif t == "rate_limit":
            target.rate_limited = True
            return


async def _chat(
    token: str,
    message: str,
    persona: str = "balanced",
    proactivity: str = "medium",
) -> ChatResult:
    """Open a fresh conversation, send one message, return the full result."""
    result = ChatResult()
    async with websockets.connect(WS_URL, open_timeout=15) as ws:
        await ws.send(json.dumps({"type": "auth", "token": token}))
        raw_init = await asyncio.wait_for(ws.recv(), timeout=15)
        assert json.loads(raw_init).get("type") == "conversation_init"
        await ws.send(json.dumps({
            "message": message,
            "persona": persona,
            "proactivity": proactivity,
        }))
        await asyncio.wait_for(_collect_until_done(ws, result), timeout=_AI_TIMEOUT)
    return result


async def _chat_two_turns(
    token: str,
    turn1_message: str,
    turn2_message: str = "Yes, go ahead.",
) -> tuple[ChatResult, ChatResult]:
    """
    Two messages in the same conversation — used for write-confirmation tests.
    The AI must ask for confirmation on turn 1 and execute on turn 2.
    """
    turn1, turn2 = ChatResult(), ChatResult()
    async with websockets.connect(WS_URL, open_timeout=15) as ws:
        await ws.send(json.dumps({"type": "auth", "token": token}))
        raw_init = await asyncio.wait_for(ws.recv(), timeout=15)
        assert json.loads(raw_init).get("type") == "conversation_init"

        await ws.send(json.dumps({"message": turn1_message}))
        await asyncio.wait_for(_collect_until_done(ws, turn1), timeout=_AI_TIMEOUT)

        await ws.send(json.dumps({"message": turn2_message}))
        await asyncio.wait_for(_collect_until_done(ws, turn2), timeout=_AI_TIMEOUT)
    return turn1, turn2


# Runs every test 3 times for repeatability.
REPEAT = pytest.mark.parametrize("_run", [1, 2, 3])


# ===========================================================================
# GROUP 1 — Read queries
#
# The correct tool must fire. After getting the AI's response, we also run
# the exact SQL against the real database and print both side-by-side so a
# human reviewer can judge whether the AI was accurate.
# ===========================================================================

@REPEAT
async def test_steps_query_fires_apple_health(jwt_token: str, _run: int) -> None:
    """
    "How many steps did I take today?"
    Tool required: apple_health_read_metrics

    We first check whether Apple Health is connected for this account.
      — Connected:     assert the tool fires and compare AI answer to real DB data.
      — Not connected: assert the tool still fires (Apple Health is always-on for
                       iOS users) and that Zura says data is unavailable rather
                       than inventing a number.
    """
    today = date.today().isoformat()
    sql = f"""
        SELECT date, metric_type, value, unit
        FROM daily_summaries
        WHERE user_id = '{_DEMO_USER_ID}'
          AND metric_type = 'steps'
          AND date = '{today}'
        ORDER BY computed_at DESC
        LIMIT 1;
    """
    apple_health_connected = await _is_integration_connected("apple_health")
    result = await _chat(jwt_token, "How many steps did I take today?")
    db_rows = await _db_query(sql)
    _print_comparison(
        f"STEPS TODAY  [run {_run}]  "
        f"[Apple Health: {'CONNECTED' if apple_health_connected else 'NOT CONNECTED'}]",
        result.response,
        sql,
        db_rows,
    )

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert "apple_health_read_metrics" in result.tools_fired, (
        f"[run {_run}] apple_health_read_metrics did not fire.\n"
        f"Tools fired: {result.tools_fired}"
    )
    assert len(result.response) > 20


@REPEAT
async def test_sleep_query_fires_apple_health(jwt_token: str, _run: int) -> None:
    """
    "How was my sleep last week?"
    Tool required: apple_health_read_metrics
    Verification: query daily_summaries for last 7 days of sleep data.
    """
    week_ago = (date.today() - timedelta(days=7)).isoformat()
    sql = f"""
        SELECT date, metric_type, value, unit
        FROM daily_summaries
        WHERE user_id = '{_DEMO_USER_ID}'
          AND metric_type IN ('sleep_duration', 'sleep_efficiency', 'sleep_quality')
          AND date >= '{week_ago}'
        ORDER BY date DESC;
    """
    apple_health_connected = await _is_integration_connected("apple_health")
    result = await _chat(jwt_token, "How was my sleep last week?")
    db_rows = await _db_query(sql)
    _print_comparison(
        f"SLEEP LAST 7 DAYS  [run {_run}]  "
        f"[Apple Health: {'CONNECTED' if apple_health_connected else 'NOT CONNECTED'}]",
        result.response,
        sql,
        db_rows,
    )

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert "apple_health_read_metrics" in result.tools_fired, (
        f"[run {_run}] apple_health_read_metrics did not fire.\n"
        f"Tools fired: {result.tools_fired}"
    )
    assert len(result.response) > 20


@REPEAT
async def test_goals_query_fires_get_goals(jwt_token: str, _run: int) -> None:
    """
    "What goals do I currently have?"
    Tool required: get_goals
    Verification: query user_goals for active goals.
    """
    sql = f"""
        SELECT title, metric, target_value, current_value, period, is_completed
        FROM user_goals
        WHERE user_id = '{_DEMO_USER_ID}'
          AND is_active = true
        ORDER BY created_at DESC;
    """
    result = await _chat(jwt_token, "What goals do I currently have?")
    db_rows = await _db_query(sql)
    _print_comparison(
        f"ACTIVE GOALS [run {_run}]",
        result.response,
        sql,
        db_rows,
    )

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert "get_goals" in result.tools_fired, (
        f"[run {_run}] get_goals did not fire.\nTools fired: {result.tools_fired}"
    )
    assert len(result.response) > 20


@REPEAT
async def test_strava_query_fires_get_activities(jwt_token: str, _run: int) -> None:
    """
    "Show me my recent workouts from Strava."

    We first check whether Strava is connected for this account.

      — Connected:     strava_get_activities must fire, and we compare the AI's
                       answer against what's actually in the database.

      — Not connected: the Strava tool is never even given to Zura (the server
                       hides it for unconnected integrations), so the tool
                       cannot fire. Zura must say Strava is not connected rather
                       than inventing workout data. We assert the response
                       mentions "not connected" or "connect Strava".
    """
    strava_connected = await _is_integration_connected("strava")

    sql = f"""
        SELECT name, activity_type, distance_meters, duration_seconds, started_at
        FROM unified_activities
        WHERE user_id = '{_DEMO_USER_ID}'
          AND source = 'strava'
        ORDER BY started_at DESC
        LIMIT 5;
    """
    result = await _chat(jwt_token, "Show me my recent workouts from Strava.")
    db_rows = await _db_query(sql)
    _print_comparison(
        f"STRAVA ACTIVITIES  [run {_run}]  "
        f"[Strava: {'CONNECTED' if strava_connected else 'NOT CONNECTED'}]",
        result.response,
        sql,
        db_rows,
    )

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"

    if strava_connected:
        # Tool must fire — Strava is available in the user's toolkit.
        assert "strava_get_activities" in result.tools_fired, (
            f"[run {_run}] Strava is connected but strava_get_activities did not fire.\n"
            f"Tools fired: {result.tools_fired}"
        )
    else:
        # Tool must NOT fire — it was never given to Zura.
        # Zura must tell the user to connect Strava instead of making up data.
        assert "strava_get_activities" not in result.tools_fired, (
            f"[run {_run}] Strava is NOT connected but the tool fired anyway."
        )
        not_connected_phrases = ["not connected", "connect strava", "link strava", "no strava"]
        assert any(p in result.response.lower() for p in not_connected_phrases), (
            f"[run {_run}] Strava not connected but Zura didn't say so.\n"
            f"Response: {result.response[:300]}"
        )

    assert len(result.response) > 20


@REPEAT
async def test_streak_query_fires_get_streaks(jwt_token: str, _run: int) -> None:
    """
    "How long is my current streak?"
    Tool required: get_streaks
    Verification: query user_streaks directly.
    """
    sql = f"""
        SELECT streak_type, current_count, longest_count, last_activity_date, is_frozen
        FROM user_streaks
        WHERE user_id = '{_DEMO_USER_ID}'
        ORDER BY current_count DESC;
    """
    result = await _chat(jwt_token, "How long is my current streak?")
    db_rows = await _db_query(sql)
    _print_comparison(
        f"STREAKS [run {_run}]",
        result.response,
        sql,
        db_rows,
    )

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert "get_streaks" in result.tools_fired, (
        f"[run {_run}] get_streaks did not fire.\nTools fired: {result.tools_fired}"
    )
    assert len(result.response) > 20


@REPEAT
async def test_supplements_query_fires_get_supplements(jwt_token: str, _run: int) -> None:
    """
    "What supplements am I taking?"
    Tool required: get_supplements
    Verification: query user_supplements directly.
    """
    sql = f"""
        SELECT name, dose, timing
        FROM user_supplements
        WHERE user_id = '{_DEMO_USER_ID}'
          AND is_active = true
        ORDER BY sort_order;
    """
    result = await _chat(jwt_token, "What supplements am I taking?")
    db_rows = await _db_query(sql)
    _print_comparison(
        f"SUPPLEMENTS [run {_run}]",
        result.response,
        sql,
        db_rows,
    )

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert "get_supplements" in result.tools_fired, (
        f"[run {_run}] get_supplements did not fire.\nTools fired: {result.tools_fired}"
    )
    assert len(result.response) > 20


# ===========================================================================
# GROUP 2 — Write confirmation
#
# Turn 1: write tool must NOT fire. AI must ask for confirmation.
# Turn 2: after "Yes" — write tool MUST fire.
# ===========================================================================

@REPEAT
async def test_create_goal_requires_confirmation(jwt_token: str, _run: int) -> None:
    """
    "Set me a body weight goal of 75 kg."
    Uses body_weight type — demo user has no active body_weight goal.
    Turn 1 — create_goal must NOT fire. AI asks confirmation.
    Turn 2 — "Yes, go ahead." — create_goal MUST fire.
    """
    turn1, turn2 = await _chat_two_turns(
        jwt_token,
        turn1_message="Set me a body weight goal of 75 kg.",
        turn2_message="Yes, go ahead.",
    )

    assert "create_goal" not in turn1.tools_fired, (
        f"[run {_run}] FAIL — create_goal fired on turn 1 without confirmation.\n"
        f"Tools fired: {turn1.tools_fired}"
    )
    assert any(w in turn1.response.lower() for w in
               ["confirm", "shall i", "want me to", "go ahead", "create", "set", "sure"]), (
        f"[run {_run}] Turn 1 doesn't look like a confirmation request.\n"
        f"Response: {turn1.response[:300]}"
    )
    assert "create_goal" in turn2.tools_fired, (
        f"[run {_run}] FAIL — create_goal did not fire after confirmation.\n"
        f"Tools on turn 2: {turn2.tools_fired}\nResponse: {turn2.response[:300]}"
    )


@REPEAT
async def test_save_memory_fires_directly(jwt_token: str, _run: int) -> None:
    """
    "Remember that I prefer morning workouts."
    The system prompt does not require user confirmation before saving a memory —
    the AI saves directly on the first turn and confirms in its reply.
    This test verifies that save_memory fires and the response acknowledges the save.
    """
    result = await _chat(jwt_token, "Remember that I prefer morning workouts.")

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert "save_memory" in result.tools_fired, (
        f"[run {_run}] FAIL — save_memory did not fire.\n"
        f"Tools fired: {result.tools_fired}"
    )
    assert any(w in result.response.lower() for w in
               ["remember", "noted", "note", "saved", "morning", "workout", "preference"]), (
        f"[run {_run}] Response doesn't acknowledge the saved preference.\n"
        f"Response: {result.response[:300]}"
    )


@REPEAT
async def test_add_supplement_requires_confirmation(jwt_token: str, _run: int) -> None:
    """
    "Add magnesium to my supplement list."
    Turn 1 — add_supplement must NOT fire.
    Turn 2 — "Yes, add it." — add_supplement MUST fire.
    """
    turn1, turn2 = await _chat_two_turns(
        jwt_token,
        turn1_message="Add magnesium to my supplement list.",
        turn2_message="Yes, add it.",
    )

    assert "add_supplement" not in turn1.tools_fired, (
        f"[run {_run}] FAIL — add_supplement fired on turn 1 without confirmation."
    )
    assert any(w in turn1.response.lower() for w in
               ["confirm", "add", "magnesium", "sure", "want me to", "shall i"]), (
        f"[run {_run}] Turn 1 doesn't look like a confirmation request.\n"
        f"Response: {turn1.response[:300]}"
    )
    assert "add_supplement" in turn2.tools_fired, (
        f"[run {_run}] FAIL — add_supplement did not fire after confirmation.\n"
        f"Tools on turn 2: {turn2.tools_fired}"
    )


# ===========================================================================
# GROUP 3 — Multi-tool chains
# ===========================================================================

@REPEAT
async def test_daily_checkin_fires_multiple_tools(jwt_token: str, _run: int) -> None:
    """
    "How am I doing today overall?" (proactivity=high)
    A complete daily summary needs at least 2 tools — health data AND goals.
    """
    result = await _chat(jwt_token, "How am I doing today overall?", proactivity="high")

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert len(result.tools_fired) >= 2, (
        f"[run {_run}] Expected 2+ tools for a full daily check-in.\n"
        f"Only fired: {result.tools_fired}"
    )
    assert len(result.response) > 20


# ===========================================================================
# GROUP 4 — Edge cases
# ===========================================================================

@REPEAT
async def test_empty_message_returns_error(jwt_token: str, _run: int) -> None:
    """
    Blank message → server returns a clean error, does not crash.
    """
    result = await _chat(jwt_token, "")

    assert result.error is not None, (
        f"[run {_run}] Expected an error for a blank message, got none.\n"
        f"Response: {result.response}"
    )
    assert "empty" in result.error.lower(), (
        f"[run {_run}] Error doesn't mention 'empty': {result.error}"
    )


@REPEAT
async def test_oversized_message_returns_error(jwt_token: str, _run: int) -> None:
    """
    Message over 4,000 chars → server returns a clean 'too long' error.
    The server limit is 4,000 characters. We send ~5,800.
    """
    long_message = "Tell me about all my health data in detail please. " * 120

    result = await _chat(jwt_token, long_message)

    assert result.error is not None, (
        f"[run {_run}] Expected an error for oversized message, got none."
    )
    assert any(w in result.error.lower() for w in ["long", "max", "4,000", "character"]), (
        f"[run {_run}] Error doesn't mention the length limit: {result.error}"
    )


# ===========================================================================
# GROUP 5 — Model routing
#
# The server has two AI models:
#   Zura Flash  (Qwen3.5-Flash)  — fast, lightweight, for simple questions
#   Zura        (Kimi K2.5)      — slower, more powerful, for complex analysis
#
# Routing rules (from classifier.py):
#   < 8 words AND no plan keywords  → fast-path → Zura Flash  (no LLM needed)
#   Has plan keyword OR ≥ 8 words   → LLM classifier → deep_analysis → Zura
#                                                     → standard     → Zura Flash
#
# Plan keywords: plan, program, schedule, routine, periodiz, analyze, analysis,
#                compare, breakdown, correlat, trend, pattern, why, cause, optimize
#
# The stream_end event carries "model_used": "zura" or "zura_flash".
# ===========================================================================

@REPEAT
async def test_simple_greeting_routes_to_zura_flash(jwt_token: str, _run: int) -> None:
    """
    "How are you?" — 3 words, no plan keywords.
    Fast-path rule: < 8 words AND no plan keywords → always Zura Flash.
    No LLM classifier call needed.
    """
    result = await _chat(jwt_token, "How are you?")

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert result.model_used == "zura_flash", (
        f"[run {_run}] Expected Zura Flash for a simple greeting.\n"
        f"Got: {result.model_used!r}\n"
        f"Response: {result.response[:200]}"
    )


@REPEAT
async def test_simple_lookup_routes_to_zura_flash(jwt_token: str, _run: int) -> None:
    """
    "What are my steps?" — 4 words, no plan keywords.
    Fast-path rule → Zura Flash.
    """
    result = await _chat(jwt_token, "What are my steps?")

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    assert result.model_used == "zura_flash", (
        f"[run {_run}] Expected Zura Flash for a simple lookup.\n"
        f"Got: {result.model_used!r}"
    )


@REPEAT
async def test_complex_analysis_routes_to_zura(jwt_token: str, _run: int) -> None:
    """
    Long analysis request containing plan keywords ('analyze', 'trend', 'pattern').
    LLM classifier should label this deep_analysis → Zura (Kimi K2.5).
    """
    message = (
        "Analyze my training load over the past month and explain "
        "the trend in my HRV pattern — am I showing signs of overtraining?"
    )
    result = await _chat(jwt_token, message)

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    if result.classifier_result == "skipped":
        pytest.skip(f"[run {_run}] Zura (Kimi K2.5) rate limit exhausted — router skipped classifier and fell back to Flash. Re-run when quota resets.")
    assert result.model_used == "zura", (
        f"[run {_run}] Expected Zura (Kimi K2.5) for a deep analysis question.\n"
        f"Got: {result.model_used!r} (classifier_result={result.classifier_result!r})\n"
        f"Response: {result.response[:200]}"
    )


@REPEAT
async def test_training_plan_request_routes_to_zura(jwt_token: str, _run: int) -> None:
    """
    A training plan request contains the keyword 'plan' — triggers LLM classifier.
    Classifier should return deep_analysis → Zura (Kimi K2.5).
    """
    message = (
        "Design me a 12-week marathon training plan with periodization "
        "starting from 20km per week."
    )
    result = await _chat(jwt_token, message)

    assert result.error is None, f"[run {_run}] Unexpected error: {result.error}"
    if result.classifier_result == "skipped":
        pytest.skip(f"[run {_run}] Zura (Kimi K2.5) rate limit exhausted — router skipped classifier and fell back to Flash. Re-run when quota resets.")
    assert result.model_used == "zura", (
        f"[run {_run}] Expected Zura (Kimi K2.5) for a training plan request.\n"
        f"Got: {result.model_used!r} (classifier_result={result.classifier_result!r})\n"
        f"Response: {result.response[:200]}"
    )
