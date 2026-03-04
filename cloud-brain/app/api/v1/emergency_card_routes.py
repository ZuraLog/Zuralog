"""
Zuralog Cloud Brain — Emergency Health Card API.

Endpoints:
  GET /api/v1/emergency-card — Retrieve the authenticated user's emergency card.
  PUT /api/v1/emergency-card — Create or fully replace the emergency card (upsert).

Auth is via ``get_current_user`` (returns the full User ORM object).
The card is stored one-per-user (``user_id`` is the primary key). On PUT,
key medical facts are soft-copied to the memory store if available, so
the AI coach can reference allergies, medications, and conditions.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.emergency_card import EmergencyCard
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/emergency-card", tags=["emergency-card"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class EmergencyCardRequest(BaseModel):
    """Payload for creating or replacing the emergency health card.

    All fields are optional — any omitted field is stored as its zero
    value (``None`` for blood_type, ``[]`` for list fields).

    Attributes:
        blood_type: ABO/Rh blood type string (e.g. ``"O+"``). Nullable.
        allergies: List of allergy description strings.
        medications: List of current medication name strings.
        conditions: List of medical condition strings.
        emergency_contacts: List of contact dicts. Each dict should contain
            ``name``, ``relationship``, and ``phone`` keys.
    """

    blood_type: str | None = None
    allergies: list[str] = []
    medications: list[str] = []
    conditions: list[str] = []
    emergency_contacts: list[dict] = []


class EmergencyCardResponse(BaseModel):
    """Emergency health card payload returned to the client.

    Attributes:
        user_id: Supabase UID of the card owner.
        blood_type: ABO/Rh blood type string, or ``None`` if not set.
        allergies: List of allergy description strings.
        medications: List of current medication name strings.
        conditions: List of medical condition strings.
        emergency_contacts: List of emergency contact dicts.
        updated_at: ISO-8601 last-update timestamp, or ``None``.
    """

    user_id: str
    blood_type: str | None
    allergies: list
    medications: list
    conditions: list
    emergency_contacts: list
    updated_at: str | None

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _card_to_response(card: EmergencyCard) -> dict:
    """Serialise an EmergencyCard ORM instance to a response dict.

    Args:
        card: The ORM row to serialise.

    Returns:
        Dict suitable for the EmergencyCardResponse schema.
    """
    return {
        "user_id": card.user_id,
        "blood_type": card.blood_type,
        "allergies": card.allergies or [],
        "medications": card.medications or [],
        "conditions": card.conditions or [],
        "emergency_contacts": card.emergency_contacts or [],
        "updated_at": str(card.updated_at) if card.updated_at else None,
    }


async def _update_memory_store(request: Request, user_id: str, card: EmergencyCard) -> None:
    """Soft-copy key medical facts to the memory store if available.

    Reads ``request.app.state.memory_store`` — if absent or if writing
    raises any exception, the failure is logged and silently swallowed so
    it never breaks the API response.

    Args:
        request: The incoming FastAPI request (for app.state access).
        user_id: The authenticated user's ID.
        card: The newly saved EmergencyCard ORM instance.
    """
    try:
        memory_store = getattr(request.app.state, "memory_store", None)
        if memory_store is None:
            return

        facts: list[str] = []

        if card.blood_type:
            facts.append(f"Blood type: {card.blood_type}")

        if card.allergies:
            facts.append(f"Allergies: {', '.join(card.allergies)}")

        if card.medications:
            facts.append(f"Medications: {', '.join(card.medications)}")

        if card.conditions:
            facts.append(f"Medical conditions: {', '.join(card.conditions)}")

        if facts:
            await memory_store.save_facts(user_id=user_id, facts=facts, source="emergency_card")
            logger.info(
                "_update_memory_store: saved %d medical facts for user='%s'",
                len(facts),
                user_id,
            )
    except Exception:  # noqa: BLE001
        logger.debug(
            "_update_memory_store: memory store write skipped for user='%s'",
            user_id,
        )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="Retrieve the emergency health card", response_model=EmergencyCardResponse)
async def get_emergency_card(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the authenticated user's emergency health card.

    Args:
        current_user: The authenticated User ORM instance.
        db: Async database session.

    Returns:
        The user's ``EmergencyCardResponse``.

    Raises:
        HTTPException: 404 if no card has been set yet.
    """
    result = await db.execute(
        select(EmergencyCard).where(EmergencyCard.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()

    if card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No emergency card found. Use PUT /emergency-card to create one.",
        )

    logger.info("get_emergency_card: found card for user='%s'", current_user.id)
    return _card_to_response(card)


@router.put("", summary="Create or replace the emergency health card", response_model=EmergencyCardResponse)
async def upsert_emergency_card(
    request: Request,
    body: EmergencyCardRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create the emergency health card or fully replace all fields if one exists.

    The PUT implements upsert semantics: if a card already exists for the
    user, all fields are overwritten with the values in the request body.
    Omitted list fields default to empty arrays; ``blood_type`` defaults
    to ``None``.

    After saving, key medical facts (allergies, medications, conditions)
    are soft-written to the memory store so the AI coach can reference
    them. Memory store failures are silently ignored.

    Args:
        request: The incoming FastAPI request (for memory store access).
        body: New card field values.
        current_user: The authenticated User ORM instance.
        db: Async database session.

    Returns:
        The created or updated ``EmergencyCardResponse``.
    """
    result = await db.execute(
        select(EmergencyCard).where(EmergencyCard.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()

    if card is not None:
        # Full replacement of all fields.
        card.blood_type = body.blood_type
        card.allergies = body.allergies
        card.medications = body.medications
        card.conditions = body.conditions
        card.emergency_contacts = body.emergency_contacts
        logger.info("upsert_emergency_card: replacing card for user='%s'", current_user.id)
    else:
        # Create a new card row.
        card = EmergencyCard(
            user_id=current_user.id,
            blood_type=body.blood_type,
            allergies=body.allergies,
            medications=body.medications,
            conditions=body.conditions,
            emergency_contacts=body.emergency_contacts,
        )
        db.add(card)
        logger.info("upsert_emergency_card: creating card for user='%s'", current_user.id)

    await db.commit()
    await db.refresh(card)

    # Soft-update memory store — never raises.
    await _update_memory_store(request, current_user.id, card)

    return _card_to_response(card)
