"""Migrate user_goals.metric values to canonical metric_type slugs.

Revision ID: x9y0z1a2b3c4
Revises: w8x9y0z1a2b3
Create Date: 2026-03-22

Updates existing user_goals.metric column values to match the canonical
slugs defined in metric_definitions (created in the previous migration).

Slug mapping applied:
  water    -> water_ml
  sleep    -> sleep_duration
  weight   -> weight_kg
  run      -> exercise_minutes
  meal     -> calories
  workout  -> exercise_minutes
  pain     -> stress           (closest available mapping)

Already-canonical values (steps, mood, energy, stress) are left untouched.
"""

from alembic import op


revision = "x9y0z1a2b3c4"
down_revision = "w8x9y0z1a2b3"
branch_labels = None
depends_on = None

# Mapping of old slug -> new canonical slug.
# Order does not matter because each UPDATE is independent (no two old values
# share the same target) with the exception of run/workout both mapping to
# exercise_minutes — that is intentional and safe.
SLUG_MAP = {
    "water": "water_ml",
    "sleep": "sleep_duration",
    "weight": "weight_kg",
    "run": "exercise_minutes",
    "meal": "calories",
    "workout": "exercise_minutes",
    "pain": "stress",
}

# Reverse map used for downgrade.  Where two old values shared the same new
# value (run + workout -> exercise_minutes) we cannot recover which was which,
# so the downgrade picks the first old value alphabetically ("run") as a
# best-effort restoration.
_SEEN_NEW: dict = {}
REVERSE_MAP: dict = {}
for old, new in sorted(SLUG_MAP.items()):
    if new not in _SEEN_NEW:
        _SEEN_NEW[new] = old
        REVERSE_MAP[new] = old


def upgrade() -> None:
    for old_slug, new_slug in SLUG_MAP.items():
        op.execute(
            f"UPDATE user_goals SET metric = '{new_slug}' WHERE metric = '{old_slug}'"
        )


def downgrade() -> None:
    for new_slug, old_slug in REVERSE_MAP.items():
        op.execute(
            f"UPDATE user_goals SET metric = '{old_slug}' WHERE metric = '{new_slug}'"
        )
