"""End-to-end check of the payment endpoints against a running local API.

Signs in a throwaway user with the dev OTP, creates a subscription order and
confirms the API returns a real Razorpay order plus the public key the Flutter
checkout needs. Also asserts the webhook rejects unsigned requests.

Run the API first, then: python scripts/check_payment_flow.py
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402

BASE = "http://127.0.0.1:8000/v1"
PHONE = "9812345670"

ok = True


def check(label: str, passed: bool, detail: str = "") -> None:
    global ok
    ok = ok and passed
    print(f"[{'PASS' if passed else 'FAIL'}] {label}{f' — {detail}' if detail else ''}")


async def main() -> int:
    async with httpx.AsyncClient(base_url=BASE, timeout=120) as client:
        cfg = (await client.get("/config")).json()
        check(
            "razorpay enabled in public config",
            cfg.get("razorpayEnabled") is True,
            cfg.get("razorpayKeyId", ""),
        )

        await client.post("/auth/send-otp", json={"phone": PHONE})
        auth = await client.post(
            "/auth/verify-otp", json={"phone": PHONE, "otp": "123456"}
        )
        check("dev OTP sign-in", auth.status_code == 200, str(auth.status_code))
        if auth.status_code != 200:
            print(auth.text)
            return 1
        token = auth.json()["accessToken"]
        headers = {"Authorization": f"Bearer {token}"}

        plans = (await client.get("/plans")).json()
        check("plans available", bool(plans), f"{len(plans)} plans")
        plan_type = plans[0]["type"]

        order = await client.post(
            "/payments/create-order", json={"planType": plan_type}, headers=headers
        )
        check("create-order", order.status_code == 200, str(order.status_code))
        if order.status_code != 200:
            print(order.text)
            return 1
        data = order.json()
        order_id = str(data.get("orderId", ""))
        key = str(data.get("key", ""))
        check(
            "real Razorpay order (not stub)",
            order_id.startswith("order_") and "stub" not in order_id,
            order_id,
        )
        check("checkout key returned to client", key.startswith("rzp_"), key)
        check(
            "amount matches plan",
            data.get("amount") == plans[0]["priceInPaise"],
            f"{data.get('amount')} paise",
        )

        bad_sig = await client.post(
            "/payments/verify",
            json={
                "orderId": order_id,
                "paymentId": "pay_forged000000001",
                "signature": "deadbeef",
            },
            headers=headers,
        )
        check(
            "forged checkout signature rejected",
            bad_sig.status_code >= 400,
            str(bad_sig.status_code),
        )

        hook = await client.post(
            "/payments/razorpay/webhook",
            json={"event": "payment.captured"},
            headers={"X-Razorpay-Signature": "not-a-signature"},
        )
        check("unsigned webhook rejected", hook.status_code == 401, str(hook.status_code))

        # A correctly signed capture must activate the subscription even though
        # the client never called /payments/verify.
        secret = get_settings().razorpay_webhook_secret
        if not secret:
            check("webhook secret configured", False, "RAZORPAY_WEBHOOK_SECRET is empty")
            print("\nSOME CHECKS FAILED")
            return 1

        body = json.dumps(
            {
                "event": "payment.captured",
                "payload": {
                    "payment": {
                        "entity": {
                            "id": "pay_webhooktest0001",
                            "order_id": order_id,
                            "notes": {"planType": plan_type},
                        }
                    }
                },
            }
        ).encode("utf-8")
        signature = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
        signed = await client.post(
            "/payments/razorpay/webhook",
            content=body,
            headers={
                "Content-Type": "application/json",
                "X-Razorpay-Signature": signature,
            },
        )
        check("signed webhook accepted", signed.status_code == 200, signed.text[:120])

        sub = await client.get("/subscriptions/current", headers=headers)
        active = sub.status_code == 200 and (sub.json() or {}).get("status") == "active"
        check("subscription activated by webhook", active, sub.text[:120])

        replay = await client.post(
            "/payments/razorpay/webhook",
            content=body,
            headers={
                "Content-Type": "application/json",
                "X-Razorpay-Signature": signature,
            },
        )
        check("webhook replay is idempotent", replay.status_code == 200, replay.text[:120])

    await _cleanup()
    print("\nPAYMENTS OK" if ok else "\nSOME CHECKS FAILED")
    return 0 if ok else 1


async def _cleanup() -> None:
    """Remove the throwaway user so the tower is left as it was found."""
    from sqlalchemy import select

    from app.db.models import ParkingSlot, User
    from app.db.session import get_engine, get_session_factory

    async with get_session_factory()() as db:
        user = await db.scalar(select(User).where(User.phone == PHONE))
        if user is not None:
            slots = await db.scalars(
                select(ParkingSlot).where(ParkingSlot.assigned_user_id == user.id)
            )
            for slot in slots:
                slot.assigned_user_id = None
                slot.is_occupied = False
            await db.delete(user)
            await db.commit()
            print("cleaned up test user and released its slot")
    await get_engine().dispose()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
