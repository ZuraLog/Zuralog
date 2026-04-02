"""
Zuralog Cloud Brain — Message Router.

Decides which AI model handles each incoming message based on per-user
rate limit state and message complexity classification.

Decision tree (evaluated in order):
  1. Burst window exhausted → reject (LimitExhaustedException, is_burst=True)
  2. Both models exhausted → reject (LimitExhaustedException, is_burst=False)
  3. Only Zura Flash available → route to Zura Flash (skip classifier)
  4. Only Zura available (Flash exhausted) → route to Zura (skip classifier)
  5. **Path E — Only Zura available:** (Flash exhausted) Skip classifier, always route to Zura.
  6. Both available → classify → route accordingly
"""

import logging

from app.agent.classifier import MessageTier, classify_message
from app.config import ROUTER_MODEL_ZURA, ROUTER_MODEL_ZURA_FLASH
from dataclasses import dataclass

logger = logging.getLogger(__name__)


class LimitExhaustedException(Exception):
    """Raised when all available model limits are exhausted for this user."""

    def __init__(self, message: str, reset_seconds: int, is_burst: bool = False, tier: str = "free") -> None:
        super().__init__(message)
        self.message = message
        self.reset_seconds = reset_seconds
        self.is_burst = is_burst
        self.tier = tier


@dataclass
class RoutingResult:
    """Result of the routing decision."""
    model: str          # OpenRouter model ID (e.g. "moonshotai/kimi-k2.5")
    model_tier: str     # "zura" or "zura_flash"
    classifier_result: str  # "deep_analysis", "standard", or "skipped"


async def route_message(
    text: str,
    user_id: str,
    tier: str,
    rate_limiter,
) -> RoutingResult:
    """Route a message to the appropriate model based on limits and complexity.

    Args:
        text: The user's message text.
        user_id: The authenticated user's ID.
        tier: Subscription tier ("free" or "premium").
        rate_limiter: A RateLimiter instance with check_model_limits().

    Returns:
        RoutingResult indicating which model to use.

    Raises:
        LimitExhaustedException: When all relevant model capacity is exhausted.
    """
    limits = await rate_limiter.check_model_limits(user_id, tier)

    # Path 1: Burst window exhausted — reject regardless of model state.
    if not limits.burst_allowed:
        raise LimitExhaustedException(
            message="You're sending messages too quickly. Please slow down.",
            reset_seconds=limits.burst_reset_seconds,
            is_burst=True,
            tier=tier,
        )

    # Path 2: Both models exhausted — reject.
    if not limits.flash_allowed and not limits.zura_allowed:
        reset = min(limits.flash_reset_seconds, limits.zura_reset_seconds)
        raise LimitExhaustedException(
            message="You've used all your messages for this period.",
            reset_seconds=reset,
            is_burst=False,
            tier=tier,
        )

    # Path 3: Only Zura Flash available (Zura exhausted) — skip classifier.
    if not limits.zura_allowed:
        return RoutingResult(
            model=ROUTER_MODEL_ZURA_FLASH,
            model_tier="zura_flash",
            classifier_result="skipped",
        )

    # Path 4: Only Zura available (Flash exhausted) — skip classifier, use Zura.
    if not limits.flash_allowed:
        return RoutingResult(
            model=ROUTER_MODEL_ZURA,
            model_tier="zura",
            classifier_result="skipped",
        )

    # Path 6: Both available — classify and route.
    classification = await classify_message(text)
    if classification == MessageTier.deep_analysis:
        return RoutingResult(
            model=ROUTER_MODEL_ZURA,
            model_tier="zura",
            classifier_result=classification.value,
        )
    return RoutingResult(
        model=ROUTER_MODEL_ZURA_FLASH,
        model_tier="zura_flash",
        classifier_result=classification.value,
    )
