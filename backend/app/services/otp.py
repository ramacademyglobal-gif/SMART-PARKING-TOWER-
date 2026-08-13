from __future__ import annotations

import hashlib
import re
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppError
from app.core.security import hash_value, new_id, utcnow, verify_hash, as_utc
from app.db.models import OtpChallenge
from app.services.msg91 import send_otp_sms

PHONE_RE = re.compile(r"^[6-9]\d{9}$")


def normalize_phone(raw: str) -> str:
    digits = re.sub(r"\D", "", raw or "")
    if len(digits) > 10:
        digits = digits[-10:]
    if digits.startswith("0") and len(digits) == 11:
        digits = digits[1:]
    if not PHONE_RE.match(digits):
        raise AppError("Enter a valid 10-digit Indian mobile number")
    return digits


def _sha(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


async def create_and_send_otp(db: AsyncSession, phone: str) -> str | None:
    """Create an OTP challenge and optionally SMS it via MSG91.

    Returns the MSG91 ``request_id`` when a live SMS was submitted, else None.
    Resend / hourly limits are disabled so local testing is never blocked.
    """
    settings = get_settings()
    phone = normalize_phone(phone)
    now = utcnow()

    code = "123456" if (settings.otp_dev_mode or not settings.msg91_enabled) else _random_otp(
        settings.otp_length
    )
    challenge = OtpChallenge(
        id=new_id("otp"),
        phone=phone,
        code_hash=hash_value(code),
        expires_at=now + timedelta(seconds=settings.otp_expiry_seconds),
    )
    db.add(challenge)
    await db.commit()

    if settings.msg91_enabled:
        return await send_otp_sms(phone, code)
    return None


def _random_otp(length: int) -> str:
    import secrets

    return "".join(str(secrets.randbelow(10)) for _ in range(length))


async def verify_otp_code(db: AsyncSession, phone: str, otp: str) -> bool:
    settings = get_settings()
    phone = normalize_phone(phone)
    otp = (otp or "").strip()
    if len(otp) != settings.otp_length or not otp.isdigit():
        raise AppError("Enter a valid OTP")

    challenge = await db.scalar(
        select(OtpChallenge)
        .where(
            OtpChallenge.phone == phone,
            OtpChallenge.consumed.is_(False),
        )
        .order_by(OtpChallenge.created_at.desc())
        .limit(1)
    )
    if challenge is None:
        if settings.otp_dev_mode and otp == "123456":
            return True
        raise AppError("OTP expired or not found. Request a new code.")

    if as_utc(challenge.expires_at) < utcnow():
        raise AppError("OTP expired. Request a new code.")

    ok = verify_hash(otp, challenge.code_hash) or (
        settings.otp_dev_mode and otp == "123456"
    )
    challenge.attempts += 1
    if not ok:
        await db.commit()
        raise AppError("Invalid OTP")

    challenge.consumed = True
    await db.commit()
    return True
