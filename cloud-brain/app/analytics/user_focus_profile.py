"""User Focus Profile builder for the AI Insights Engine.

Maps a user's stated goals and dashboard layout card keys to an inferred
focus label and an ordered list of priority metrics. The InsightSignalDetector
(Chunk 4) uses this profile to boost severity scores for metrics the user
actually cares about.
"""

from dataclasses import dataclass, field


# ---------------------------------------------------------------------------
# Dataclass
# ---------------------------------------------------------------------------


@dataclass
class UserFocusProfile:
    """Inferred focus and priority metrics for a single user.

    Attributes:
        stated_goals: Goal slugs the user selected during onboarding
            (e.g. ``["weight_loss", "sleep"]``).
        inferred_focus: The dominant focus label derived from goals and
            dashboard layout.
        focus_metrics: Ordered list of metric keys the user cares most about.
        deprioritised_metrics: Known metrics *not* in ``focus_metrics``.
        coach_persona: AI coaching style (``"tough_love"``, ``"balanced"``,
            ``"gentle"``).
        fitness_level: Self-assessed fitness level or ``None``.
        units_system: ``"metric"`` or ``"imperial"``.
    """

    stated_goals: list[str] = field(default_factory=list)
    inferred_focus: str = "general"
    focus_metrics: list[str] = field(default_factory=list)
    deprioritised_metrics: list[str] = field(default_factory=list)
    coach_persona: str = "balanced"
    fitness_level: str | None = None
    units_system: str = "metric"


# ---------------------------------------------------------------------------
# Mapping tables
# ---------------------------------------------------------------------------

# Maps a stated goal slug → (focus_label, ordered_metrics)
_GOAL_TO_FOCUS: dict[str, tuple[str, list[str]]] = {
    "weight_loss": (
        "cutting",
        ["weight_kg", "calories", "active_calories", "body_fat_percentage", "protein_grams"],
    ),
    "sleep": (
        "recovery",
        ["sleep_hours", "sleep_quality", "hrv_ms", "stress", "resting_heart_rate"],
    ),
    "fitness": (
        "performance",
        ["steps", "active_calories", "distance_meters", "vo2_max", "workout_frequency"],
    ),
    "stress": (
        "stress_management",
        ["stress", "mood", "hrv_ms", "sleep_hours", "resting_heart_rate"],
    ),
    "nutrition": (
        "nutrition",
        ["calories", "protein_grams", "carbs_grams", "fat_grams", "water_ml"],
    ),
    "longevity": (
        "longevity",
        ["hrv_ms", "resting_heart_rate", "vo2_max", "sleep_hours", "weight_kg"],
    ),
    "build_muscle": (
        "body_recomposition",
        ["weight_kg", "protein_grams", "workout_frequency", "active_calories"],
    ),
}

# Each entry: (required_card_keys, focus_label, ordered_metrics).
# Evaluated in order; first match wins.
_LAYOUT_PATTERNS: list[tuple[set[str], str, list[str]]] = [
    (
        {"protein", "calories", "weight", "workouts"},
        "body_recomposition",
        ["weight_kg", "protein_grams", "workout_frequency", "active_calories"],
    ),
    (
        {"sleep", "hrv", "stress"},
        "recovery",
        ["sleep_hours", "sleep_quality", "hrv_ms", "stress", "resting_heart_rate"],
    ),
    (
        {"sleep", "hrv", "water"},
        "sleep_optimisation",
        ["sleep_hours", "sleep_quality", "hrv_ms", "water_ml"],
    ),
    (
        {"calories", "weight"},
        "cutting",
        ["weight_kg", "calories", "active_calories", "body_fat_percentage"],
    ),
    (
        {"steps", "active_calories", "distance"},
        "activity_volume",
        ["steps", "active_calories", "distance_meters"],
    ),
    (
        {"calories", "protein", "carbs", "fat"},
        "nutrition_tracking",
        ["calories", "protein_grams", "carbs_grams", "fat_grams", "water_ml"],
    ),
]


# ---------------------------------------------------------------------------
# Builder
# ---------------------------------------------------------------------------


class UserFocusProfileBuilder:
    """Builds a :class:`UserFocusProfile` from raw preferences data.

    Parameters
    ----------
    goals:
        List of goal slugs (e.g. ``["weight_loss", "sleep"]``).
    dashboard_layout:
        The user's ``dashboard_layout`` JSON dict.  The builder inspects
        ``visible_cards`` inside it to infer focus from card presence.
    coach_persona:
        AI coaching style.
    fitness_level:
        Self-assessed fitness level or ``None``.
    units_system:
        ``"metric"`` or ``"imperial"``.
    """

    def __init__(
        self,
        goals: list[str] | None,
        dashboard_layout: dict | None,
        coach_persona: str = "balanced",
        fitness_level: str | None = None,
        units_system: str = "metric",
    ) -> None:
        self.goals = goals or []
        self.dashboard_layout = dashboard_layout or {}
        self.coach_persona = coach_persona
        self.fitness_level = fitness_level
        self.units_system = units_system

    def build(self) -> UserFocusProfile:
        """Compute and return the :class:`UserFocusProfile`."""

        # 1. Map stated goals → focus labels + metrics (preserve goal order)
        goal_focuses: list[str] = []
        goal_metrics: list[str] = []
        for goal in self.goals:
            if goal in _GOAL_TO_FOCUS:
                focus_label, metrics = _GOAL_TO_FOCUS[goal]
                goal_focuses.append(focus_label)
                for m in metrics:
                    if m not in goal_metrics:
                        goal_metrics.append(m)

        # 2. Infer focus from dashboard visible_cards (first matching pattern)
        visible_cards = set(self.dashboard_layout.get("visible_cards", []))
        layout_focus: str | None = None
        layout_metrics: list[str] = []
        for required_keys, focus_label, metrics in _LAYOUT_PATTERNS:
            if required_keys.issubset(visible_cards):
                layout_focus = focus_label
                layout_metrics = metrics
                break

        # 3. Combine: layout focus wins if it also appears in goal focuses,
        #    otherwise layout still wins (it reflects what the user *looks* at).
        if layout_focus and layout_focus in goal_focuses:
            inferred_focus = layout_focus
            focus_metrics = _merge_unique(layout_metrics, goal_metrics)
        elif layout_focus:
            inferred_focus = layout_focus
            focus_metrics = _merge_unique(layout_metrics, goal_metrics)
        elif goal_focuses:
            inferred_focus = goal_focuses[0]
            focus_metrics = goal_metrics
        else:
            inferred_focus = "general"
            focus_metrics = []

        # 4. Everything we know about but didn't prioritise
        all_known = {m for _, (_, ms) in _GOAL_TO_FOCUS.items() for m in ms}
        deprioritised = [m for m in all_known if m not in focus_metrics]

        return UserFocusProfile(
            stated_goals=self.goals,
            inferred_focus=inferred_focus,
            focus_metrics=focus_metrics,
            deprioritised_metrics=deprioritised,
            coach_persona=self.coach_persona,
            fitness_level=self.fitness_level,
            units_system=self.units_system,
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _merge_unique(primary: list[str], secondary: list[str]) -> list[str]:
    """Return *primary* with any *secondary* items appended that aren't already present."""
    result = list(primary)
    for m in secondary:
        if m not in result:
            result.append(m)
    return result
