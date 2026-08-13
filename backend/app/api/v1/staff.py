from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_staff
from app.core.security import utcnow
from app.db.models import ParkingHistory, ParkingSlot, User
from app.db.session import get_db
from app.db.seed import FLOORS, EXPECTED_SLOT_COUNT
from app.schemas.common import (
    GateScanIn,
    GateValidateOut,
    ParkingSlotOut,
    StaffOverviewOut,
    StaffSessionOut,
    WalkInIn,
)
from app.services.gate import process_gate_scan
from app.services import walk_in as walk_in_service

router = APIRouter(prefix="/staff", tags=["staff"])


def _start_of_today() -> datetime:
    now = utcnow()
    return datetime(now.year, now.month, now.day, tzinfo=timezone.utc)


@router.get("/overview", response_model=StaffOverviewOut)
async def overview(
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> StaffOverviewOut:
    settings = get_settings()
    total = await db.scalar(select(func.count()).select_from(ParkingSlot)) or 0
    if total == 0:
        total = EXPECTED_SLOT_COUNT
        occupied = 0
    else:
        occupied = (
            await db.scalar(
                select(func.count())
                .select_from(ParkingSlot)
                .where(ParkingSlot.is_occupied.is_(True))
            )
            or 0
        )

    parked_now = await db.scalar(
        select(func.count()).select_from(ParkingHistory).where(ParkingHistory.status == "parked")
    ) or 0
    walk_ins_parked = await db.scalar(
        select(func.count())
        .select_from(ParkingHistory)
        .where(ParkingHistory.status == "parked", ParkingHistory.is_walk_in.is_(True))
    ) or 0

    today = _start_of_today()
    entries_today = await db.scalar(
        select(func.count()).select_from(ParkingHistory).where(ParkingHistory.entry_at >= today)
    ) or 0
    exits_today = await db.scalar(
        select(func.count())
        .select_from(ParkingHistory)
        .where(ParkingHistory.exit_at >= today)
    ) or 0
    pending_payments = await db.scalar(
        select(func.count())
        .select_from(ParkingHistory)
        .where(ParkingHistory.payment_status == "pending")
    ) or 0
    collected_paise = await db.scalar(
        select(func.coalesce(func.sum(ParkingHistory.amount_in_paise), 0)).where(
            ParkingHistory.payment_status == "paid",
            ParkingHistory.exit_at >= today,
        )
    ) or 0

    return StaffOverviewOut(
        staff_name=staff.display_name,
        role=staff.role,
        total_slots=total,
        occupied_slots=occupied,
        available_slots=total - occupied,
        parked_now=parked_now,
        walk_ins_parked=walk_ins_parked,
        entries_today=entries_today,
        exits_today=exits_today,
        pending_payments=pending_payments,
        collected_today_rupees=collected_paise / 100.0,
        hourly_rate_rupees=settings.hourly_rate_paise / 100.0,
    )


@router.post("/scan", response_model=GateValidateOut)
async def staff_scan(
    body: GateScanIn,
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> GateValidateOut:
    """Staff QR scanner: resolves entry vs exit and returns full pass details."""
    return await process_gate_scan(db, token=body.token, action=body.action, staff_id=staff.id)


@router.get("/slots", response_model=list[ParkingSlotOut])
async def list_slots_by_floor(
    floor: int = Query(..., ge=1, le=FLOORS, description="Floor 1–11; never returns all 1100"),
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> list[ParkingSlotOut]:
    """Inventory for one floor only (100 bays). Use floor filter — do not list the whole tower."""
    _ = staff
    rows = list(
        await db.scalars(
            select(ParkingSlot)
            .where(ParkingSlot.floor == floor)
            .order_by(ParkingSlot.zone, ParkingSlot.slot_number)
        )
    )
    return [ParkingSlotOut.model_validate(row) for row in rows]


@router.get("/sessions", response_model=list[StaffSessionOut])
async def active_sessions(
    search: str | None = Query(default=None),
    status: str = Query(default="parked"),
    floor: int | None = Query(default=None, ge=1, le=FLOORS),
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> list[StaffSessionOut]:
    _ = staff
    stmt = select(ParkingHistory)
    normalized = status.lower().strip()
    if normalized in {"parked", "completed"}:
        stmt = stmt.where(ParkingHistory.status == normalized)
    if floor is not None:
        stmt = stmt.outerjoin(
            ParkingSlot, ParkingHistory.parking_slot_id == ParkingSlot.id
        ).where(func.coalesce(ParkingSlot.floor, ParkingHistory.floor) == floor)
    if search:
        q = f"%{search.strip().upper()}%"
        stmt = stmt.where(
            or_(
                ParkingHistory.vehicle_number.ilike(q),
                ParkingHistory.slot_number.ilike(q),
                ParkingHistory.driver_name.ilike(q),
                ParkingHistory.contact_phone.ilike(q),
            )
        )
    order = (
        ParkingHistory.entry_at.desc()
        if normalized == "parked"
        else ParkingHistory.exit_at.desc()
    )
    stmt = stmt.order_by(order).limit(100)
    rows = list(await db.scalars(stmt))
    return [await walk_in_service.to_session_out(db, row) for row in rows]


@router.get("/sessions/lookup", response_model=StaffSessionOut | None)
async def lookup_session(
    plate: str = Query(..., min_length=3),
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> StaffSessionOut | None:
    _ = staff
    normalized = walk_in_service.normalize_plate(plate)
    session = await walk_in_service.find_open_session_by_plate(db, normalized)
    if session is None:
        return None
    return await walk_in_service.to_session_out(db, session)


@router.post("/walk-in", response_model=StaffSessionOut, status_code=201)
async def register_walk_in(
    body: WalkInIn,
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> StaffSessionOut:
    """Book a bay for a driver without the app, keyed by number plate."""
    session = await walk_in_service.create_walk_in_session(
        db,
        number_plate=body.number_plate,
        driver_name=body.driver_name,
        contact_phone=body.contact_phone,
        staff=staff,
    )
    return await walk_in_service.to_session_out(db, session)


@router.post("/sessions/{history_id}/checkout", response_model=StaffSessionOut)
async def checkout_session(
    history_id: str,
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> StaffSessionOut:
    """Close a parked session (walk-in or app user) and compute the amount due."""
    session = await walk_in_service.close_session(db, history_id=history_id, staff=staff)
    return await walk_in_service.to_session_out(db, session)


@router.post("/sessions/{history_id}/collect", response_model=StaffSessionOut)
async def collect_payment(
    history_id: str,
    staff: User = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
) -> StaffSessionOut:
    """Mark a pending amount as collected in cash at the counter."""
    session = await walk_in_service.mark_session_paid(db, history_id=history_id, staff=staff)
    return await walk_in_service.to_session_out(db, session)
