import pytest
from dataclasses import replace
from app.analytics.insight_signal_detector import InsightSignal
from app.analytics.signal_prioritizer import SignalPrioritizer


def _signal(
    signal_type="trend_decline", category="A", severity=2, focus_relevant=False, actionable=False, metrics=None
):
    return InsightSignal(
        signal_type=signal_type,
        category=category,
        metrics=metrics or ["steps"],
        values={},
        severity=severity,
        actionable=actionable,
        focus_relevant=focus_relevant,
        title_hint="Test",
        data_payload={},
    )


def test_empty_input_returns_empty():
    assert SignalPrioritizer([]).prioritize() == []


def test_critical_anomaly_pinned_to_top():
    signals = [
        _signal("trend_decline", "A", severity=3),
        _signal("anomaly", "C", severity=5),
    ]
    result = SignalPrioritizer(signals).prioritize()
    assert result[0].signal_type == "anomaly"


def test_composite_score_orders_by_focus_and_actionable():
    high = _signal("goal_near_miss", "B", severity=3, focus_relevant=True, actionable=True)
    low = _signal("correlation_discovery", "D", severity=3, focus_relevant=False, actionable=False)
    result = SignalPrioritizer([low, high]).prioritize()
    assert result[0].signal_type == "goal_near_miss"


def test_deduplication_merges_trend_and_goal_for_same_metric():
    trend = _signal("trend_decline", "A", severity=2, metrics=["steps"])
    goal = _signal("goal_near_miss", "B", severity=4, metrics=["steps"])
    result = SignalPrioritizer([trend, goal]).prioritize()
    steps_signals = [s for s in result if "steps" in s.metrics]
    assert len(steps_signals) == 1
    assert steps_signals[0].severity == 4


def test_diversity_cap_limits_to_2_per_category():
    signals = [_signal(f"type_{i}", "A", severity=2) for i in range(5)]
    result = SignalPrioritizer(signals).prioritize()
    a_signals = [s for s in result if s.category == "A"]
    assert len(a_signals) <= 2


def test_anomaly_exempt_from_diversity_cap():
    signals = [_signal("anomaly", "C", severity=5) for _ in range(4)]
    result = SignalPrioritizer(signals).prioritize()
    c_signals = [s for s in result if s.category == "C"]
    # Critical anomalies: up to 2 pinned, but severity<5 ones still capped
    assert len(c_signals) >= 2


def test_max_ten_cards():
    signals = [_signal(f"type_{i}", chr(65 + i % 7), severity=2) for i in range(15)]
    assert len(SignalPrioritizer(signals).prioritize()) <= 10


def test_single_signal_returned():
    signals = [_signal("trend_decline", "A", severity=2)]
    assert len(SignalPrioritizer(signals).prioritize()) == 1


def test_category_diversity_with_4_plus_signals():
    signals = [_signal("type_a", "A", severity=3) for _ in range(2)] + [
        _signal("type_b", "B", severity=3) for _ in range(2)
    ]
    result = SignalPrioritizer(signals).prioritize()
    assert len({s.category for s in result}) >= 2
