"""
Zuralog Cloud Brain — Signal Prioritizer.

Receives the raw InsightSignal list from InsightSignalDetector and returns
a final ordered subset for the LLM call.
"""

import logging
from dataclasses import replace

from app.analytics.insight_signal_detector import InsightSignal

logger = logging.getLogger(__name__)

# Advisory minimum — the prioritizer returns all available signals if fewer than this exist.
# No padding logic: callers must handle <2 cards gracefully.
_DESIRED_MIN_CARDS = 2
_MAX_CARDS = 10
_MAX_PER_CATEGORY = 2
# Categories not listed (E, G, H) default to 99 (low recency weight — intentional for compound/quality signals)
_RECENCY_ORDER: dict[str, int] = {"C": 0, "A": 1, "B": 1, "E": 1, "G": 1, "H": 2, "D": 3}


class SignalPrioritizer:
    def __init__(self, signals: list[InsightSignal]) -> None:
        self.signals = signals

    def prioritize(self) -> list[InsightSignal]:
        if not self.signals:
            return []

        # Step 1: Deduplicate
        signals = _deduplicate(self.signals)

        # Step 2: Separate critical anomalies
        critical = [s for s in signals if s.category == "C" and s.severity == 5]
        rest = [s for s in signals if not (s.category == "C" and s.severity == 5)]

        # Step 3: Score and sort the rest
        def _sort_key(s: InsightSignal) -> tuple[int, int]:
            composite = (s.severity * 3) + (int(s.focus_relevant) * 2) + int(s.actionable)
            recency = _RECENCY_ORDER.get(s.category, 99)
            return (-composite, recency)

        rest_sorted = sorted(rest, key=_sort_key)

        # Step 4: Diversity cap (max 2 per category, C exempt)
        category_counts: dict[str, int] = {}
        capped: list[InsightSignal] = []
        for s in rest_sorted:
            count = category_counts.get(s.category, 0)
            if count < _MAX_PER_CATEGORY:
                capped.append(s)
                category_counts[s.category] = count + 1

        # Step 5: Combine — pin up to 2 critical anomalies at top
        combined = critical[:2] + capped

        # Step 6: Category diversity enforcement (≥4 signals → ≥2 categories)
        if len(combined) >= 4:
            categories_present = {s.category for s in combined}
            if len(categories_present) < 2:
                for s in rest_sorted:
                    if s.category not in categories_present and s not in combined:
                        combined.append(s)
                        break

        # Step 7: Clamp to max
        result = combined[:_MAX_CARDS]

        logger.debug(
            "SignalPrioritizer: %d signals in → %d signals out",
            len(self.signals),
            len(result),
        )
        return result


def _deduplicate(signals: list[InsightSignal]) -> list[InsightSignal]:
    """Merge trend_decline + goal_near_miss/goal_behind_pace for the same metric."""
    MERGEABLE_GOAL_TYPES = {"goal_near_miss", "goal_behind_pace"}

    # Index: metric → list of signals about that metric
    by_metric: dict[str, list[InsightSignal]] = {}
    for s in signals:
        for m in s.metrics:
            by_metric.setdefault(m, []).append(s)

    merged_ids: set[int] = set()  # id() is safe: signals are short-lived, non-mutated dataclass instances
    result: list[InsightSignal] = []

    for s in signals:
        if id(s) in merged_ids:
            continue

        if s.signal_type == "trend_decline" and s.metrics:
            metric = s.metrics[0]
            partner = next(
                (
                    g
                    for g in by_metric.get(metric, [])
                    if g.signal_type in MERGEABLE_GOAL_TYPES and id(g) not in merged_ids
                ),
                None,
            )
            if partner is not None:
                merged = replace(
                    s if s.severity >= partner.severity else partner,
                    severity=max(s.severity, partner.severity),
                    data_payload={**s.data_payload, **partner.data_payload},
                    values={**s.values, **partner.values},
                )
                result.append(merged)
                merged_ids.add(id(s))
                merged_ids.add(id(partner))
                continue

        result.append(s)
        merged_ids.add(id(s))

    return result
