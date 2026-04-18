"""add usage_logs table

Revision ID: c8d60f5c8771
Revises: 191778be138d
Create Date: 2026-02-22 18:00:35.791065

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c8d60f5c8771'
down_revision: Union[str, Sequence[str], None] = '191778be138d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema. All operations use IF NOT EXISTS for idempotency."""
    op.execute("""
        CREATE TABLE IF NOT EXISTS nutrition_entries (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            source VARCHAR NOT NULL,
            date VARCHAR NOT NULL,
            calories INTEGER NOT NULL,
            protein_grams FLOAT,
            carbs_grams FLOAT,
            fat_grams FLOAT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            CONSTRAINT uq_nutrition_user_source_date UNIQUE (user_id, source, date)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_nutrition_entries_user_id ON nutrition_entries (user_id)")

    op.execute("""
        CREATE TABLE IF NOT EXISTS sleep_records (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            source VARCHAR NOT NULL,
            date VARCHAR NOT NULL,
            hours FLOAT NOT NULL,
            quality_score INTEGER,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            CONSTRAINT uq_sleep_user_source_date UNIQUE (user_id, source, date)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_sleep_records_user_id ON sleep_records (user_id)")

    op.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activitytype') THEN
                CREATE TYPE activitytype AS ENUM ('RUN', 'CYCLE', 'WALK', 'SWIM', 'STRENGTH', 'UNKNOWN');
            END IF;
        END $$;
    """)
    op.execute("""
        CREATE TABLE IF NOT EXISTS unified_activities (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            source VARCHAR NOT NULL,
            original_id VARCHAR NOT NULL,
            activity_type activitytype NOT NULL,
            duration_seconds INTEGER NOT NULL,
            distance_meters FLOAT,
            calories INTEGER NOT NULL,
            start_time TIMESTAMPTZ NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            CONSTRAINT uq_activity_source_original UNIQUE (source, original_id)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_unified_activities_user_id ON unified_activities (user_id)")

    op.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'goalperiod') THEN
                CREATE TYPE goalperiod AS ENUM ('DAILY', 'WEEKLY', 'LONG_TERM');
            END IF;
        END $$;
    """)
    op.execute("""
        CREATE TABLE IF NOT EXISTS user_goals (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            metric VARCHAR NOT NULL,
            target_value FLOAT NOT NULL,
            period goalperiod NOT NULL,
            is_active BOOLEAN NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            CONSTRAINT uq_user_goal_user_metric UNIQUE (user_id, metric)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_user_goals_user_id ON user_goals (user_id)")

    op.execute("""
        CREATE TABLE IF NOT EXISTS weight_measurements (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            source VARCHAR NOT NULL,
            date VARCHAR NOT NULL,
            weight_kg FLOAT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            CONSTRAINT uq_weight_user_source_date UNIQUE (user_id, source, date)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_weight_measurements_user_id ON weight_measurements (user_id)")

    op.execute("""
        CREATE TABLE IF NOT EXISTS conversations (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            title VARCHAR,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at TIMESTAMPTZ,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_conversations_user_id ON conversations (user_id)")

    op.execute("""
        CREATE TABLE IF NOT EXISTS user_devices (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            fcm_token VARCHAR NOT NULL UNIQUE,
            platform VARCHAR NOT NULL,
            last_seen_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_user_devices_user_id ON user_devices (user_id)")

    op.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id VARCHAR NOT NULL PRIMARY KEY,
            conversation_id VARCHAR NOT NULL,
            role VARCHAR NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_messages_conv_created ON messages (conversation_id, created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_messages_conversation_id ON messages (conversation_id)")

    op.execute("ALTER TABLE integrations ADD COLUMN IF NOT EXISTS sync_status VARCHAR NOT NULL DEFAULT ''")
    op.execute("ALTER TABLE integrations ADD COLUMN IF NOT EXISTS sync_error VARCHAR")


def downgrade() -> None:
    """Downgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('integrations', 'sync_error')
    op.drop_column('integrations', 'sync_status')
    op.drop_index(op.f('ix_messages_conversation_id'), table_name='messages')
    op.drop_index('ix_messages_conv_created', table_name='messages')
    op.drop_table('messages')
    op.drop_index(op.f('ix_user_devices_user_id'), table_name='user_devices')
    op.drop_table('user_devices')
    op.drop_index(op.f('ix_conversations_user_id'), table_name='conversations')
    op.drop_table('conversations')
    op.drop_index(op.f('ix_weight_measurements_user_id'), table_name='weight_measurements')
    op.drop_table('weight_measurements')
    op.drop_index(op.f('ix_user_goals_user_id'), table_name='user_goals')
    op.drop_table('user_goals')
    op.drop_index(op.f('ix_unified_activities_user_id'), table_name='unified_activities')
    op.drop_table('unified_activities')
    op.drop_index(op.f('ix_sleep_records_user_id'), table_name='sleep_records')
    op.drop_table('sleep_records')
    op.drop_index(op.f('ix_nutrition_entries_user_id'), table_name='nutrition_entries')
    op.drop_table('nutrition_entries')
    # ### end Alembic commands ###
