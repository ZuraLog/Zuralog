"""Muscle log endpoints — per-user muscle state logs."""
import logging
import re
import uuid
from datetime import date, datetime, time, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, field_validator
from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.muscle_log import MuscleLog

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/muscle-logs", tags=["muscle-logs"])

_VALID_SLUG = re.compile(r"^[a-z_]+$")
_VALID_STATES = {"fresh", "worked", "sore"}


class MuscleLogIn(BaseModel):
    muscle_group: str
    state: str
    log_date: str
    logged_at_time: str

    @field_validator("muscle_group")
    @classmethod
    def validate_slug(cls, v: str) -> str:
        if not _VALID_SLUG.match(v):
            raise ValueError("Invalid muscle_group slug")
        return v

    @field_validator("state")
    @classmethod
    def validate_state(cls, v: str) -> str:
        if v not in _VALID_STATES:
            raise ValueError(f"state must be one of {_VALID_STATES}")
        return v


class MuscleLogOut(BaseModel):
    id: str
    muscle_group: str
    state: str
    log_date: str
    logged_at_time: str


class MuscleLogsResponse(BaseModel):
    logs: list[MuscleLogOut]


@limiter.limit("60/minute")
@router.get("", response_model=MuscleLogsResponse)
async def get_muscle_logs(
    request: Request,
    log_date: str = Query(..., description="Date in YYYY-MM-DD format"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> MuscleLogsResponse:
    """Return all muscle logs for the authenticated user on the given date."""
    try:
        parsed_date = date.fromisoformat(log_date)
    except ValueError:
        raise HTTPException(status_code=422, detail="log_date must be YYYY-MM-DD")

    result = await db.execute(
        select(MuscleLog).where(
            MuscleLog.user_id == user_id,
            MuscleLog.log_date == parsed_date,
        )
    )
    rows = result.scalars().all()
    return MuscleLogsResponse(
        logs=[
            MuscleLogOut(
                id=str(r.id),
                muscle_group=r.muscle_group,
                state=r.state,
                log_date=r.log_date.isoformat(),
                logged_at_time=r.logged_at_time.strftime("%H:%M"),
            )
            for r in rows
        ]
    )


@limiter.limit("120/minute")
@router.post("", response_model=MuscleLogOut, status_code=200)
async def upsert_muscle_log(
    request: Request,
    body: MuscleLogIn,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> MuscleLogOut:
    """Upsert a muscle log entry. Replaces any existing entry for the same muscle + date."""
    try:
        parsed_date = date.fromisoformat(body.log_date)
        parsed_time = time.fromisoformat(body.logged_at_time)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid date or time format")

    stmt = (
        pg_insert(MuscleLog)
        .values(
            id=str(uuid.uuid4()),
            user_id=user_id,
            log_date=parsed_date,
            muscle_group=body.muscle_group,
            state=body.state,
            logged_at_time=parsed_time,
        )
        .on_conflict_do_update(
            constraint="uq_muscle_logs_user_date_muscle",
            set_={
                "state": body.state,
                "logged_at_time": parsed_time,
                "updated_at": datetime.now(timezone.utc),
            },
        )
        .returning(MuscleLog)
    )
    result = await db.execute(stmt)
    await db.commit()
    row = result.scalars().one()
    return MuscleLogOut(
        id=str(row.id),
        muscle_group=row.muscle_group,
        state=row.state,
        log_date=row.log_date.isoformat(),
        logged_at_time=row.logged_at_time.strftime("%H:%M"),
    )


@limiter.limit("30/minute")
@router.delete("", status_code=204)
async def delete_muscle_logs(
    request: Request,
    log_date: str = Query(..., description="Date in YYYY-MM-DD format"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> None:
    """Delete all muscle logs for the authenticated user on the given date."""
    try:
        parsed_date = date.fromisoformat(log_date)
    except ValueError:
        raise HTTPException(status_code=422, detail="log_date must be YYYY-MM-DD")

    await db.execute(
        delete(MuscleLog).where(
            MuscleLog.user_id == user_id,
            MuscleLog.log_date == parsed_date,
        )
    )
    await db.commit()
