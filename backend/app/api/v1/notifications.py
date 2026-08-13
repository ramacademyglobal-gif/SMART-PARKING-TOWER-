from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.exceptions import ForbiddenError, NotFoundError
from app.core.security import new_id
from app.db.models import (
    DeviceToken,
    AppNotification,
    User,
)
from app.db.session import get_db
from app.schemas.common import (
    FcmRegisterIn,
    GateValidateIn,
    GateValidateOut,
    MarkReadIn,
    MessageOut,
    NotificationOut,
)

notifications_router = APIRouter(prefix="/notifications", tags=["notifications"])
fcm_router = APIRouter(prefix="/fcm", tags=["fcm"])
gate_router = APIRouter(prefix="/gate", tags=["gate"])


@notifications_router.get("", response_model=list[NotificationOut])
async def list_notifications(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[NotificationOut]:
    rows = await db.scalars(
        select(AppNotification)
        .where(AppNotification.user_id == user.id)
        .order_by(AppNotification.created_at.desc())
    )
    out: list[NotificationOut] = []
    for row in rows:
        out.append(
            NotificationOut(
                id=row.id,
                title=row.title,
                body=row.body,
                type=row.type,
                created_at=row.created_at,
                is_read=row.is_read,
                data=json.loads(row.data_json or "{}"),
            )
        )
    return out


@notifications_router.post("/read", response_model=MessageOut)
async def mark_read(
    body: MarkReadIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    rows = await db.scalars(
        select(AppNotification).where(
            AppNotification.user_id == user.id,
            AppNotification.id.in_(body.ids) if body.ids else True,
        )
    )
    for row in rows:
        if not body.ids or row.id in body.ids:
            row.is_read = True
    await db.commit()
    return MessageOut(message="Notifications updated")


@fcm_router.post("/register", response_model=MessageOut)
async def register_fcm(
    body: FcmRegisterIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    existing = await db.scalar(
        select(DeviceToken).where(
            DeviceToken.user_id == user.id,
            DeviceToken.token == body.token,
        )
    )
    if existing is None:
        db.add(
            DeviceToken(
                id=new_id("fcm"),
                user_id=user.id,
                token=body.token,
                platform=body.platform,
            )
        )
        await db.commit()
    return MessageOut(message="FCM token registered")


@fcm_router.post("/unregister", response_model=MessageOut)
async def unregister_fcm(
    body: FcmRegisterIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    row = await db.scalar(
        select(DeviceToken).where(
            DeviceToken.user_id == user.id,
            DeviceToken.token == body.token,
        )
    )
    if row:
        await db.delete(row)
        await db.commit()
    return MessageOut(message="FCM token removed")


@gate_router.post("/validate", response_model=GateValidateOut)
async def validate_gate(
    body: GateValidateIn,
    x_gate_key: str | None = Header(default=None, alias="X-Gate-Key"),
    db: AsyncSession = Depends(get_db),
) -> GateValidateOut:
    settings = get_settings()
    if x_gate_key != settings.gate_api_key:
        raise ForbiddenError("Invalid gate API key")

    from app.services.gate import process_gate_scan

    return await process_gate_scan(db, token=body.token, action=body.action)
