"""
Zuralog Cloud Brain — ORM Models Package.

Re-exports Base and all model classes for convenient imports.
Alembic's env.py imports from here to discover all models.
"""

from app.database import Base
from app.models.achievement import Achievement  # noqa: F401
from app.models.blood_pressure import BloodPressureRecord  # noqa: F401
from app.models.conversation import Conversation, Message
from app.models.daily_metrics import DailyHealthMetrics  # noqa: F401
from app.models.emergency_card import EmergencyCard  # noqa: F401
from app.models.health_data import (
    ActivityType,
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.insight import Insight  # noqa: F401
from app.models.integration import Integration
from app.models.journal_entry import JournalEntry  # noqa: F401
from app.models.notification_log import NotificationLog  # noqa: F401
from app.models.quick_log import QuickLog  # noqa: F401
from app.models.user import SubscriptionTier, User
from app.models.user_device import UserDevice
from app.models.user_goal import GoalPeriod, UserGoal
from app.models.user_preferences import (  # noqa: F401
    AppTheme,
    CoachPersona,
    ProactivityLevel,
    Theme,
    UnitsSystem,
    UserPreferences,
)
from app.models.achievement import ACHIEVEMENT_REGISTRY, Achievement  # noqa: F401
from app.models.user_streak import StreakType, UserStreak  # noqa: F401
from app.models.journal_entry import JournalEntry  # noqa: F401
from app.models.quick_log import MetricType, QuickLog  # noqa: F401
from app.models.emergency_card import EmergencyCard, EmergencyHealthCard  # noqa: F401
from app.models.insight import Insight, InsightType  # noqa: F401
from app.models.notification_log import NotificationLog, NotificationType  # noqa: F401
from app.models.report import Report, ReportType  # noqa: F401

__all__ = [
    "ACHIEVEMENT_REGISTRY",
    "Achievement",
    "ActivityType",
    "AppTheme",
    "Base",
    "BloodPressureRecord",
    "CoachPersona",
    "Conversation",
    "DailyHealthMetrics",
    "EmergencyCard",
    "EmergencyHealthCard",
    "GoalPeriod",
    "Insight",
    "InsightType",
    "Integration",
    "JournalEntry",
    "Message",
    "MetricType",
    "NotificationLog",
    "NotificationType",
    "NutritionEntry",
    "ProactivityLevel",
    "QuickLog",
    "Report",
    "ReportType",
    "SleepRecord",
    "StreakType",
    "SubscriptionTier",
    "Theme",
    "UnifiedActivity",
    "UnitsSystem",
    "User",
    "UserDevice",
    "UserGoal",
    "UserPreferences",
    "UserStreak",
    "WeightMeasurement",
]
