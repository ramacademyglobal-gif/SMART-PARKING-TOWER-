from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from uuid import uuid4
import hashlib
import hmac
import secrets

from jose import JWTError, jwt

from app.core.config import get_settings

ALGORITHM = "HS256"


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(dt: datetime) -> datetime:
    """Normalize SQLite-naive datetimes to aware UTC for comparisons."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def new_id(prefix: str = "") -> str:
    value = uuid4().hex
    return f"{prefix}_{value}" if prefix else value


def hash_value(value: str) -> str:
    """Salted SHA-256 hash for OTP / refresh tokens."""
    salt = secrets.token_hex(16)
    digest = hashlib.sha256(f"{salt}:{value}".encode("utf-8")).hexdigest()
    return f"{salt}${digest}"


def verify_hash(plain: str, hashed: str) -> bool:
    try:
        salt, digest = hashed.split("$", 1)
    except ValueError:
        return False
    check = hashlib.sha256(f"{salt}:{plain}".encode("utf-8")).hexdigest()
    return hmac.compare_digest(check, digest)


PBKDF2_SCHEME = "pbkdf2_sha256"
PBKDF2_ITERATIONS = 240_000


def hash_password(password: str) -> str:
    """PBKDF2-HMAC-SHA256 for staff passwords, which are long-lived at rest."""
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PBKDF2_ITERATIONS)
    return f"{PBKDF2_SCHEME}${PBKDF2_ITERATIONS}${salt.hex()}${digest.hex()}"


def verify_password(password: str, hashed: str) -> bool:
    try:
        scheme, iterations, salt_hex, digest_hex = hashed.split("$")
        if scheme != PBKDF2_SCHEME:
            return False
        check = hashlib.pbkdf2_hmac(
            "sha256", password.encode("utf-8"), bytes.fromhex(salt_hex), int(iterations)
        )
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(check.hex(), digest_hex)


def create_access_token(subject: str, extra: Optional[dict[str, Any]] = None) -> str:
    settings = get_settings()
    payload: dict[str, Any] = {
        "sub": subject,
        "type": "access",
        "exp": utcnow() + timedelta(minutes=settings.jwt_access_expire_minutes),
        "iat": utcnow(),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def create_refresh_token(subject: str) -> str:
    settings = get_settings()
    payload = {
        "sub": subject,
        "type": "refresh",
        "jti": new_id("jti"),
        "exp": utcnow() + timedelta(days=settings.jwt_refresh_expire_days),
        "iat": utcnow(),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise ValueError("Invalid or expired token") from exc
