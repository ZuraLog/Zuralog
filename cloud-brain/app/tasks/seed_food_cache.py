"""Seed the food_cache table with USDA common foods.

Can be run as:
  - Celery task: celery_app.send_task('seed_food_cache')
  - Standalone:  python -m app.tasks.seed_food_cache
"""

import asyncio
import logging
import uuid
from datetime import datetime, timezone

from celery import shared_task
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.data.usda_seed_foods import SEED_FOODS
from app.database import worker_async_session
from app.models.food_cache import FoodCache

logger = logging.getLogger(__name__)


@shared_task(name="seed_food_cache")
def seed_food_cache() -> dict:
    """Celery task entry point — seeds common foods into food_cache."""
    return asyncio.run(_seed())


async def _seed() -> dict:
    """Insert or update USDA seed foods in food_cache.

    Uses PostgreSQL's INSERT ... ON CONFLICT DO UPDATE (upsert) so the
    script is safe to run repeatedly — existing rows get refreshed,
    new ones get created.
    """
    async with worker_async_session() as db:
        inserted_or_updated = 0

        for food in SEED_FOODS:
            now = datetime.now(timezone.utc)
            values = {
                "id": uuid.uuid4(),
                "external_id": food["external_id"],
                "name": food["name"],
                "brand": None,
                "serving_size": food["serving_size"],
                "serving_unit": food["serving_unit"],
                "calories_per_serving": food["calories_per_serving"],
                "protein_per_serving": food["protein_per_serving"],
                "carbs_per_serving": food["carbs_per_serving"],
                "fat_per_serving": food["fat_per_serving"],
                "metadata_": {"source": "usda"},
                "fetched_at": now,
            }

            stmt = pg_insert(FoodCache).values(**values).on_conflict_do_update(
                index_elements=["external_id"],
                set_={
                    "name": food["name"],
                    "serving_size": food["serving_size"],
                    "serving_unit": food["serving_unit"],
                    "calories_per_serving": food["calories_per_serving"],
                    "protein_per_serving": food["protein_per_serving"],
                    "carbs_per_serving": food["carbs_per_serving"],
                    "fat_per_serving": food["fat_per_serving"],
                    "metadata": {"source": "usda"},
                    "fetched_at": now,
                },
            )
            result = await db.execute(stmt)
            if result.rowcount:
                inserted_or_updated += 1

        await db.commit()

        summary = {
            "inserted_or_updated": inserted_or_updated,
            "total_seed_foods": len(SEED_FOODS),
        }
        logger.info("Food cache seeding complete: %s", summary)
        return summary


if __name__ == "__main__":
    result = asyncio.run(_seed())
    print(f"Seeding complete: {result}")
