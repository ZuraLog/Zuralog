"""
Zuralog Cloud Brain — Trend Detector.

Identifies directional trends in health metric time series by comparing
moving averages over configurable windows. Used to answer questions like
"Is my sleep improving?" or "Are my steps declining this month?"
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class TrendDetector:
    """Detects upward, downward, or stable trends in numeric time series.

    Compares the mean of the most recent window of values against the
    mean of the immediately preceding window. The percent change between
    these two averages is classified against a configurable sensitivity
    threshold.

    All methods are pure functions with no side effects.
    """

    DEFAULT_WINDOW: int = 7
    DEFAULT_SENSITIVITY: float = 10.0

    def detect_trend(
        self,
        values: list[float],
        window_size: int = DEFAULT_WINDOW,
        sensitivity_pct: float = DEFAULT_SENSITIVITY,
    ) -> dict[str, Any]:
        """Detect the directional trend in a series of numeric values.

        Splits the tail of ``values`` into two adjacent windows of length
        ``window_size``, computes each window's mean, and classifies the
        percent change between them as ``"up"``, ``"down"``, or ``"stable"``.

        Args:
            values: Ordered numeric observations (oldest first).
                Must contain at least ``window_size * 2`` entries for a
                meaningful comparison.
            window_size: Number of observations in each comparison window.
                Defaults to :pyattr:`DEFAULT_WINDOW` (7).
            sensitivity_pct: Minimum absolute percent change required to
                classify a trend as ``"up"`` or ``"down"``. Values within
                +/- this threshold are classified ``"stable"``.
                Defaults to :pyattr:`DEFAULT_SENSITIVITY` (10.0).

        Returns:
            A dict with the following keys:

            - **trend** (``str``): One of ``"up"``, ``"down"``,
              ``"stable"``, or ``"insufficient_data"``.
            - **percent_change** (``float``): Percent change from
              previous to recent window, rounded to 1 decimal place.
              Present only when sufficient data exists.
            - **recent_avg** (``float``): Mean of the recent window,
              rounded to 2 decimal places.
            - **previous_avg** (``float``): Mean of the previous window,
              rounded to 2 decimal places.
        """
        min_required = window_size * 2
        if len(values) < min_required:
            logger.debug(
                "Insufficient data: got %d values, need %d (window_size=%d)",
                len(values),
                min_required,
                window_size,
            )
            return {"trend": "insufficient_data"}

        recent = values[-window_size:]
        previous = values[-min_required:-window_size]

        recent_avg = sum(recent) / window_size
        previous_avg = sum(previous) / window_size

        pct_change = self._percent_change(previous_avg, recent_avg)
        trend = self._classify(pct_change, sensitivity_pct)

        return {
            "trend": trend,
            "percent_change": round(pct_change, 1),
            "recent_avg": round(recent_avg, 2),
            "previous_avg": round(previous_avg, 2),
        }

    @staticmethod
    def _percent_change(previous_avg: float, recent_avg: float) -> float:
        """Compute percent change, handling a zero baseline gracefully.

        Args:
            previous_avg: Mean of the previous (older) window.
            recent_avg: Mean of the recent (newer) window.

        Returns:
            Percent change from ``previous_avg`` to ``recent_avg``.
            If ``previous_avg`` is zero and ``recent_avg`` is positive,
            returns ``100.0``. If both are zero, returns ``0.0``.
        """
        if previous_avg == 0:
            return 100.0 if recent_avg > 0 else 0.0
        return ((recent_avg - previous_avg) / previous_avg) * 100

    @staticmethod
    def _classify(pct_change: float, sensitivity_pct: float) -> str:
        """Classify a percent change into a trend direction.

        Args:
            pct_change: Percent change between two window averages.
            sensitivity_pct: Threshold for non-stable classification.

        Returns:
            ``"up"`` if change exceeds positive threshold,
            ``"down"`` if below negative threshold, otherwise ``"stable"``.
        """
        if pct_change > sensitivity_pct:
            return "up"
        if pct_change < -sensitivity_pct:
            return "down"
        return "stable"
