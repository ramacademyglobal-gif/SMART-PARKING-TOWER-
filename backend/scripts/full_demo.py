"""Full working demo of everything completed so far.

Walks the live API through:
  1. Public config (DB + Razorpay status)
  2. Member OTP login → vehicle → subscription order (Razorpay live order)
  3. Staff username/password login → overview
  4. Walk-in vehicle booking by plate
  5. Staff checkout + cash collect
  6. QR issue for the member (after vehicle exists)
  7. Staff QR scan entry / exit details

Run with the API already listening on :8000:
  python scripts/full_demo.py
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
MEMBER_PHONE = "9876501234"
WALK_IN_PLATE = "KA01DEMO9999"


def banner(title: str) -> None:
    print()
    print("=" * 64)
    print(f"  {title}")
    print("=" * 64)


def step(n: int, text: str) -> None:
    print(f"\n[{n}] {text}")


def ok(text: str) -> None:
    print(f"    [OK] {text}")


def fail(text: str) -> None:
    print(f"    [FAIL] {text}")
    raise SystemExit(1)


async def main() -> int:
    get_settings.cache_clear()
    settings = get_settings()

    async with httpx.AsyncClient(base_url=BASE, timeout=120) as client:
        # ------------------------------------------------------------------
        banner("1. SYSTEM BOOTSTRAP")
        # ------------------------------------------------------------------
        step(1, "Public config")
        cfg = (await client.get("/config")).json()
        ok(
            f"Tower {cfg.get('towerName')} | "
            f"{cfg.get('availableSlots')}/{cfg.get('totalSlots')} free | "
            f"Rs {cfg.get('hourlyRateRupees')}/hr"
        )
        ok(f"OTP dev mode = {cfg.get('otpDevMode')} (code always 123456)")
        ok(
            f"Razorpay enabled = {cfg.get('razorpayEnabled')} | "
            f"key = {cfg.get('razorpayKeyId')}"
        )
        if not cfg.get("razorpayEnabled"):
            fail("Razorpay keys missing - check backend/.env")

        # ------------------------------------------------------------------
        banner("2. MEMBER FLOW (phone OTP)")
        # ------------------------------------------------------------------
        step(2, f"Send + verify OTP for {MEMBER_PHONE}")
        await client.post("/auth/send-otp", json={"phone": MEMBER_PHONE})
        auth = await client.post(
            "/auth/verify-otp", json={"phone": MEMBER_PHONE, "otp": "123456"}
        )
        if auth.status_code != 200:
            fail(f"OTP login failed: {auth.text}")
        session = auth.json()
        member = session["user"]
        member_headers = {"Authorization": f"Bearer {session['accessToken']}"}
        ok(f"Logged in as {member['displayName']} ({member['role']})")

        step(3, "Register vehicle KA01AB1234")
        vehicles = (await client.get("/vehicles", headers=member_headers)).json()
        if not vehicles:
            created = await client.post(
                "/vehicles",
                headers=member_headers,
                json={
                    "numberPlate": "KA01AB1234",
                    "make": "Toyota",
                    "model": "Innova",
                    "color": "White",
                    "isDefault": True,
                },
            )
            if created.status_code not in (200, 201):
                fail(f"Vehicle create failed: {created.text}")
            vehicles = [created.json()]
        ok(f"Vehicle ready: {vehicles[0]['numberPlate']}")

        step(4, "Create Razorpay subscription order (Monthly)")
        plans = (await client.get("/plans")).json()
        monthly = next(p for p in plans if p["type"] == "monthly")
        order = await client.post(
            "/payments/create-order",
            headers=member_headers,
            json={"planType": "monthly"},
        )
        if order.status_code != 200:
            fail(f"create-order failed: {order.text}")
        order_data = order.json()
        ok(
            f"Live Razorpay order {order_data['orderId']} | "
            f"Rs {order_data['amount'] / 100:.0f} | key {order_data['key']}"
        )
        ok("In the Flutter app this would open the Razorpay checkout sheet.")

        step(5, "Simulate successful payment via signed webhook")
        secret = settings.razorpay_webhook_secret
        body = json.dumps(
            {
                "event": "payment.captured",
                "payload": {
                    "payment": {
                        "entity": {
                            "id": "pay_demo_full_001",
                            "order_id": order_data["orderId"],
                            "notes": {"planType": "monthly", "userId": member["id"]},
                        }
                    }
                },
            }
        ).encode("utf-8")
        signature = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
        hook = await client.post(
            "/payments/razorpay/webhook",
            content=body,
            headers={
                "Content-Type": "application/json",
                "X-Razorpay-Signature": signature,
            },
        )
        if hook.status_code != 200:
            fail(f"webhook settle failed: {hook.text}")
        sub = (await client.get("/subscriptions/current", headers=member_headers)).json()
        ok(f"Subscription active: {sub['planType']} until {sub['expiryDate'][:10]}")

        step(6, "Allocate bay + issue QR pass")
        slot = await client.post("/parking/allocate", headers=member_headers)
        if slot.status_code != 200:
            fail(f"allocate failed: {slot.text}")
        slot_data = slot.json()
        ok(
            f"Bay assigned: Tower {slot_data['tower']} | Floor {slot_data['floor']} | "
            f"Zone {slot_data['zone']} | Slot {slot_data['slotNumber']}"
        )
        qr = await client.post("/qr/refresh", headers=member_headers)
        if qr.status_code != 200:
            fail(f"QR issue failed: {qr.text}")
        qr_data = qr.json()
        qr_token = qr_data["token"]
        ok(f"QR pass issued (token length {len(qr_token)})")

        # ------------------------------------------------------------------
        banner("3. STAFF CONSOLE")
        # ------------------------------------------------------------------
        step(7, "Staff login (username + password)")
        staff_login = await client.post(
            "/auth/staff/login",
            json={
                "username": settings.staff_username,
                "password": settings.staff_password,
            },
        )
        if staff_login.status_code != 200:
            fail(f"Staff login failed: {staff_login.text}")
        staff_session = staff_login.json()
        staff = staff_session["user"]
        staff_headers = {"Authorization": f"Bearer {staff_session['accessToken']}"}
        ok(
            f"Staff in: {staff['displayName']} | role={staff['role']} | "
            f"username={staff.get('username')}"
        )

        step(8, "Staff overview dashboard")
        overview = (await client.get("/staff/overview", headers=staff_headers)).json()
        ok(
            f"Slots {overview['occupiedSlots']}/{overview['totalSlots']} occupied | "
            f"parked now {overview['parkedNow']} | "
            f"entries today {overview['entriesToday']}"
        )

        step(9, "Staff scans member QR → ENTRY")
        scan_in = await client.post(
            "/staff/scan",
            headers=staff_headers,
            json={"token": qr_token, "action": "auto"},
        )
        if scan_in.status_code != 200:
            fail(f"staff scan entry failed: {scan_in.text}")
        entry = scan_in.json()
        ok(
            f"{entry.get('action', entry.get('result', 'ENTRY')).upper()} | "
            f"{entry.get('vehicleNumber') or entry.get('userName')} | "
            f"slot {entry.get('slotNumber')} | "
            f"{entry.get('message') or entry.get('detail') or ''}"
        )
        # Print a few useful detail fields if present
        for key in (
            "userName",
            "userPhone",
            "subscriptionType",
            "tower",
            "floor",
            "zone",
            "slotNumber",
            "vehicleNumber",
        ):
            if entry.get(key) is not None:
                print(f"       {key}: {entry[key]}")

        step(10, "Walk-in driver (no app) - book bay by plate")
        # Clear any leftover open session for this demo plate
        lookup = await client.get(
            "/staff/sessions/lookup",
            headers=staff_headers,
            params={"plate": WALK_IN_PLATE},
        )
        if lookup.status_code == 200 and lookup.json():
            old = lookup.json()
            await client.post(
                f"/staff/sessions/{old['id']}/checkout", headers=staff_headers
            )

        walk = await client.post(
            "/staff/walk-in",
            headers=staff_headers,
            json={
                "numberPlate": WALK_IN_PLATE,
                "driverName": "Ravi Kumar",
                "contactPhone": "9876543210",
            },
        )
        if walk.status_code not in (200, 201):
            fail(f"walk-in failed: {walk.text}")
        walk_session = walk.json()
        ok(
            f"Walk-in parked: {walk_session['vehicleNumber']} | "
            f"{walk_session['slotLabel']} | driver {walk_session.get('driverName')}"
        )

        step(11, "Active parked sessions (staff list)")
        sessions = (
            await client.get(
                "/staff/sessions",
                headers=staff_headers,
                params={"status": "parked"},
            )
        ).json()
        ok(f"{len(sessions)} vehicle(s) currently parked")
        for s in sessions[:5]:
            tag = "WALK-IN" if s.get("isWalkIn") else "APP"
            print(
                f"       [{tag}] {s['vehicleNumber']} | {s['slotLabel']} | "
                f"since {s['entryAt'][:16]}"
            )

        step(12, "Checkout walk-in + collect cash")
        checkout = await client.post(
            f"/staff/sessions/{walk_session['id']}/checkout",
            headers=staff_headers,
        )
        if checkout.status_code != 200:
            fail(f"checkout failed: {checkout.text}")
        closed = checkout.json()
        amount = closed.get("amountRupees") or 0
        ok(
            f"Checked out | duration {closed.get('durationLabel')} | "
            f"due Rs {amount:.0f} | payment={closed.get('paymentStatus')}"
        )
        if closed.get("paymentStatus") == "pending":
            collect = await client.post(
                f"/staff/sessions/{closed['id']}/collect",
                headers=staff_headers,
            )
            if collect.status_code != 200:
                fail(f"collect failed: {collect.text}")
            ok(f"Cash collected | payment={collect.json().get('paymentStatus')}")

        step(13, "Staff scans member QR → EXIT")
        # Refresh QR may still be valid; scan again for exit
        scan_out = await client.post(
            "/staff/scan",
            headers=staff_headers,
            json={"token": qr_token, "action": "auto"},
        )
        if scan_out.status_code != 200:
            # Some gate logic issues a one-shot QR; refresh and try once more
            qr2 = await client.post("/qr/refresh", headers=member_headers)
            if qr2.status_code == 200:
                scan_out = await client.post(
                    "/staff/scan",
                    headers=staff_headers,
                    json={"token": qr2.json()["token"], "action": "auto"},
                )
        if scan_out.status_code != 200:
            fail(f"staff scan exit failed: {scan_out.text}")
        exit_data = scan_out.json()
        ok(
            f"{exit_data.get('action', exit_data.get('result', 'EXIT')).upper()} | "
            f"{exit_data.get('message') or exit_data.get('detail') or 'exit recorded'}"
        )
        for key in (
            "vehicleNumber",
            "durationLabel",
            "amountRupees",
            "paymentStatus",
            "billingType",
        ):
            if exit_data.get(key) is not None:
                print(f"       {key}: {exit_data[key]}")

        # Final overview
        step(14, "Final staff overview")
        final = (await client.get("/staff/overview", headers=staff_headers)).json()
        ok(
            f"Available {final['availableSlots']} | parked {final['parkedNow']} | "
            f"exits today {final['exitsToday']} | "
            f"collected today Rs {final['collectedTodayRupees']:.0f}"
        )

    banner("DEMO COMPLETE - ALL FLOWS WORKING")
    print(
        """
What you just saw on the API:
  • Member OTP login (dev code 123456)
  • Vehicle registration
  • Live Razorpay order + webhook settlement → subscription
  • Bay allocation + QR pass
  • Staff login (staff / Parking@123)
  • Staff QR scan entry & exit with full details
  • Walk-in booking by plate, checkout, cash collect

To see the same UI in the Flutter app, run the commands printed next.
"""
    )
    print("Staff credentials:")
    print(f"  username: {settings.staff_username}")
    print(f"  password: {settings.staff_password}")
    print(f"  admin:    {settings.admin_username} / {settings.admin_password}")
    print(f"\nMember demo phone: {MEMBER_PHONE}  OTP: 123456")
    print(f"API docs: http://127.0.0.1:8000/docs")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
