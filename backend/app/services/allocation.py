from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ConflictError
from app.core.security import new_id, utcnow, as_utc
from app.db.models import (
    ParkingSlot,
    QrAccess,
    Subscription,
    User,
    Vehicle,
)
from app.services.qr_crypto import seal_qr_payload, token_hash


# Prefer lower floors for subscribers (quicker entry/exit). Not a permanent bay.
SUBSCRIBER_FLOORS = (1, 2, 3)


async def get_active_subscription(db: AsyncSession, user_id: str) -> Subscription | None:
    now = utcnow()
    result = await db.scalars(
        select(Subscription)
        .where(
            Subscription.user_id == user_id,
            Subscription.status == "active",
        )
        .order_by(Subscription.expiry_date.desc())
    )
    for sub in result:
        if as_utc(sub.expiry_date) > now:
            return sub
    return None


def has_active_plan(sub: Subscription | None) -> bool:
    """Monthly or annual — not pay-as-you-go."""
    return bool(sub and sub.plan_type in {"monthly", "annual"})


async def allocate_slot_for_user(db: AsyncSession, user: User) -> ParkingSlot:
    """Allocate a slot for the current visit.

    - Subscribers (monthly/annual): prefer premium Zone A on floors 1–3, then any
      premium bay tower-wide, then any free bay. Not permanent — freed on exit.
    - Hourly: temporary standard bay; occupancy flips only on real gate entry.
    """
    sub = await get_active_subscription(db, user.id)

    # Soft assignment only while the current visit is open (cleared on exit).
    existing_assigned = await db.scalar(
        select(ParkingSlot)
        .where(ParkingSlot.assigned_user_id == user.id)
        .limit(1)
    )
    if existing_assigned is not None:
        return existing_assigned

    if has_active_plan(sub):
        # 1) Premium on preferential floors 1–3
        slot = await db.scalar(
            select(ParkingSlot)
            .where(
                ParkingSlot.floor.in_(SUBSCRIBER_FLOORS),
                ParkingSlot.is_premium.is_(True),
                ParkingSlot.is_occupied.is_(False),
                ParkingSlot.assigned_user_id.is_(None),
            )
            .order_by(ParkingSlot.floor, ParkingSlot.zone, ParkingSlot.slot_number)
            .limit(1)
        )
        # 2) Any premium bay in the tower
        if slot is None:
            slot = await db.scalar(
                select(ParkingSlot)
                .where(
                    ParkingSlot.is_premium.is_(True),
                    ParkingSlot.is_occupied.is_(False),
                    ParkingSlot.assigned_user_id.is_(None),
                )
                .order_by(ParkingSlot.floor, ParkingSlot.zone, ParkingSlot.slot_number)
                .limit(1)
            )
        # 3) Any free bay on preferential floors
        if slot is None:
            slot = await db.scalar(
                select(ParkingSlot)
                .where(
                    ParkingSlot.floor.in_(SUBSCRIBER_FLOORS),
                    ParkingSlot.is_occupied.is_(False),
                    ParkingSlot.assigned_user_id.is_(None),
                )
                .order_by(
                    ParkingSlot.is_premium.desc(),
                    ParkingSlot.floor,
                    ParkingSlot.zone,
                    ParkingSlot.slot_number,
                )
                .limit(1)
            )
        # 4) Last resort — any free bay
        if slot is None:
            slot = await db.scalar(
                select(ParkingSlot)
                .where(
                    ParkingSlot.is_occupied.is_(False),
                    ParkingSlot.assigned_user_id.is_(None),
                )
                .order_by(
                    ParkingSlot.is_premium.desc(),
                    ParkingSlot.floor,
                    ParkingSlot.zone,
                    ParkingSlot.slot_number,
                )
                .limit(1)
            )
    else:
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
        raise ConflictError("No parking slots available right now")

    # Allotment alone must never look like the car is parked.
    slot.is_occupied = False
    slot.assigned_user_id = user.id
    # Do not pin a permanent bay on the subscription — premium users only get
    # preferential rows, not a reserved slot for the plan duration.
    if sub is not None:
        sub.parking_slot_id = slot.id
    await db.commit()
    await db.refresh(slot)
    return slot


def slot_label(slot: ParkingSlot) -> str:
    return f"Tower {slot.tower} · Floor {slot.floor} · Zone {slot.zone} · Slot {slot.slot_number}"


# Hourly (non-subscriber) gate passes expire after two hours.
QR_PASS_TTL = timedelta(hours=2)


async def issue_qr_for_user(db: AsyncSession, user: User, *, rotate: bool = False) -> QrAccess:
    sub = await get_active_subscription(db, user.id)

    vehicle = await db.scalar(
        select(Vehicle)
        .where(Vehicle.user_id == user.id)
        .order_by(Vehicle.is_default.desc(), Vehicle.created_at.desc())
        .limit(1)
    )
    if vehicle is None:
        raise AppError("Register a vehicle before generating QR")

    slot = await allocate_slot_for_user(db, user)

    # Subscribers keep a permanent QR; hourly passes expire after 2 hours.
    is_permanent = has_active_plan(sub)

    if not rotate:
        current = await current_qr(db, user)
        if current is not None:
            if is_permanent and current.is_permanent:
                return current
            if not is_permanent and not current.is_permanent:
                return current

    existing = await db.scalars(
        select(QrAccess).where(
            QrAccess.user_id == user.id,
            QrAccess.revoked.is_(False),
        )
    )
    for row in existing:
        if not row.is_permanent or rotate or not is_permanent:
            row.revoked = True

    ttl = timedelta(days=365) if is_permanent else QR_PASS_TTL
    expires_at = utcnow() + ttl
    payload = {
        "uid": user.id,
        "vid": vehicle.id,
        "sid": slot.id,
        "sub": sub.id if sub else None,
        "plate": vehicle.number_plate,
        "billing": sub.plan_type if sub else "hourly",
    }
    token = seal_qr_payload(payload, ttl)
    access = QrAccess(
        id=new_id("qr"),
        user_id=user.id,
        vehicle_id=vehicle.id,
        subscription_id=sub.id if sub else None,
        parking_slot_id=slot.id,
        token_hash=token_hash(token),
        token_cipher=token,
        is_permanent=is_permanent,
        expires_at=expires_at,
    )
    db.add(access)
    await db.commit()
    await db.refresh(access)
    return access


async def revoke_non_permanent_qr(db: AsyncSession, user_id: str) -> None:
    """Invalidate hourly/visit QR after exit. Permanent subscription QR stays."""
    rows = await db.scalars(
        select(QrAccess).where(
            QrAccess.user_id == user_id,
            QrAccess.revoked.is_(False),
            QrAccess.is_permanent.is_(False),
        )
    )
    for row in rows:
        row.revoked = True


async def current_qr(db: AsyncSession, user: User) -> QrAccess | None:
    rows = await db.scalars(
        select(QrAccess)
        .where(
            QrAccess.user_id == user.id,
            QrAccess.revoked.is_(False),
        )
        .order_by(QrAccess.created_at.desc())
    )
    now = utcnow()
    for row in rows:
        if as_utc(row.expires_at) > now:
            return row
    return None
