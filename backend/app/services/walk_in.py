"""Counter bookings for drivers who do not have the app.

A walk-in session is a ``ParkingHistory`` row with ``user_id = NULL`` and
``is_walk_in = True``. There is no ``Vehicle`` row and no QR pass: staff open
the session by plate at entry and close it by plate at exit.
"""

from __future__ import annotations

import re

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppError, ConflictError, NotFoundError
from app.core.security import as_utc, new_id, utcnow
from app.db.models import ParkingHistory, ParkingSlot, User
from app.schemas.common import StaffSessionOut
from app.services.allocation import get_active_subscription, slot_label
from app.services.billing import calculate_hourly_charge_paise, format_duration

_PLATE_RE = re.compile(r"^[A-Z0-9]{4,12}$")


def normalize_plate(plate: str) -> str:
    """Uppercase and strip separators so ``KA 01 AB 1234`` matches ``ka01ab1234``."""
    cleaned = re.sub(r"[^A-Za-z0-9]", "", plate or "").upper()
    if not _PLATE_RE.match(cleaned):
        raise AppError("Enter a valid vehicle number (e.g. KA01AB1234)")
    return cleaned


def normalize_contact(phone: str | None) -> str | None:
    if not phone:
        return None
    digits = re.sub(r"\D", "", phone)[-10:]
    if not digits:
        return None
    if not re.match(r"^[6-9]\d{9}$", digits):
        raise AppError("Enter a valid 10-digit mobile number")
    return digits


def plate_expr():
    """SQL-side plate normalization so ``KA-01-AB-1234`` matches ``KA01AB1234``.

    Uses only ``upper``/``replace`` so it behaves the same on Postgres and SQLite.
    """
    expr = func.upper(ParkingHistory.vehicle_number)
    for char in (" ", "-", ".", "_"):
        expr = func.replace(expr, char, "")
    return expr


async def find_open_session_by_plate(db: AsyncSession, plate: str) -> ParkingHistory | None:
    return await db.scalar(
        select(ParkingHistory)
        .where(
            plate_expr() == plate,
            ParkingHistory.status == "parked",
        )
        .order_by(ParkingHistory.entry_at.desc())
        .limit(1)
    )


async def _claim_free_slot(db: AsyncSession) -> ParkingSlot:
    slot = await db.scalar(
        select(ParkingSlot)
        .where(
            ParkingSlot.is_premium.is_(False),
            ParkingSlot.is_occupied.is_(False),
            ParkingSlot.assigned_user_id.is_(None),
        )
        .order_by(ParkingSlot.floor, ParkingSlot.zone, ParkingSlot.slot_number)
        .limit(1)
    )
    if slot is None:
        # Fall back to premium bays only when every standard bay is taken.
        slot = await db.scalar(
            select(ParkingSlot)
            .where(
                ParkingSlot.is_occupied.is_(False),
                ParkingSlot.assigned_user_id.is_(None),
            )
            .order_by(ParkingSlot.floor, ParkingSlot.zone, ParkingSlot.slot_number)
            .limit(1)
        )
    if slot is None:
        raise ConflictError("Tower is full. No bay available right now.")
    return slot


async def create_walk_in_session(
    db: AsyncSession,
    *,
    number_plate: str,
    driver_name: str | None,
    contact_phone: str | None,
    staff: User,
) -> ParkingHistory:
    plate = normalize_plate(number_plate)
    contact = normalize_contact(contact_phone)

    existing = await find_open_session_by_plate(db, plate)
    if existing is not None:
        raise ConflictError(
            f"{plate} is already parked at {existing.slot_number}. Check it out first."
        )

    slot = await _claim_free_slot(db)
    slot.is_occupied = True

    history = ParkingHistory(
        id=new_id("hist"),
        user_id=None,
        vehicle_number=plate,
        entry_at=utcnow(),
        tower=slot.tower,
        floor=slot.floor,
        zone=slot.zone,
        slot_number=slot.slot_number,
        parking_slot_id=slot.id,
        subscription_type="hourly",
        billing_type="hourly",
        status="parked",
        payment_status="free",
        is_walk_in=True,
        driver_name=(driver_name or "").strip() or None,
        contact_phone=contact,
        created_by_staff_id=staff.id,
    )
    db.add(history)
    await db.commit()
    await db.refresh(history)
    return history


