from __future__ import annotations

import re

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.exceptions import AppError, ConflictError, NotFoundError
from app.core.security import new_id, utcnow
from app.db.models import User, Vehicle
from app.db.session import get_db
from app.schemas.common import VehicleIn, VehicleOut

router = APIRouter(prefix="/vehicles", tags=["vehicles"])

PLATE_RE = re.compile(r"^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$")


def _normalize_plate(value: str) -> str:
    plate = re.sub(r"[\s-]", "", (value or "").upper())
    if not PLATE_RE.match(plate):
        raise AppError("Enter a valid number, e.g. MH12AB1234")
    return plate


@router.get("", response_model=list[VehicleOut])
async def list_vehicles(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[VehicleOut]:
    rows = await db.scalars(
        select(Vehicle)
        .where(Vehicle.user_id == user.id)
        .order_by(Vehicle.is_default.desc(), Vehicle.created_at.desc())
    )
    return [VehicleOut.model_validate(v) for v in rows]


@router.post("", response_model=VehicleOut, status_code=status.HTTP_201_CREATED)
async def add_vehicle(
    body: VehicleIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VehicleOut:
    plate = _normalize_plate(body.number_plate)
    exists = await db.scalar(
        select(Vehicle).where(Vehicle.user_id == user.id, Vehicle.number_plate == plate)
    )
    if exists:
        raise ConflictError("Vehicle with this number plate already exists")

    count = await db.scalar(
        select(func.count()).select_from(Vehicle).where(Vehicle.user_id == user.id)
    )
    make_default = body.is_default or (count or 0) == 0

    if make_default:
        current = await db.scalars(select(Vehicle).where(Vehicle.user_id == user.id))
        for row in current:
            row.is_default = False

    vehicle = Vehicle(
        id=new_id("veh"),
        user_id=user.id,
        number_plate=plate,
        make=(body.make or None),
        model=(body.model or None),
        color=(body.color or None),
        is_default=make_default,
        created_at=utcnow(),
    )
    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)
    return VehicleOut.model_validate(vehicle)


@router.put("/{vehicle_id}", response_model=VehicleOut)
async def update_vehicle(
    vehicle_id: str,
    body: VehicleIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VehicleOut:
    vehicle = await db.get(Vehicle, vehicle_id)
    if vehicle is None or vehicle.user_id != user.id:
        raise NotFoundError("Vehicle not found")
    vehicle.number_plate = _normalize_plate(body.number_plate)
    vehicle.make = body.make
    vehicle.model = body.model
    vehicle.color = body.color
    await db.commit()
    await db.refresh(vehicle)
    return VehicleOut.model_validate(vehicle)


@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def delete_vehicle(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Response:
    vehicle = await db.get(Vehicle, vehicle_id)
    if vehicle is None or vehicle.user_id != user.id:
        raise NotFoundError("Vehicle not found")
    was_default = vehicle.is_default
    await db.delete(vehicle)
    await db.flush()
    if was_default:
        next_vehicle = await db.scalar(
            select(Vehicle)
            .where(Vehicle.user_id == user.id)
            .order_by(Vehicle.created_at.desc())
            .limit(1)
        )
        if next_vehicle:
            next_vehicle.is_default = True
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{vehicle_id}/default", response_model=VehicleOut)
async def set_default(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VehicleOut:
    vehicle = await db.get(Vehicle, vehicle_id)
    if vehicle is None or vehicle.user_id != user.id:
        raise NotFoundError("Vehicle not found")
    others = await db.scalars(select(Vehicle).where(Vehicle.user_id == user.id))
    for row in others:
        row.is_default = row.id == vehicle.id
    await db.commit()
    await db.refresh(vehicle)
    return VehicleOut.model_validate(vehicle)
