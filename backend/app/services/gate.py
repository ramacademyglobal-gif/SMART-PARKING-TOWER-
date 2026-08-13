from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import as_utc, new_id, utcnow
from app.db.models import ParkingHistory, ParkingSlot, QrAccess, User, Vehicle
from app.schemas.common import GateValidateOut
from app.services.allocation import (
    get_active_subscription,
    has_active_plan,
    revoke_non_permanent_qr,
    slot_label,
)
from app.services.billing import calculate_hourly_charge_paise, format_duration
from app.services.notifications import push_notification
from app.services.qr_crypto import open_qr_payload, token_hash


async def _free_standard_slot(db: AsyncSession) -> ParkingSlot | None:
    return await db.scalar(
        select(ParkingSlot)
        .where(
            ParkingSlot.is_premium.is_(False),
            ParkingSlot.is_occupied.is_(False),
            ParkingSlot.assigned_user_id.is_(None),
        )
        .order_by(ParkingSlot.floor, ParkingSlot.zone, ParkingSlot.slot_number)
        .limit(1)
    )


async def _free_premium_row_slot(db: AsyncSession) -> ParkingSlot | None:
    """Prefer premium Zone A on floors 1–3, then any premium, then any free."""
    from app.services.allocation import SUBSCRIBER_FLOORS

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
    if slot is not None:
        return slot
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
    if slot is not None:
        return slot
    return await db.scalar(
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


async def process_gate_scan(
    db: AsyncSession,
    *,
    token: str,
    action: str = "auto",
    staff_id: str | None = None,
) -> GateValidateOut:
    """Validate a QR token and record entry or exit.

    ``action`` may be ``entry``, ``exit``, or ``auto`` (exit if a parked
    session exists for the QR owner, otherwise entry).
    """
    settings = get_settings()
    cleaned = (token or "").strip()
    try:
        payload = open_qr_payload(cleaned)
    except ValueError as exc:
        return GateValidateOut(valid=False, message=str(exc), action=None)

    digest = token_hash(cleaned)
    access = await db.scalar(
        select(QrAccess).where(
            QrAccess.token_hash == digest,
            QrAccess.revoked.is_(False),
        )
    )
    if access is None:
        # Fall back to cipher match (handles rare hash/encoding mismatches) and
        # distinguish revoked vs unknown so staff see a clear reason.
        access = await db.scalar(
            select(QrAccess).where(
                QrAccess.token_cipher == cleaned,
                QrAccess.revoked.is_(False),
            )
        )
    if access is None:
        revoked = await db.scalar(
            select(QrAccess).where(
                or_(
                    QrAccess.token_hash == digest,
                    QrAccess.token_cipher == cleaned,
                ),
                QrAccess.revoked.is_(True),
            )
        )
        if revoked is not None:
            msg = (
                "This visit QR is no longer valid after exit. Ask the member to book a new slot."
                if not revoked.is_permanent
                else "QR was refreshed. Ask the member to show the latest code."
            )
            return GateValidateOut(
                valid=False,
                message=msg,
            )
        return GateValidateOut(valid=False, message="QR is unknown or invalid")

    if as_utc(access.expires_at) < utcnow():
        return GateValidateOut(valid=False, message="QR has expired. Ask the member to refresh.")

    user = await db.get(User, payload.get("uid"))
    vehicle = await db.get(Vehicle, payload.get("vid"))
    slot = await db.get(ParkingSlot, payload.get("sid"))
    if user is None or vehicle is None or slot is None:
        return GateValidateOut(valid=False, message="QR references missing records")

    sub = await get_active_subscription(db, user.id)
    billing_type = sub.plan_type if sub else "hourly"

    open_session = await db.scalar(
        select(ParkingHistory)
        .where(
            ParkingHistory.user_id == user.id,
            ParkingHistory.status == "parked",
        )
        .order_by(ParkingHistory.entry_at.desc())
        .limit(1)
    )

    resolved = action.lower().strip()
    if resolved in {"", "auto"}:
        resolved = "exit" if open_session is not None else "entry"

    if resolved == "entry":
        if open_session is not None:
            return GateValidateOut(
                valid=False,
                message=f"{vehicle.number_plate} is already parked at {open_session.slot_number}",
                vehicle_number=vehicle.number_plate,
                slot_label=slot_label(slot),
                user_name=user.display_name,
                user_phone=user.phone,
                subscription_type=billing_type,
                entry_at=open_session.entry_at,
                history_id=open_session.id,
                action="entry",
            )

        if slot.is_occupied and slot.assigned_user_id != user.id:
            # The bay on the pass was taken since the QR was issued.
            replacement = (
                await _free_premium_row_slot(db)
                if has_active_plan(sub)
                else await _free_standard_slot(db)
            )
            if replacement is None:
                return GateValidateOut(
                    valid=False,
                    message="Tower is full. No bay available right now.",
                    vehicle_number=vehicle.number_plate,
                    user_name=user.display_name,
                    action="entry",
                )
            slot = replacement
            access.parking_slot_id = slot.id

        now = utcnow()
        slot.is_occupied = True
        slot.assigned_user_id = user.id
        history = ParkingHistory(
            id=new_id("hist"),
            user_id=user.id,
            vehicle_number=vehicle.number_plate,
            entry_at=now,
            tower=slot.tower,
            floor=slot.floor,
            zone=slot.zone,
            slot_number=slot.slot_number,
            parking_slot_id=slot.id,
            subscription_type=billing_type,
            billing_type=billing_type,
            status="parked",
            created_by_staff_id=staff_id,
        )
        db.add(history)
        await db.commit()
        await push_notification(
            db,
            user_id=user.id,
            title="Vehicle entered",
            body=f"{vehicle.number_plate} parked at {slot_label(slot)}.",
            type_="parking",
            data={"historyId": history.id, "action": "entry"},
        )
        return GateValidateOut(
            valid=True,
            message=f"ENTRY · Allotted slot {slot_label(slot)}",
            vehicle_number=vehicle.number_plate,
            slot_label=slot_label(slot),
            entry_at=now,
            billing_type=billing_type,
            hourly_rate_rupees=settings.hourly_rate_paise / 100.0,
            history_id=history.id,
            payment_status="free",
            action="entry",
            user_name=user.display_name,
            user_phone=user.phone,
            subscription_type=billing_type,
            tower=slot.tower,
            floor=slot.floor,
            zone=slot.zone,
            slot_number=slot.slot_number,
        )

    if resolved == "exit":
        session = open_session
        if session is None:
            return GateValidateOut(
                valid=False,
                message="No active parking session for this pass",
                vehicle_number=vehicle.number_plate,
                slot_label=slot_label(slot),
                user_name=user.display_name,
                user_phone=user.phone,
                action="exit",
            )

        # Free the bay the car actually occupies, not the one printed on the pass.
        occupied_slot = slot
        if session.parking_slot_id:
            occupied_slot = await db.get(ParkingSlot, session.parking_slot_id) or slot

        now = utcnow()
        duration_seconds = int((now - as_utc(session.entry_at)).total_seconds())
        session.exit_at = now
        session.duration_seconds = duration_seconds
        session.status = "completed"
        session.closed_by_staff_id = staff_id

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

        occupied_slot.is_occupied = False
        # No permanent bay for anyone — free the assignment on exit.
        # Premium users only get preferential rows on the next booking.
        occupied_slot.assigned_user_id = None
        if sub is not None:
            sub.parking_slot_id = None

        # Hourly / visit QR becomes invalid after exit; subscription QR stays.
        await revoke_non_permanent_qr(db, user.id)

        await db.commit()

        amount_rupees = amount_paise / 100.0
        duration_label = format_duration(duration_seconds)
        if amount_paise > 0:
            message = (
                f"EXIT · {vehicle.number_plate} · "
                f"{duration_label} · ₹{amount_rupees:.0f} due"
            )
            await push_notification(
                db,
                user_id=user.id,
                title="Parking payment due",
                body=(
                    f"{vehicle.number_plate} exited · {duration_label} · "
                    f"₹{amount_rupees:.0f}. Pay now on Home."
                ),
                type_="billing",
                data={
                    "historyId": session.id,
                    "amountInPaise": amount_paise,
                    "action": "pay_parking",
                },
            )
        else:
            message = f"EXIT · Covered by your {billing_type} plan"
            await push_notification(
                db,
                user_id=user.id,
                title="Exit complete",
                body=f"{vehicle.number_plate} exited · covered by your plan.",
                type_="parking",
                data={"historyId": session.id, "action": "exit"},
            )

        return GateValidateOut(
            valid=True,
            message=message,
            vehicle_number=vehicle.number_plate,
            slot_label=slot_label(occupied_slot),
            entry_at=session.entry_at,
            exit_at=now,
            duration_seconds=duration_seconds,
            duration_label=duration_label,
            amount_in_paise=amount_paise,
            amount_rupees=amount_rupees,
            billing_type=session.billing_type,
            hourly_rate_rupees=settings.hourly_rate_paise / 100.0,
            history_id=session.id,
            payment_status=session.payment_status,
            action="exit",
            user_name=user.display_name,
            user_phone=user.phone,
            subscription_type=session.billing_type,
            tower=occupied_slot.tower,
            floor=occupied_slot.floor,
            zone=occupied_slot.zone,
            slot_number=occupied_slot.slot_number,
        )

    return GateValidateOut(
        valid=False,
        message="action must be entry, exit, or auto",
    )
