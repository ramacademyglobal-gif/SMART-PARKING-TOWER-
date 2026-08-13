from __future__ import annotations

import base64
import hashlib
import json
from datetime import datetime, timedelta
from typing import Any

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import get_settings
from app.core.security import as_utc, utcnow


def _fernet() -> Fernet:
    settings = get_settings()
    digest = hashlib.sha256(settings.qr_secret.encode("utf-8")).digest()
    key = base64.urlsafe_b64encode(digest)
    return Fernet(key)


def seal_qr_payload(payload: dict[str, Any], ttl: timedelta) -> str:
    body = {
        **payload,
        "exp": (utcnow() + ttl).isoformat(),
        "iat": utcnow().isoformat(),
    }
    raw = json.dumps(body, separators=(",", ":")).encode("utf-8")
    return _fernet().encrypt(raw).decode("utf-8")


def open_qr_payload(token: str) -> dict[str, Any]:
    cleaned = (token or "").strip()
    try:
        raw = _fernet().decrypt(cleaned.encode("utf-8"))
    except InvalidToken as exc:
        raise ValueError("Invalid QR token") from exc
    data = json.loads(raw.decode("utf-8"))
    exp = data.get("exp")
    if exp:
        try:
            exp_dt = as_utc(datetime.fromisoformat(str(exp)))
        except ValueError as exc:
            raise ValueError("Invalid QR token") from exc
        if utcnow() > exp_dt:
            raise ValueError("QR token expired")
    return data


def token_hash(token: str) -> str:
    return hashlib.sha256((token or "").strip().encode("utf-8")).hexdigest()
