from __future__ import annotations

import json
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import new_id, utcnow
from app.db.models import AppNotification


async def push_notification(
    db: AsyncSession,
    *,
    user_id: str,
    title: str,
    body: str,
    type_: str = "general",
    data: dict[str, Any] | None = None,
) -> AppNotification:
    note = AppNotification(
        id=new_id("notif"),
        user_id=user_id,
        title=title,
        body=body,
        type=type_,
        data_json=json.dumps(data or {}),
        created_at=utcnow(),
    )
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return note
