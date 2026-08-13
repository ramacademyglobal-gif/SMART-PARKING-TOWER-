from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import STAFF_ROLES, get_current_user
from app.core.config import get_settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_value,
    new_id,
    utcnow,
    verify_hash,
    verify_password,
    as_utc,
)
from app.core.exceptions import UnauthorizedError
from app.db.models import RefreshToken, User
from app.db.session import get_db
from app.schemas.common import (
    AuthSessionOut,
    FirebaseLoginIn,
    MessageOut,
    RefreshIn,
    SendOtpIn,
    StaffLoginIn,
    UserOut,
    VerifyOtpIn,
)
from app.services.firebase_auth import phone_from_firebase_claims, verify_firebase_id_token
from app.services.otp import create_and_send_otp, normalize_phone, verify_otp_code

router = APIRouter(prefix="/auth", tags=["auth"])


def _user_out(user: User) -> UserOut:
    return UserOut.model_validate(user)


async def _issue_session(db: AsyncSession, user: User, *, is_new_user: bool) -> AuthSessionOut:
    access = create_access_token(user.id, extra={"role": user.role})
    refresh = create_refresh_token(user.id)
    payload = decode_token(refresh)
    db.add(
        RefreshToken(
            id=new_id("rt"),
            user_id=user.id,
            token_hash=hash_value(refresh),
            expires_at=utcnow()
            + timedelta(days=30),
        )
    )
    await db.commit()
    return AuthSessionOut(
        access_token=access,
        refresh_token=refresh,
        user=_user_out(user),
        is_new_user=is_new_user,
    )


@router.post("/send-otp", response_model=MessageOut)
async def send_otp(body: SendOtpIn, db: AsyncSession = Depends(get_db)) -> MessageOut:
    settings = get_settings()
    request_id = await create_and_send_otp(db, body.phone)
    if settings.otp_dev_mode:
        return MessageOut(message="OTP sent. Use 123456 to verify (dev mode).")
    return MessageOut(
        message="OTP sent successfully. If SMS does not arrive, check MSG91 OTP → Logs.",
        request_id=request_id,
    )


@router.post("/verify-otp", response_model=AuthSessionOut)
async def verify_otp(body: VerifyOtpIn, db: AsyncSession = Depends(get_db)) -> AuthSessionOut:
    phone = normalize_phone(body.phone)
    await verify_otp_code(db, phone, body.otp)

    user = await db.scalar(select(User).where(User.phone == phone))
    is_new_user = user is None
    if user is None:
        user = User(
            id=new_id("user"),
            phone=phone,
            display_name=f"User {phone[-4:]}",
            role="user",
            member_since=utcnow(),
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return await _issue_session(db, user, is_new_user=is_new_user)


@router.post("/firebase", response_model=AuthSessionOut)
async def firebase_login(
    body: FirebaseLoginIn,
    db: AsyncSession = Depends(get_db),
) -> AuthSessionOut:
    """Create/restore a parking-app session after Firebase Phone Auth succeeds."""
    claims = await verify_firebase_id_token(body.id_token)
    phone = phone_from_firebase_claims(claims, body.phone)
    if len(phone) != 10:
        raise UnauthorizedError("Firebase token did not include a valid phone number")

    user = await db.scalar(select(User).where(User.phone == phone))
    is_new_user = user is None
    if user is None:
        user = User(
            id=new_id("user"),
            phone=phone,
            display_name=f"User {phone[-4:]}",
            role="user",
            member_since=utcnow(),
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return await _issue_session(db, user, is_new_user=is_new_user)


@router.post("/staff/login", response_model=AuthSessionOut)
async def staff_login(body: StaffLoginIn, db: AsyncSession = Depends(get_db)) -> AuthSessionOut:
    """Username + password sign-in for gate staff and admins."""
    username = body.username.strip().lower()
    account = await db.scalar(select(User).where(User.username == username))

    # Same message for unknown user, wrong password and non-staff role so the
    # endpoint cannot be used to enumerate accounts.
    invalid = UnauthorizedError("Invalid username or password")
    if account is None or not account.password_hash:
        raise invalid
    if not verify_password(body.password, account.password_hash):
        raise invalid
    if account.role not in STAFF_ROLES:
        raise invalid

    return await _issue_session(db, account, is_new_user=False)


@router.post("/refresh", response_model=AuthSessionOut)
async def refresh(body: RefreshIn, db: AsyncSession = Depends(get_db)) -> AuthSessionOut:
    try:
        payload = decode_token(body.refresh_token)
    except ValueError as exc:
        raise UnauthorizedError(str(exc)) from exc
    if payload.get("type") != "refresh":
        raise UnauthorizedError("Invalid refresh token")

    user_id = payload.get("sub")
    tokens = await db.scalars(
        select(RefreshToken).where(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked.is_(False),
        )
    )
    matched = None
    for row in tokens:
        if verify_hash(body.refresh_token, row.token_hash):
            matched = row
            break
    if matched is None or as_utc(matched.expires_at) < utcnow():
        raise UnauthorizedError("Refresh token expired or revoked")

    matched.revoked = True
    user = await db.get(User, user_id)
    if user is None:
        raise UnauthorizedError("User not found")
    await db.commit()
    return await _issue_session(db, user, is_new_user=False)


@router.post("/logout", response_model=MessageOut)
async def logout(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    tokens = await db.scalars(
        select(RefreshToken).where(
            RefreshToken.user_id == user.id,
            RefreshToken.revoked.is_(False),
        )
    )
    for row in tokens:
        row.revoked = True
    await db.commit()
    return MessageOut(message="Logged out")
