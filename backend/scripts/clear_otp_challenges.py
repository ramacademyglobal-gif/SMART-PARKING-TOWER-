"""Clear recent OTP rate-limit rows for a phone so testing can continue.

Run: python scripts/clear_otp_challenges.py 9043775875
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

from sqlalchemy import delete

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.models import OtpChallenge  # noqa: E402
from app.db.session import get_engine, get_session_factory  # noqa: E402
from app.services.otp import normalize_phone  # noqa: E402


async def main(raw_phone: str) -> int:
    phone = normalize_phone(raw_phone)
    async with get_session_factory()() as db:
        result = await db.execute(delete(OtpChallenge).where(OtpChallenge.phone == phone))
        await db.commit()
        print(f"deleted {result.rowcount} otp challenge(s) for {phone}")
    await get_engine().dispose()
    return 0


if __name__ == "__main__":
    phone = sys.argv[1] if len(sys.argv) > 1 else "9043775875"
    raise SystemExit(asyncio.run(main(phone)))
