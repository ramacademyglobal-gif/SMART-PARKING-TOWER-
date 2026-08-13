"""Probe MSG91 with the credentials in backend/.env.

Prints the exact HTTP status + body from both known OTP hosts so we can see
why the SMS never arrives (IP whitelist, bad template, wrong host, etc.).

Run: python scripts/probe_msg91.py [10-digit-phone]
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402


HOSTS = (
    "https://control.msg91.com/api/v5/otp",
    "https://api.msg91.com/api/v5/otp",
)


async def probe(phone: str) -> int:
    get_settings.cache_clear()
    settings = get_settings()
    print(f"auth_key set     : {bool(settings.msg91_auth_key)} ({len(settings.msg91_auth_key)} chars)")
    print(f"template_id      : {settings.msg91_template_id}")
    print(f"sender_id        : {settings.msg91_sender_id}")
    print(f"otp_dev_mode     : {settings.otp_dev_mode}")
    print(f"msg91_enabled    : {settings.msg91_enabled}")
    print(f"configured url   : {settings.msg91_flow_url}")
    print(f"target phone     : 91{phone}")
    print()

    params = {
        "template_id": settings.msg91_template_id,
        "mobile": f"91{phone}",
        "otp": "482913",
        "otp_length": "6",
        "otp_expiry": "5",
        "sender": settings.msg91_sender_id,
    }
    headers = {
        "authkey": settings.msg91_auth_key,
        "content-type": "application/json",
        "accept": "application/json",
    }

    ok = False
    async with httpx.AsyncClient(timeout=30) as client:
        for url in HOSTS:
            print(f"--- POST {url}")
            try:
                response = await client.post(url, params=params, headers=headers)
            except Exception as exc:  # noqa: BLE001
                print(f"transport error: {type(exc).__name__}: {exc}")
                print()
                continue
            print(f"status : {response.status_code}")
            print(f"body   : {response.text[:1000]}")
            print()
            if response.status_code < 400:
                try:
                    data = response.json()
                except Exception:
                    data = {}
                if isinstance(data, dict) and str(data.get("type", "")).lower() != "error":
                    ok = True

    return 0 if ok else 1


if __name__ == "__main__":
    phone = (sys.argv[1] if len(sys.argv) > 1 else "9043775875").strip()
    raise SystemExit(asyncio.run(probe(phone)))
