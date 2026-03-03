"""
Zuralog Cloud Brain — ORM Models Package.

Re-exports Base and all model classes for convenient imports.
Alembic's env.py imports from here to discover all models.
"""

from app.database import Base
from app.models.blood_pressure import BloodPressureRecord  # noqa: F401
from app.models.conversation import Conversation, Message
from app.models.daily_metrics import DailyHealthMetrics  # noqa: F401
from app.models.health_data import (
    ActivityType,
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.integration import Integration
from app.models.user import SubscriptionTier, User
from app.models.user_device import UserDevice
from app.models.user_goal import GoalPeriod, UserGoal
from app.models.user_preferences import (  # noqa: F401
    AppTheme,
    CoachPersona,
    ProactivityLevel,
    UserPreferences,
)

__all__ = [
    "ActivityType",
    "AppTheme",
    "Base",
    "BloodPressureRecord",
    "CoachPersona",
    "Conversation",
    "DailyHealthMetrics",
    "GoalPeriod",
    "Integration",
    "Message",
    "NutritionEntry",
    "ProactivityLevel",
    "SleepRecord",
    "SubscriptionTier",
    "UnifiedActivity",
    "User",
    "UserDevice",
    "UserGoal",
    "UserPreferences",
    "WeightMeasurement",
]
