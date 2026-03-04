"""
Zuralog Cloud Brain — Report Routes.

REST endpoints for accessing generated health reports:
  GET /api/v1/reports        — list all reports (type filter + pagination)
  GET /api/v1/reports/{id}   — fetch a specific report

Authentication: Bearer JWT via ``get_authenticated_user_id``.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.report import Report, ReportType

logger = logging.getLogger(__name__)

router = APIRouter(tags=["reports"])


@router.get("/reports")
async def list_reports(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
    type: str | None = Query(default=None, description="Filter by report type: 'weekly' or 'monthly'"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict:
    """Return a paginated list of reports for the authenticated user.

    Args:
        type: Optional filter by ReportType value (``"weekly"`` or ``"monthly"``).
        limit: Maximum number of reports to return (1–100).
        offset: Number of records to skip for pagination.

    Returns:
        ``{"reports": [...], "total": int, "limit": int, "offset": int}``

    Raises:
        400 if ``type`` is not a valid ReportType value.
    """
    # Validate type filter if provided.
    if type is not None:
        valid_types = {rt.value for rt in ReportType}
        if type not in valid_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid report type '{type}'. Must be one of: {sorted(valid_types)}",
            )

    # Build query
    stmt = select(Report).where(Report.user_id == user_id)
    if type is not None:
        stmt = stmt.where(Report.type == type)
    stmt = stmt.order_by(Report.period_start.desc()).limit(limit).offset(offset)

    result = await db.execute(stmt)
    reports = result.scalars().all()

    # Count total (without limit/offset)
    from sqlalchemy import func

    count_stmt = select(func.count(Report.id)).where(Report.user_id == user_id)
    if type is not None:
        count_stmt = count_stmt.where(Report.type == type)
    count_result = await db.execute(count_stmt)
    total = count_result.scalar_one_or_none() or 0

    return {
        "reports": [r.to_dict() for r in reports],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.get("/reports/{report_id}")
async def get_report(
    report_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Fetch a specific report by ID.

    Args:
        report_id: UUID of the Report record.

    Returns:
        Serialized report dict.

    Raises:
        404 if the report does not exist or belongs to another user.
    """
    stmt = select(Report).where(
        Report.id == report_id,
        Report.user_id == user_id,
    )
    result = await db.execute(stmt)
    report = result.scalar_one_or_none()

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )

    return report.to_dict()
