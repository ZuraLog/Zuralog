"""add missing preference columns to user_preferences

Revision ID: l7g8h9i0j1k2
Revises: k6f7a8b9c0d1
Create Date: 2026-03-08

Adds 6 new columns to user_preferences that the Flutter client already
sends and expects. These were missing from the backend model.

  Coach:
    - response_length: VARCHAR NOT NULL DEFAULT 'concise'
    - suggested_prompts_enabled: BOOLEAN NOT NULL DEFAULT true
    - voice_input_enabled: BOOLEAN NOT NULL DEFAULT true

  Privacy & Visibility:
    - wellness_checkin_card_visible: BOOLEAN NOT NULL DEFAULT true
    - data_maturity_banner_dismissed: BOOLEAN NOT NULL DEFAULT false
    - analytics_opt_out: BOOLEAN NOT NULL DEFAULT false

Also adds a CHECK constraint on response_length enforcing the
'concise' | 'detailed' domain.
"""

from alembic import op


revision = "l7g8h9i0j1k2"
down_revision = "k6f7a8b9c0d1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ADD COLUMN with a constant DEFAULT is metadata-only on PostgreSQL 11+.
    # No table rewrite, no lock escalation.
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS "
        "response_length VARCHAR NOT NULL DEFAULT 'concise'"
    )
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS "
        "suggested_prompts_enabled BOOLEAN NOT NULL DEFAULT true"
    )
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS "
        "voice_input_enabled BOOLEAN NOT NULL DEFAULT true"
    )
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS "
        "wellness_checkin_card_visible BOOLEAN NOT NULL DEFAULT true"
    )
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS "
        "data_maturity_banner_dismissed BOOLEAN NOT NULL DEFAULT false"
    )
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS "
        "analytics_opt_out BOOLEAN NOT NULL DEFAULT false"
    )
    # CHECK constraint on response_length (defense-in-depth).
    # NOT VALID avoids ACCESS EXCLUSIVE lock; VALIDATE acquires only
    # SHARE UPDATE EXCLUSIVE (does not block reads/writes).
    op.execute(
        "ALTER TABLE user_preferences ADD CONSTRAINT "
        "ck_user_preferences_response_length "
        "CHECK (response_length IN ('concise', 'detailed')) "
        "NOT VALID"
    )
    op.execute(
        "ALTER TABLE user_preferences VALIDATE CONSTRAINT "
        "ck_user_preferences_response_length"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE user_preferences DROP CONSTRAINT "
        "IF EXISTS ck_user_preferences_response_length"
    )
    op.drop_column("user_preferences", "analytics_opt_out")
    op.drop_column("user_preferences", "data_maturity_banner_dismissed")
    op.drop_column("user_preferences", "wellness_checkin_card_visible")
    op.drop_column("user_preferences", "voice_input_enabled")
    op.drop_column("user_preferences", "suggested_prompts_enabled")
    op.drop_column("user_preferences", "response_length")
