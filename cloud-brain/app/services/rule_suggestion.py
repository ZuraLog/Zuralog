"""Rule-suggestion detection service.

Mines a user's tagged meal_foods for repeated
``(source_question_id, source_answer_value)`` combinations. When the
same pair appears three or more times in the last 60 days — and no
existing rule already covers it, and no active snooze blocks it — we
surface it as a :class:`SuggestedRule` on the next parse/refine/scan
response.

Security model:
    * The text returned to the client is composed server-side from a
      hand-written template map. LLM output never lands in the rule
      string.
    * Everything is clamped to 200 chars and stripped of newlines before
      leaving this module.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.nutrition_schemas import SuggestedRule
from app.models.meal import Meal
from app.models.meal_food import MealFood
from app.models.nutrition_rule import NutritionRule
from app.models.rule_suggestion_snooze import RuleSuggestionSnooze

# Window the detector scans. Meals older than this never count.
_DETECTION_WINDOW_DAYS = 60

# Minimum number of times the same (question_id, answer_value) pair must
# appear in the window before we surface a suggestion.
_MIN_OCCURRENCES = 3

# How many top pairs to inspect per detection call. Bounded to keep the
# detection path cheap on the parse hot path.
_MAX_CANDIDATES = 5


# Hand-written templates keyed on (question_id, answer_value). When the
# parse prompt starts emitting a new question id, add an entry here so
# the suggestion reads naturally. Unknown pairs fall back to a generic
# sentence — the suggestion still works, just with less polish.
_RULE_TEMPLATES: dict[tuple[str, str], str] = {}


def _build_rule_text(question_id: str, answer_value: str) -> str:
    """Compose the human-facing rule text for a ``(qid, answer)`` pair.

    Looks up a hand-written template first and falls back to a generic
    sentence when the pair is unknown. The result is stripped of
    newlines and clamped to 200 characters so it is always safe to echo
    straight into the API response.
    """

    text = _RULE_TEMPLATES.get((question_id, answer_value))
    if text is None:
        text = f'I always answer "{answer_value}" for this question'
    text = text.replace("\n", " ").replace("\r", " ").strip()
    return text[:200]


async def detect_suggested_rule(
    db: AsyncSession, user_id: str
) -> SuggestedRule | None:
    """Return the best rule suggestion for this user, or ``None``.

    One aggregate query counts tagged ``(source_question_id,
    source_answer_value)`` pairs across the user's non-deleted meals in
    the detection window. The top candidates (highest count first) are
    then filtered: any pair already covered by an existing rule is
    skipped, and any pair with an active snooze row is skipped. The
    first survivor wins.
    """

    cutoff = datetime.now(timezone.utc) - timedelta(days=_DETECTION_WINDOW_DAYS)

    stmt = (
        select(
            MealFood.source_question_id,
            MealFood.source_answer_value,
            func.count().label("n"),
        )
        .select_from(MealFood)
        .join(Meal, Meal.id == MealFood.meal_id)
        .where(
            and_(
                Meal.user_id == user_id,
                Meal.deleted_at.is_(None),
                Meal.logged_at >= cutoff,
                MealFood.source_question_id.is_not(None),
                MealFood.source_answer_value.is_not(None),
            )
        )
        .group_by(MealFood.source_question_id, MealFood.source_answer_value)
        .having(func.count() >= _MIN_OCCURRENCES)
        .order_by(func.count().desc())
        .limit(_MAX_CANDIDATES)
    )
    result = await db.execute(stmt)
    candidates = result.all()
    if not candidates:
        return None

    # Preload rules once; list is bounded to MAX_RULES_PER_USER (20).
    rules_result = await db.execute(
        select(NutritionRule.rule_text).where(NutritionRule.user_id == user_id)
    )
    existing_rule_texts_lower = [
        (r or "").lower() for r in rules_result.scalars().all()
    ]

    for qid, aval, _count in candidates:
        if not qid or not aval:
            continue

        qid_lower = qid.lower()
        aval_lower = aval.lower()

        # Existing-rule filter — case-insensitive substring on both
        # tokens. Advisory only; better to skip a real match than to
        # double-bug a user with a duplicate rule prompt.
        conflicts = any(
            qid_lower in text and aval_lower in text
            for text in existing_rule_texts_lower
        )
        if conflicts:
            continue

        # Active-snooze filter.
        snooze_result = await db.execute(
            select(RuleSuggestionSnooze.id).where(
                and_(
                    RuleSuggestionSnooze.user_id == user_id,
                    RuleSuggestionSnooze.question_id == qid,
                    RuleSuggestionSnooze.answer_value == aval,
                    RuleSuggestionSnooze.occurrences_remaining > 0,
                )
            )
        )
        if snooze_result.scalar_one_or_none() is not None:
            continue

        return SuggestedRule(
            rule_text=_build_rule_text(qid, aval),
            question_id=qid,
            answer_value=aval,
        )

    return None
