"""
Life Logger Cloud Brain — ORM Models Package.

Re-exports Base and all model classes for convenient imports.
Alembic's env.py imports from here to discover all models.
"""

from app.database import Base
from app.models.conversation import Conversation, Message
from app.models.health_data import (
    ActivityType,
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.integration import Integration
from app.models.user import User
from app.models.user_device import UserDevice
from app.models.user_goal import GoalPeriod, UserGoal

__all__ = [
    "ActivityType",
    "Base",
    "Conversation",
    "GoalPeriod",
    "Integration",
    "Message",
    "NutritionEntry",
    "SleepRecord",
    "UnifiedActivity",
    "User",
    "UserDevice",
    "UserGoal",
    "WeightMeasurement",
]
