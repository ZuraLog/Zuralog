"""Test that DailySummary has the query-optimized composite index."""
from app.models.daily_summary import DailySummary


def test_daily_summary_has_query_optimized_index() -> None:
    index_names = {idx.name for idx in DailySummary.__table__.indexes}
    assert "ix_daily_summaries_user_metric_date" in index_names, (
        f"Expected index 'ix_daily_summaries_user_metric_date' not found. "
        f"Existing indexes: {index_names}"
    )
