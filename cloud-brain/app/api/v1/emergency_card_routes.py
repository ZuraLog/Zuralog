"""
Zuralog Cloud Brain — Emergency Health Card API Routes.

Provides upsert and retrieval endpoints for a user's emergency health card.
There is at most one card per user.

Endpoints:
    GET /api/v1/emergency-card   — Retrieve the user's emergency card
    PUT /api/v1/emergency-card   — Create or update the emergency card
"""

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.emergency_card import EmergencyHealthCard

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/emergency-card",
    tags=["emergency-card"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class MedicationEntry(BaseModel):
    """A single medication record.

    Attributes:
        name: Medication name (e.g. ``"Metformin"``).
        dose: Dose string (e.g. ``"500mg"``).
        frequency: Frequency string (e.g. ``"twice daily"``).
    """

    name: str
    dose: str | None = None
    frequency: str | None = None


class EmergencyContactEntry(BaseModel):
    """A single emergency contact record.

    Attributes:
        name: Contact's full name.
        relationship: Relationship to the user (e.g. ``"spouse"``).
        phone: Contact phone number.
    """

    name: str
    relationship: str | None = None
    phone: str | None = None


class EmergencyCardRequest(BaseModel):
    """Request body for creating or updating an emergency health card.

    All fields are optional to support partial updates.
    """

    blood_type: str | None = None
    allergies: list[str] | None = None
    medications: list[MedicationEntry] | None = None
    conditions: list[str] | None = None
    emergency_contacts: list[EmergencyContactEntry] | None = None


class EmergencyCardResponse(BaseModel):
    """API response shape for an emergency health card."""

    id: str
    user_id: str
    blood_type: str | None
    allergies: list[str] | None
    medications: list[Any] | None
    conditions: list[str] | None
    emergency_contacts: list[Any] | None
    updated_at: Any
    created_at: Any

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("", response_model=EmergencyCardResponse)
async def get_emergency_card(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> EmergencyHealthCard:
    """Retrieve the authenticated user's emergency health card.

    Args:
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        The user's :class:`EmergencyHealthCard`.

    Raises:
        HTTPException: 404 if no card has been created yet.
    """
    result = await db.execute(select(EmergencyHealthCard).where(EmergencyHealthCard.user_id == user_id))
    card = result.scalars().first()
    if card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Emergency health card not found. Use PUT to create one.",
        )
    return card


@router.put("", response_model=EmergencyCardResponse)
async def upsert_emergency_card(
    body: EmergencyCardRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> EmergencyHealthCard:
    """Create or update the authenticated user's emergency health card.

    Performs a full-replace upsert: all provided fields overwrite existing
    values. Fields set to ``null`` in the request body clear the stored
    value (explicit null semantics).

    Args:
        body: Emergency card payload. All fields are optional.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        The created or updated :class:`EmergencyHealthCard`.
    """
    result = await db.execute(select(EmergencyHealthCard).where(EmergencyHealthCard.user_id == user_id))
    card = result.scalars().first()

    # Serialise nested Pydantic models to plain dicts for JSON storage
    medications_data = [m.model_dump() for m in body.medications] if body.medications is not None else None
    contacts_data = [c.model_dump() for c in body.emergency_contacts] if body.emergency_contacts is not None else None

    if card is not None:
        # Update existing card with all fields from the request
        update_payload = {
            "blood_type": body.blood_type,
            "allergies": body.allergies,
            "medications": medications_data,
            "conditions": body.conditions,
            "emergency_contacts": contacts_data,
        }
        for field, value in update_payload.items():
            setattr(card, field, value)
    else:
        card = EmergencyHealthCard(
            user_id=user_id,
            blood_type=body.blood_type,
            allergies=body.allergies,
            medications=medications_data,
            conditions=body.conditions,
            emergency_contacts=contacts_data,
        )
        db.add(card)

    await db.commit()
    await db.refresh(card)
    return card
