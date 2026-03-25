"""Add FK CASCADE on health model user_id columns.

Revision ID: z1a2b3c4d5e6
Revises: y0z1a2b3c4d5
Create Date: 2026-03-25
"""
from alembic import op

revision = "z1a2b3c4d5e6"
down_revision = "ed0cb70e858b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Use raw SQL with existence checks — tables may not exist in all environments
    op.execute("""
        DO $$
        DECLARE
            t TEXT;
            c TEXT;
        BEGIN
            -- unified_activities
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'unified_activities') THEN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_unified_activities_user_id') THEN
                    ALTER TABLE unified_activities ADD CONSTRAINT fk_unified_activities_user_id
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
                END IF;
            END IF;
            -- sleep_records
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sleep_records') THEN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_sleep_records_user_id') THEN
                    ALTER TABLE sleep_records ADD CONSTRAINT fk_sleep_records_user_id
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
                END IF;
            END IF;
            -- nutrition_entries
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'nutrition_entries') THEN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_nutrition_entries_user_id') THEN
                    ALTER TABLE nutrition_entries ADD CONSTRAINT fk_nutrition_entries_user_id
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
                END IF;
            END IF;
            -- weight_measurements
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'weight_measurements') THEN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_weight_measurements_user_id') THEN
                    ALTER TABLE weight_measurements ADD CONSTRAINT fk_weight_measurements_user_id
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
                END IF;
            END IF;
            -- daily_health_metrics
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_health_metrics') THEN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_daily_health_metrics_user_id') THEN
                    ALTER TABLE daily_health_metrics ADD CONSTRAINT fk_daily_health_metrics_user_id
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
                END IF;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.drop_constraint("fk_unified_activities_user_id", "unified_activities", type_="foreignkey")
    op.drop_constraint("fk_sleep_records_user_id", "sleep_records", type_="foreignkey")
    op.drop_constraint("fk_nutrition_entries_user_id", "nutrition_entries", type_="foreignkey")
    op.drop_constraint("fk_weight_measurements_user_id", "weight_measurements", type_="foreignkey")
    op.drop_constraint("fk_daily_health_metrics_user_id", "daily_health_metrics", type_="foreignkey")
