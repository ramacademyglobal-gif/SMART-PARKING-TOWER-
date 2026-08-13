from __future__ import annotations

import asyncio
from typing import Any

from google.auth.transport import requests
from google.oauth2 import id_token

from app.core.config import get_settings
from app.core.exceptions import UnauthorizedError
from app.services.otp import normalize_phone

# Reuse one Request so Google certs are cached after the first verify / warm-up.
_GOOGLE_REQUEST = requests.Request()
_CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)


def warm_firebase_certs() -> None:
    """Prefetch Firebase ID-token certificates so the first login is not slow."""
    try:
        _GOOGLE_REQUEST(url=_CERTS_URL, method="GET")
    except Exception:  # noqa: BLE001 — best-effort warm-up
        pass


def verify_firebase_id_token_sync(token: str) -> dict[str, Any]:
    """Validate a Firebase ID token and return its claims (blocking)."""
    settings = get_settings()
    project_id = (settings.firebase_project_id or "").strip()
    if not project_id:
        raise UnauthorizedError("Firebase project is not configured on the server")

    try:
        claims = id_token.verify_firebase_token(
            token,
            _GOOGLE_REQUEST,
            audience=project_id,
        )
    except Exception as exc:  # noqa: BLE001 — surface as auth failure
        raise UnauthorizedError("Invalid or expired Firebase token") from exc

    if not claims or claims.get("aud") != project_id:
        raise UnauthorizedError("Invalid Firebase token audience")
    return claims


async def verify_firebase_id_token(token: str) -> dict[str, Any]:
    """Async wrapper — Google cert verify is sync and must not block the event loop."""
    return await asyncio.to_thread(verify_firebase_id_token_sync, token)


def phone_from_firebase_claims(claims: dict[str, Any], fallback: str | None = None) -> str:
    """Extract a 10-digit Indian phone from Firebase claims or the client fallback."""
    raw = (claims.get("phone_number") or fallback or "").strip()
    # Firebase stores E.164 like +919876543210
    if raw.startswith("+91"):
        raw = raw[3:]
    elif raw.startswith("91") and len(raw) == 12:
        raw = raw[2:]
    return normalize_phone(raw)
