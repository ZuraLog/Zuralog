"""fix_unified_activity_constraint_add_user_id

Revision ID: ed0cb70e858b
Revises: y0z1a2b3c4d5
Create Date: 2026-03-25 11:07:12.236958

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ed0cb70e858b'
down_revision: Union[str, Sequence[str], None] = 'y0z1a2b3c4d5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Use raw SQL with IF EXISTS to handle cases where the table or constraint
    # may not exist (e.g. table was recreated without the old constraint).
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_name = 'unified_activities'
            ) THEN
                ALTER TABLE unified_activities
                    DROP CONSTRAINT IF EXISTS uq_activity_source_original;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conname = 'uq_activity_user_source_original'
                ) THEN
                    ALTER TABLE unified_activities
                        ADD CONSTRAINT uq_activity_user_source_original
                        UNIQUE (user_id, source, original_id);
                END IF;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.drop_constraint("uq_activity_user_source_original", "unified_activities", type_="unique")
    op.create_unique_constraint(
        "uq_activity_source_original",
        "unified_activities",
        ["source", "original_id"],
    )
