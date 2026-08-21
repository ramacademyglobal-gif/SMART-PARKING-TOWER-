from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import _ENV_FILE, get_settings
from app.db.models import ParkingSlot
from app.db.seed import EXPECTED_SLOT_COUNT, PREMIUM_SLOTS, STANDARD_SLOTS, TOWER_ID
from app.db.session import get_db
from app.schemas.common import PublicConfigOut

router = APIRouter(tags=["config"])


@router.get("/config", response_model=PublicConfigOut)
async def public_config(db: AsyncSession = Depends(get_db)) -> PublicConfigOut:
    """Public bootstrap config — no auth required. Never includes secrets."""
    get_settings.cache_clear()
    settings = get_settings()
    total = await db.scalar(select(func.count()).select_from(ParkingSlot)) or 0
    if total == 0:
        total = EXPECTED_SLOT_COUNT
        occupied = 0
        available = total
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
    return PublicConfigOut(
        otp_dev_mode=settings.otp_dev_mode,
        razorpay_key_id=settings.razorpay_key_id or "",
        razorpay_enabled=settings.razorpay_enabled,
        msg91_enabled=settings.msg91_enabled,
        env_file_loaded=_ENV_FILE.is_file(),
        tower_id=TOWER_ID,
        tower_name="MultiParking Tower A",
        total_slots=total,
        available_slots=available,
        occupied_slots=occupied,
        premium_slots=PREMIUM_SLOTS,
        standard_slots=STANDARD_SLOTS,
        hourly_rate_rupees=settings.hourly_rate_paise / 100.0,
        booking_fee_rupees=settings.booking_fee_paise / 100.0,
        booking_fee_paise=settings.booking_fee_paise,
    )
