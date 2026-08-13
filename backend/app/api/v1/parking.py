from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.exceptions import AppError, NotFoundError
from app.core.security import new_id, utcnow, as_utc
from app.db.models import ParkingHistory, ParkingSlot, User, Vehicle
from app.db.seed import EXPECTED_SLOT_COUNT, PREMIUM_SLOTS, STANDARD_SLOTS, TOWER_ID
from app.db.session import get_db
from app.schemas.common import (
    GateScanIn,
    GateValidateOut,
    ParkingHistoryOut,
    ParkingSlotOut,
    TowerCapacityOut,
)
from app.services.allocation import (
    allocate_slot_for_user,
    get_active_subscription,
    issue_qr_for_user,
)
from app.services.billing import calculate_hourly_charge_paise
from app.services.gate import process_gate_scan

router = APIRouter(prefix="/parking", tags=["parking"])


@router.get("/capacity", response_model=TowerCapacityOut)
async def tower_capacity(
    db: AsyncSession = Depends(get_db),
) -> TowerCapacityOut:
    """Public-ish capacity snapshot for the demo tower (auth still required via router norms)."""
    settings = get_settings()
    total = await db.scalar(select(func.count()).select_from(ParkingSlot)) or 0
    if total == 0:
        total = EXPECTED_SLOT_COUNT
        occupied = 0
        available = total
        premium_available = PREMIUM_SLOTS
        standard_available = STANDARD_SLOTS
    else:
        occupied = (
            await db.scalar(
                select(func.count())
                .select_from(ParkingSlot)
                .where(ParkingSlot.is_occupied.is_(True))
            )
            or 0
        )
        available = total - occupied
        premium_available = (
            await db.scalar(
                select(func.count())
                .select_from(ParkingSlot)
                .where(
                    ParkingSlot.is_premium.is_(True),
                    ParkingSlot.is_occupied.is_(False),
                    ParkingSlot.assigned_user_id.is_(None),
                )
            )
            or 0
        )
        standard_available = (
            await db.scalar(
                select(func.count())
                .select_from(ParkingSlot)
                .where(
                    ParkingSlot.is_premium.is_(False),
                    ParkingSlot.is_occupied.is_(False),
                    ParkingSlot.assigned_user_id.is_(None),
                )
            )
            or 0
        )
    return TowerCapacityOut(
        tower_id=TOWER_ID,
        tower_name="MultiParking Tower A",
        total_slots=total,
        available_slots=available,
        occupied_slots=occupied,
        premium_available=premium_available,
        standard_available=standard_available,
        hourly_rate_rupees=settings.hourly_rate_paise / 100.0,
    )


