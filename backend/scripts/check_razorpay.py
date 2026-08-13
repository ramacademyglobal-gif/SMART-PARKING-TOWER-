"""Verify the configured Razorpay keys can create and sign orders.

Creates a tiny test order against the live Razorpay API, then round-trips the
HMAC signature check used by /v1/payments/verify.

Run: python scripts/check_razorpay.py
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402
from app.services.razorpay_service import (  # noqa: E402
    create_razorpay_order,
    verify_razorpay_signature,
)


async def main() -> int:
    get_settings.cache_clear()
    settings = get_settings()

    key_id = settings.razorpay_key_id
    print(f"key_id          : {key_id or '(empty)'}")
    print(f"secret set      : {bool(settings.razorpay_key_secret)}")
    print(f"razorpay_enabled: {settings.razorpay_enabled}")
    if not settings.razorpay_enabled:
        print("FAIL: keys missing, backend would run in stub mode.")
        return 1
    if not key_id.startswith("rzp_test_"):
        print("NOTE: this is a LIVE key, real money would move.")

    try:
        order = await create_razorpay_order(
            amount_paise=100,
            receipt="mp_selftest",
            notes={"purpose": "credential self-test"},
        )
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL creating order: {type(exc).__name__}: {exc}")
        return 1

    print(f"order created   : {order['id']} amount={order['amount']} {order['currency']}")
    if not order["id"].startswith("order_") or order["id"].startswith("order_stub_"):
        print("FAIL: order looks like a stub, keys were not used.")
        return 1

    # Reproduce what the Razorpay checkout SDK sends back on success.
    fake_payment_id = "pay_selftest0000001"
    signature = hmac.new(
        settings.razorpay_key_secret.encode("utf-8"),
        f"{order['id']}|{fake_payment_id}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()

    good = verify_razorpay_signature(order["id"], fake_payment_id, signature)
    bad = verify_razorpay_signature(order["id"], fake_payment_id, "deadbeef")
    print(f"signature valid : {good}")
    print(f"tampered reject : {not bad}")

    if good and not bad:
        print("RAZORPAY OK")
        return 0
    print("FAIL: signature verification behaved unexpectedly.")
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
