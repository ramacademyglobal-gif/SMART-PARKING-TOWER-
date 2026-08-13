from __future__ import annotations

import json

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import hash_password, new_id, utcnow, verify_password
from app.db.models import ParkingSlot, Plan, QrAccess, Subscription, User

# Tower A production inventory: 11 floors × 100 bays = 1100.
#
# Naming: id = slot_a{floor:02d}{zone}{nn}  e.g. slot_a01a01, slot_a11e20
# Display: Tower A · Floor N · Zone X · Slot X-NN
#
# Per floor (100): zones A–E × 20 bays (A-01…A-20 … E-01…E-20).
# Premium (~20%): Zone A on every floor → 20 × 11 = 220 (subscriber preference).
# Standard (~80%): Zones B–E → 80 × 11 = 880 (hourly + overflow).
# Allocation does NOT permanently reserve a bay for the plan duration —
# subscribers get preferential premium rows, freed on exit.
TOWER_ID = "A"
FLOORS = 11
SLOTS_PER_FLOOR = 100
ZONES = ("A", "B", "C", "D", "E")
SLOTS_PER_ZONE = 20  # 5 zones × 20 = 100 per floor
PREMIUM_ZONES = ("A",)  # Zone A only
PREMIUM_SLOTS = FLOORS * SLOTS_PER_ZONE * len(PREMIUM_ZONES)  # 220
STANDARD_SLOTS = FLOORS * SLOTS_PER_FLOOR - PREMIUM_SLOTS  # 880
EXPECTED_SLOT_COUNT = PREMIUM_SLOTS + STANDARD_SLOTS  # 1100

_MONTHLY_FEATURES = [
    "Preferential premium bay (Zone A, floors 1–3)",
    "Permanent QR access pass",
    "QR entry & exit",
    "SMS alerts",
    "Parking history",
]
_ANNUAL_FEATURES = [
    "Preferential premium bay (Zone A, floors 1–3)",
    "Permanent QR access pass",
    "Priority tower access",
    "Push & SMS alerts",
    "Dedicated support",
]


async def _upsert_staff(
    db: AsyncSession, *, username: str, password: str, display_name: str, role: str
) -> None:
    username = username.strip().lower()
    if not username or not password:
        return

    account = await db.scalar(select(User).where(User.username == username))
    if account is None:
        db.add(
            User(
                id=new_id("user"),
                phone=None,
                username=username,
                password_hash=hash_password(password),
                display_name=display_name,
                role=role,
                member_since=utcnow(),
            )
        )
        return

    # Keep the row in sync with .env so rotating the password there is enough.
    account.role = role
    account.display_name = display_name
    if not account.password_hash or not verify_password(password, account.password_hash):
        account.password_hash = hash_password(password)


async def seed_staff_accounts(db: AsyncSession) -> None:
    """Provision the console logins so a fresh database is usable immediately."""
    settings = get_settings()
    await _upsert_staff(
        db,
        username=settings.staff_username,
        password=settings.staff_password,
        display_name=settings.staff_display_name,
        role="staff",
    )
    await _upsert_staff(
        db,
        username=settings.admin_username,
        password=settings.admin_password,
        display_name=settings.admin_display_name,
        role="admin",
    )
    await db.commit()


def _build_inventory() -> list[ParkingSlot]:
    """Build the full 1100-slot Tower A inventory."""
    slots: list[ParkingSlot] = []
    for floor in range(1, FLOORS + 1):
        for zone in ZONES:
            is_premium = zone in PREMIUM_ZONES
            for num in range(1, SLOTS_PER_ZONE + 1):
                slots.append(
                    ParkingSlot(
                        id=f"slot_a{floor:02d}{zone.lower()}{num:02d}",
                        tower=TOWER_ID,
                        floor=floor,
                        zone=zone,
                        slot_number=f"{zone}-{num:02d}",
                        is_premium=is_premium,
                        is_occupied=False,
                    )
                )
    return slots


async def seed_reference_data(db: AsyncSession, *, force_slots: bool = False) -> None:
    plans = await db.scalar(select(Plan).limit(1))
    if plans is None:
        db.add_all(
            [
                Plan(
                    id="plan_monthly",
                    type="monthly",
                    name="Monthly Flex",
                    price_in_paise=99900,
                    duration_days=30,
                    features_json=json.dumps(_MONTHLY_FEATURES),
                    is_premium=False,
                ),
                Plan(
                    id="plan_annual",
                    type="annual",
                    name="Annual Premium",
                    price_in_paise=999900,
                    duration_days=365,
                    features_json=json.dumps(_ANNUAL_FEATURES),
                    is_premium=True,
                ),
            ]
        )
    else:
        # Keep feature copy aligned with allocation (preferential, not permanent bay).
        for plan_id, features in (
            ("plan_monthly", _MONTHLY_FEATURES),
            ("plan_annual", _ANNUAL_FEATURES),
        ):
            plan = await db.get(Plan, plan_id)
            if plan is not None:
                plan.features_json = json.dumps(features)

    slot_count = await db.scalar(select(func.count()).select_from(ParkingSlot)) or 0
    if force_slots or slot_count == 0 or slot_count != EXPECTED_SLOT_COUNT:
        # Clear FK references before replacing inventory.
        subs = await db.scalars(select(Subscription).where(Subscription.parking_slot_id.is_not(None)))
        for sub in subs:
            sub.parking_slot_id = None
        qrs = await db.scalars(select(QrAccess).where(QrAccess.parking_slot_id.is_not(None)))
        for qr in qrs:
            qr.parking_slot_id = None
        await db.execute(delete(ParkingSlot))
        slots = _build_inventory()
        assert len(slots) == EXPECTED_SLOT_COUNT
        db.add_all(slots)

    await db.commit()
