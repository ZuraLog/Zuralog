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
    op.create_foreign_key("fk_unified_activities_user_id", "unified_activities", "users", ["user_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("fk_sleep_records_user_id", "sleep_records", "users", ["user_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("fk_nutrition_entries_user_id", "nutrition_entries", "users", ["user_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("fk_weight_measurements_user_id", "weight_measurements", "users", ["user_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("fk_daily_health_metrics_user_id", "daily_health_metrics", "users", ["user_id"], ["id"], ondelete="CASCADE")


def downgrade() -> None:
    op.drop_constraint("fk_unified_activities_user_id", "unified_activities", type_="foreignkey")
    op.drop_constraint("fk_sleep_records_user_id", "sleep_records", type_="foreignkey")
    op.drop_constraint("fk_nutrition_entries_user_id", "nutrition_entries", type_="foreignkey")
    op.drop_constraint("fk_weight_measurements_user_id", "weight_measurements", type_="foreignkey")
    op.drop_constraint("fk_daily_health_metrics_user_id", "daily_health_metrics", type_="foreignkey")
