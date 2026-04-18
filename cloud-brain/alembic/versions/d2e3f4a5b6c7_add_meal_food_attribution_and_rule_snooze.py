"""add meal food attribution and rule snooze

Phase 6 Plan 4: Rule Suggestions.

- Adds nullable attribution columns to meal_foods so the rule-suggestion
  detector can mine (question_id, answer_value) pairs across a user's
  recent meals.
- Creates a partial composite index on those columns — only tagged rows
  participate, keeping the index small on the hot meal_foods table.
- Creates rule_suggestion_snooze to track per-user dismissals with a
  decrementing occurrence counter.

Revision ID: d2e3f4a5b6c7
Revises: c1d1e1f1g1h1
Create Date: 2026-04-17
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d2e3f4a5b6c7"
down_revision: Union[str, Sequence[str], None] = "c1d1e1f1g1h1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 1. Add attribution columns to meal_foods (all nullable — no backfill)
    # ------------------------------------------------------------------
    op.add_column(
        "meal_foods",
        sa.Column("origin", sa.String(20), nullable=True),
    )
    op.add_column(
        "meal_foods",
        sa.Column("source_question_id", sa.String(20), nullable=True),
    )
    op.add_column(
        "meal_foods",
        sa.Column("source_answer_value", sa.String(50), nullable=True),
    )

    # ------------------------------------------------------------------
    # 2. Partial composite index — only rows tagged by the walkthrough
    # ------------------------------------------------------------------
    op.create_index(
        "ix_meal_foods_attribution",
        "meal_foods",
        ["source_question_id", "source_answer_value", "meal_id"],
        postgresql_where=sa.text("source_question_id IS NOT NULL"),
    )

    # ------------------------------------------------------------------
    # 3. rule_suggestion_snooze — per-user snooze state with a counter
    # ------------------------------------------------------------------
    op.create_table(
        "rule_suggestion_snooze",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("question_id", sa.String(20), nullable=False),
        sa.Column("answer_value", sa.String(50), nullable=False),
        sa.Column(
            "occurrences_remaining",
            sa.Integer(),
            server_default=sa.text("10"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id",
            "question_id",
            "answer_value",
            name="uq_rule_suggestion_snooze_user_question_answer",
        ),
    )


def downgrade() -> None:
    # Drop table first, then index, then columns — reverse of upgrade order.
    op.drop_table("rule_suggestion_snooze")
    op.drop_index("ix_meal_foods_attribution", table_name="meal_foods")
    op.drop_column("meal_foods", "source_answer_value")
    op.drop_column("meal_foods", "source_question_id")
    op.drop_column("meal_foods", "origin")
