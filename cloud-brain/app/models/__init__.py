"""
Zuralog Cloud Brain — ORM Models Package.

Re-exports Base and all model classes for convenient imports.
Alembic's env.py imports from here to discover all models.
"""

from app.database import Base
from app.models.achievement import Achievement  # noqa: F401
from app.models.activity_session import ActivitySession  # noqa: F401
from app.models.blood_pressure import BloodPressureRecord  # noqa: F401
from app.models.conversation import Conversation, Message  # noqa: F401
from app.models.daily_metrics import DailyHealthMetrics  # noqa: F401
from app.models.daily_summary import DailySummary  # noqa: F401
from app.models.emergency_card import EmergencyCard  # noqa: F401
from app.models.health_event import HealthEvent  # noqa: F401
from app.models.health_data import (  # noqa: F401
    ActivityType,
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.insight import Insight, INSIGHT_TYPES  # noqa: F401
from app.models.metric_definition import MetricDefinition  # noqa: F401
from app.models.integration import Integration  # noqa: F401
from app.models.journal_entry import JournalEntry  # noqa: F401
from app.models.notification_log import NotificationLog, NOTIFICATION_TYPES  # noqa: F401
from app.models.quick_log import QuickLog, VALID_METRIC_TYPES  # noqa: F401
from app.models.report import Report, ReportType  # noqa: F401
from app.models.user import SubscriptionTier, User  # noqa: F401
from app.models.user_device import UserDevice  # noqa: F401
from app.models.user_goal import GoalPeriod, UserGoal  # noqa: F401
from app.models.user_preferences import (  # noqa: F401
    AppTheme,
    CoachPersona,
    ProactivityLevel,
    UserPreferences,
)
from app.models.user_streak import UserStreak  # noqa: F401

__all__ = [
    "INSIGHT_TYPES",
    "NOTIFICATION_TYPES",
    "VALID_METRIC_TYPES",
    "Achievement",
    "ActivitySession",
    "ActivityType",
    "AppTheme",
    "Base",
    "BloodPressureRecord",
    "CoachPersona",
    "Conversation",
    "DailyHealthMetrics",
    "DailySummary",
    "EmergencyCard",
    "GoalPeriod",
    "HealthEvent",
    "Insight",
    "Integration",
    "JournalEntry",
    "Message",
    "MetricDefinition",
    "NotificationLog",
    "NutritionEntry",
    "ProactivityLevel",
    "QuickLog",
    "Report",
    "ReportType",
    "SleepRecord",
    "SubscriptionTier",
    "UnifiedActivity",
    "User",
    "UserDevice",
    "UserGoal",
    "UserPreferences",
    "UserStreak",
    "WeightMeasurement",
]