async def close_session(
    db: AsyncSession, *, history_id: str, staff: User
) -> ParkingHistory:
    """Stamp exit, bill hourly usage when applicable and release the bay."""
    session = await db.get(ParkingHistory, history_id)
    if session is None:
        raise NotFoundError("Parking session not found")
    if session.status != "parked":
        raise AppError("This session is already closed")

    sub = None
    if session.user_id:
        sub = await get_active_subscription(db, session.user_id)

    now = utcnow()
    duration_seconds = int((now - as_utc(session.entry_at)).total_seconds())
    session.exit_at = now
    session.duration_seconds = duration_seconds
    session.status = "completed"
    session.closed_by_staff_id = staff.id

    amount_paise = 0
    if sub is None or sub.plan_type == "hourly":
        amount_paise = calculate_hourly_charge_paise(duration_seconds)
        session.billing_type = "hourly"
        session.subscription_type = "hourly"
    else:
        session.billing_type = sub.plan_type
        session.subscription_type = sub.plan_type
    session.amount_in_paise = amount_paise
    session.payment_status = "pending" if amount_paise > 0 else "free"

    slot = None
    if session.parking_slot_id:
        slot = await db.get(ParkingSlot, session.parking_slot_id)
    if slot is None:
        slot = await db.scalar(
            select(ParkingSlot).where(
                ParkingSlot.tower == session.tower,
                ParkingSlot.floor == session.floor,
                ParkingSlot.zone == session.zone,
                ParkingSlot.slot_number == session.slot_number,
            )
        )
    if slot is not None:
        slot.is_occupied = False
        if sub is None:
            slot.assigned_user_id = None

    await db.commit()
    await db.refresh(session)
    return session


async def mark_session_paid(
    db: AsyncSession, *, history_id: str, staff: User
) -> ParkingHistory:
    """Cash collected at the counter — used for walk-ins with no online payment."""
    session = await db.get(ParkingHistory, history_id)
    if session is None:
        raise NotFoundError("Parking session not found")
    if session.payment_status == "paid":
        return session
    if session.payment_status == "free":
        raise AppError("Nothing to collect for this session")

    session.payment_status = "paid"
    session.closed_by_staff_id = staff.id
    await db.commit()
    await db.refresh(session)
    return session


async def to_session_out(db: AsyncSession, session: ParkingHistory) -> StaffSessionOut:
    settings = get_settings()
    owner: User | None = None
    if session.user_id:
        owner = await db.get(User, session.user_id)

    duration = session.duration_seconds
    entry = session.entry_at
    if duration is None and session.status == "parked" and entry is not None:
        duration = int((utcnow() - as_utc(entry)).total_seconds())

    tower = session.tower or "A"
    floor = session.floor or 1
    zone = session.zone or "?"
    slot_number = session.slot_number or "?"
    if session.parking_slot_id:
        live = await db.get(ParkingSlot, session.parking_slot_id)
        if live is not None:
            tower, floor, zone, slot_number = live.tower, live.floor, live.zone, live.slot_number

    label = f"Tower {tower} · Floor {floor} · Zone {zone} · Slot {slot_number}"
    amount = session.amount_in_paise
    return StaffSessionOut(
        id=session.id,
        vehicle_number=session.vehicle_number or "UNKNOWN",
        driver_name=session.driver_name,
        contact_phone=session.contact_phone,
        user_name=owner.display_name if owner else session.driver_name,
        user_phone=(owner.phone if owner else session.contact_phone),
        is_walk_in=bool(session.is_walk_in),
        slot_label=label,
        tower=tower,
        floor=floor,
        zone=zone,
        slot_number=slot_number,
        entry_at=entry or utcnow(),
        exit_at=session.exit_at,
        duration_seconds=duration,
        duration_label=format_duration(duration) if duration is not None else None,
        status=session.status or "parked",
        billing_type=session.billing_type or "hourly",
        payment_status=session.payment_status or "free",
        amount_in_paise=amount,
        amount_rupees=(amount / 100.0) if amount is not None else None,
        hourly_rate_rupees=settings.hourly_rate_paise / 100.0,
    )


__all__ = [
    "close_session",
    "create_walk_in_session",
    "find_open_session_by_plate",
    "mark_session_paid",
    "normalize_contact",
    "normalize_plate",
    "slot_label",
    "to_session_out",
]
