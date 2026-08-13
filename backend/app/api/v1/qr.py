from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.exceptions import NotFoundError
from app.db.models import ParkingSlot, User, Vehicle
from app.db.session import get_db
from app.schemas.common import QrOut
from app.services.allocation import (
    current_qr,
    get_active_subscription,
    issue_qr_for_user,
    slot_label,
)

router = APIRouter(prefix="/qr", tags=["qr"])


async def _to_qr_out(db: AsyncSession, user: User, access) -> QrOut:
    sub = await get_active_subscription(db, user.id)
    slot = await db.get(ParkingSlot, access.parking_slot_id) if access.parking_slot_id else None
    vehicle = await db.get(Vehicle, access.vehicle_id) if access.vehicle_id else None
    return QrOut(
        token=access.token_cipher,
        user_name=user.display_name,
        vehicle_number=vehicle.number_plate if vehicle else "",
        slot_label=slot_label(slot) if slot else "Unassigned",
        subscription_type=sub.plan_type if sub else "hourly",
        expires_at=access.expires_at,
        is_permanent=access.is_permanent,
    )


@router.get("/current", response_model=QrOut | None)
async def get_current(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> QrOut | None:
    """Return the active pass only — never mint a new QR here.

    Hourly passes are revoked on exit, so this returns null until the member
    explicitly books again (POST /qr/refresh). Permanent subscription QRs stay.
    """
    access = await current_qr(db, user)
    if access is None:
        return None
    return await _to_qr_out(db, user, access)


@router.post("/refresh", response_model=QrOut)
async def refresh(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> QrOut:
    access = await issue_qr_for_user(db, user, rotate=True)
    return await _to_qr_out(db, user, access)
