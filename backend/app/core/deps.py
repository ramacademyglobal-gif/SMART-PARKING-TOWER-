from __future__ import annotations

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.security import decode_token
from app.db.models import User
from app.db.session import get_db

bearer = HTTPBearer(auto_error=False)

STAFF_ROLES = frozenset({"staff", "admin"})


async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    if creds is None or not creds.credentials:
        raise UnauthorizedError()
    try:
        payload = decode_token(creds.credentials)
    except ValueError as exc:
        raise UnauthorizedError(str(exc)) from exc
    if payload.get("type") != "access":
        raise UnauthorizedError("Invalid access token")
    user_id = payload.get("sub")
    if not user_id:
        raise UnauthorizedError()
    user = await db.get(User, user_id)
    if user is None:
        raise UnauthorizedError("User not found")
    return user


async def get_optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    if creds is None:
        return None
    try:
        return await get_current_user(creds, db)
    except UnauthorizedError:
        return None


async def get_current_staff(user: User = Depends(get_current_user)) -> User:
    """Gate staff console access. Role is re-read from the row, not the token."""
    if user.role not in STAFF_ROLES:
        raise ForbiddenError("Staff access required")
    return user