@router.get("/slot", response_model=ParkingSlotOut | None)
async def current_slot(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ParkingSlotOut | None:
    sub = await get_active_subscription(db, user.id)
    if sub is None or not sub.parking_slot_id:
        slot = await db.scalar(
            select(ParkingSlot).where(ParkingSlot.assigned_user_id == user.id).limit(1)
        )
        if slot is None:
            return None
        return ParkingSlotOut.model_validate(slot)
    slot = await db.get(ParkingSlot, sub.parking_slot_id)
    if slot is None:
        return None
    return ParkingSlotOut.model_validate(slot)


@router.post("/allocate", response_model=ParkingSlotOut)
async def allocate(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ParkingSlotOut:
    slot = await allocate_slot_for_user(db, user)
    return ParkingSlotOut.model_validate(slot)


@router.post("/scan", response_model=GateValidateOut)
async def scan_parking_pass(
    body: GateScanIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> GateValidateOut:
    """In-app gate scanner: 1st scan = entry, 2nd scan = exit + amount."""
    _ = user  # Auth required; any signed-in attendant/user may scan a pass.
    return await process_gate_scan(db, token=body.token, action=body.action)


@router.get("/history", response_model=list[ParkingHistoryOut])
async def history(
    search: str | None = Query(default=None),
    filter: str | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ParkingHistoryOut]:
    stmt = select(ParkingHistory).where(ParkingHistory.user_id == user.id)
    if search:
        q = f"%{search.strip().upper()}%"
        stmt = stmt.where(
            or_(
                ParkingHistory.vehicle_number.ilike(q),
                ParkingHistory.slot_number.ilike(q),
                ParkingHistory.tower.ilike(q),
                ParkingHistory.zone.ilike(q),
            )
        )
    if filter:
        f = filter.lower().strip()
        if f in {"monthly", "annual", "hourly"}:
            stmt = stmt.where(ParkingHistory.subscription_type == f)
        elif f in {"parked", "completed"}:
            stmt = stmt.where(ParkingHistory.status == f)
        elif f in {"pending"}:
            stmt = stmt.where(ParkingHistory.payment_status == "pending")
        elif f in {"currentmonth", "current_month"}:
            now = utcnow()
            start = datetime(now.year, now.month, 1, tzinfo=now.tzinfo)
            stmt = stmt.where(ParkingHistory.entry_at >= start)
    stmt = stmt.order_by(ParkingHistory.entry_at.desc())
    rows = await db.scalars(stmt)
    return [ParkingHistoryOut.model_validate(r) for r in rows]


@router.post("/simulate-entry", response_model=ParkingHistoryOut)
async def simulate_entry(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ParkingHistoryOut:
    """Dev helper: record an entry using the user's current slot/vehicle (no gate hardware)."""
    settings = get_settings()
    if settings.app_env == "production" and not settings.otp_dev_mode:
        raise AppError("simulate-entry is disabled outside development")

    open_session = await db.scalar(
        select(ParkingHistory).where(
            ParkingHistory.user_id == user.id,
            ParkingHistory.status == "parked",
        )
    )
    if open_session:
        raise AppError("Vehicle is already parked")

    vehicle = await db.scalar(
        select(Vehicle)
        .where(Vehicle.user_id == user.id)
        .order_by(Vehicle.is_default.desc(), Vehicle.created_at.desc())
        .limit(1)
    )
    if vehicle is None:
        raise AppError("Register a vehicle before entry")

    slot = await allocate_slot_for_user(db, user)
    try:
        await issue_qr_for_user(db, user)
    except AppError:
        pass

    sub = await get_active_subscription(db, user.id)
    billing_type = sub.plan_type if sub else "hourly"
    now = utcnow()
    slot.is_occupied = True
    slot.assigned_user_id = user.id
    session = ParkingHistory(
        id=new_id("hist"),
        user_id=user.id,
        vehicle_number=vehicle.number_plate,
        entry_at=now,
        tower=slot.tower,
        floor=slot.floor,
        zone=slot.zone,
        slot_number=slot.slot_number,
        subscription_type=billing_type,
        billing_type=billing_type,
        status="parked",
        payment_status="free",
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return ParkingHistoryOut.model_validate(session)


@router.post("/simulate-exit", response_model=ParkingHistoryOut)
async def simulate_exit(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ParkingHistoryOut:
    """Dev helper: complete the open parking session and bill hourly if needed."""
    settings = get_settings()
    if settings.app_env == "production" and not settings.otp_dev_mode:
        raise AppError("simulate-exit is disabled outside development")

    session = await db.scalar(
        select(ParkingHistory)
        .where(
            ParkingHistory.user_id == user.id,
            ParkingHistory.status == "parked",
        )
        .order_by(ParkingHistory.entry_at.desc())
        .limit(1)
    )
    if session is None:
        raise AppError("No active parking session to exit")

    sub = await get_active_subscription(db, user.id)
    billing_type = sub.plan_type if sub else "hourly"
    now = utcnow()
    duration_seconds = int((now - as_utc(session.entry_at)).total_seconds())
    session.exit_at = now
    session.duration_seconds = duration_seconds
    session.status = "completed"

    amount_paise = 0
    if billing_type == "hourly" or sub is None:
        amount_paise = calculate_hourly_charge_paise(duration_seconds)
        session.billing_type = "hourly"
        session.subscription_type = "hourly"
    else:
        session.billing_type = billing_type
        session.subscription_type = billing_type
    session.amount_in_paise = amount_paise
    session.payment_status = "pending" if amount_paise > 0 else "free"

    slot = await db.scalar(
        select(ParkingSlot).where(ParkingSlot.assigned_user_id == user.id).limit(1)
    )
    if slot is not None:
        slot.is_occupied = False
        if sub is None:
            slot.assigned_user_id = None

    await db.commit()
    await db.refresh(session)
    return ParkingHistoryOut.model_validate(session)
