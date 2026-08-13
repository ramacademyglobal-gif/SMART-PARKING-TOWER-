"""Diagnose why SendOTP succeeds but dashboard Logs stay empty.

Tries the documented control.msg91.com form (authkey as query param) and
fetches OTP analytics if available.

Run: python scripts/probe_msg91_account.py [10-digit-phone]
"""

from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402


async def main(phone: str) -> int:
    get_settings.cache_clear()
    s = get_settings()
    key = s.msg91_auth_key
    print(f"auth_key length : {len(key)}")
    print(f"auth_key prefix : {key[:6]}...{key[-4:]}")
    print(f"template_id     : {s.msg91_template_id}")
    print(f"sender          : {s.msg91_sender_id}")
    print()

    mobile = f"91{phone}"
    otp = "739184"

    # Official docs form: control.msg91.com + authkey in query string.
    url = "https://control.msg91.com/api/v5/otp"
    params = {
        "template_id": s.msg91_template_id,
        "mobile": mobile,
        "authkey": key,
        "otp": otp,
        "otp_length": "6",
        "otp_expiry": "5",
        "sender": s.msg91_sender_id,
    }
    headers = {
        "Content-Type": "application/json",
        "accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=30) as client:
        print("--- SendOTP (docs style: authkey query + control.msg91.com) ---")
        r = await client.post(url, params=params, headers=headers, json={})
        print(f"status: {r.status_code}")
        print(f"body  : {r.text[:800]}")
        print()

        # Also try analytics — proves whether this authkey owns the dashboard
        # workspace the user is looking at.
        end = datetime.now(timezone.utc)
        start = end - timedelta(days=7)
        analytics_url = "https://control.msg91.com/api/v5/otp/analytics"
        print("--- OTP analytics (last 7 days) ---")
        a = await client.get(
            analytics_url,
            params={
                "startDate": start.strftime("%Y-%m-%d"),
                "endDate": end.strftime("%Y-%m-%d"),
            },
            headers={"authkey": key, "accept": "application/json"},
        )
        print(f"status: {a.status_code}")
        print(f"body  : {a.text[:1200]}")
        print()

        logs_url = "https://control.msg91.com/api/v5/otp/logs"
        print("--- OTP logs (last 7 days) ---")
        l = await client.get(
            logs_url,
            params={
                "startDate": start.strftime("%Y-%m-%d"),
                "endDate": end.strftime("%Y-%m-%d"),
                "mobile": mobile,
            },
            headers={"authkey": key, "accept": "application/json"},
        )
        print(f"status: {l.status_code}")
        print(f"body  : {l.text[:2000]}")

    return 0


if __name__ == "__main__":
    phone = sys.argv[1] if len(sys.argv) > 1 else "9043775875"
    raise SystemExit(asyncio.run(main(phone)))
