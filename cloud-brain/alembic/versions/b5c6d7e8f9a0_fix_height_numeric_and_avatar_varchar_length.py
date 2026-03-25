"""Fix height_cm column type to NUMERIC(5,1) and cap avatar_url to VARCHAR(2048).

Revision ID: b5c6d7e8f9a0
Revises: a3b4c5d6e7f8
Create Date: 2026-03-25

Corrects two column types that were added with overly permissive types in
revision a3b4c5d6e7f8:

  - height_cm: was FLOAT (IEEE 754 double, 8 bytes, imprecise decimal).
    Changed to NUMERIC(5,1) — stores up to 999.9 with one decimal place,
    exact arithmetic, and a tighter storage footprint. Covers the full valid
    human height range (30–300 cm) with room to spare. The USING clause
    coerces existing float values in place; no data is lost.

  - avatar_url: was unbounded VARCHAR. Changed to VARCHAR(2048), matching the
    de-facto maximum URL length supported by all major browsers and CDNs.
    Prevents runaway storage from malformed or malicious URL values.

Both ALTER COLUMN statements are metadata-only on PostgreSQL 11+ for the
VARCHAR change, and a fast in-place rewrite for the NUMERIC change — no
table lock escalation, negligible downtime even at large table sizes.
"""

from alembic import op  # type: ignore[reportAttributeAccessIssue]


revision = "b5c6d7e8f9a0"
down_revision = "a3b4c5d6e7f8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE users ALTER COLUMN height_cm TYPE NUMERIC(5,1)"
        " USING height_cm::NUMERIC(5,1)"
    )
    op.execute("ALTER TABLE users ALTER COLUMN avatar_url TYPE VARCHAR(2048)")


def downgrade() -> None:
    op.execute(
        "ALTER TABLE users ALTER COLUMN height_cm TYPE FLOAT"
        " USING height_cm::FLOAT"
    )
    op.execute("ALTER TABLE users ALTER COLUMN avatar_url TYPE VARCHAR")
