"""Pytest suite for MultiParking FastAPI backend (SQLite file DB per test)."""

from __future__ import annotations

import os
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

TEST_DB = Path(__file__).resolve().parent / "test_multiparking.db"


@pytest.fixture(autouse=True)
def _env(tmp_path, monkeypatch):
    db_path = tmp_path / "test.db"
    monkeypatch.setenv("DATABASE_URL", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    monkeypatch.setenv("OTP_DEV_MODE", "true")
    monkeypatch.setenv("JWT_SECRET", "test-jwt-secret")
    monkeypatch.setenv("QR_SECRET", "test-qr-secret-32-bytes-long!!!!")
    monkeypatch.setenv("GATE_API_KEY", "test-gate-key")
    monkeypatch.setenv("RAZORPAY_KEY_ID", "")
    monkeypatch.setenv("RAZORPAY_KEY_SECRET", "")
    monkeypatch.setenv("APP_ENV", "test")

    from app.core.config import get_settings
    from app.db.session import reset_engine

    get_settings.cache_clear()
    reset_engine()
    yield
    get_settings.cache_clear()
    reset_engine()


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    from app.db.session import get_db, get_engine, get_session_factory, Base
    from app.db.seed import seed_reference_data
    from app.main import create_app

    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with get_session_factory()() as session:
        await seed_reference_data(session)

    app = create_app()

    async def override_get_db():
        async with get_session_factory()() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _login(client: AsyncClient, phone: str = "9876543210") -> dict:
    r = await client.post("/v1/auth/send-otp", json={"phone": phone})
    assert r.status_code == 200, r.text
    r = await client.post("/v1/auth/verify-otp", json={"phone": phone, "otp": "123456"})
    assert r.status_code == 200, r.text
    return r.json()


@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_public_config(client: AsyncClient):
    r = await client.get("/v1/config")
    assert r.status_code == 200
    body = r.json()
    assert "otpDevMode" in body
    assert body["otpDevMode"] is True
    assert "razorpayKeyId" in body
    assert body["razorpayEnabled"] is False
    assert body["totalSlots"] == 1100
    assert body["premiumSlots"] == 220
    assert body["standardSlots"] == 880


@pytest.mark.asyncio
async def test_tower_capacity(client: AsyncClient):
    session = await _login(client, "9000111222")
    headers = {"Authorization": f"Bearer {session['accessToken']}"}
    # Capacity is public on the router without auth requirement in implementation,
    # but exercise via authenticated client as the app would.
    r = await client.get("/v1/parking/capacity", headers=headers)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["totalSlots"] == 1100
    assert body["availableSlots"] == 1100
    assert body["occupiedSlots"] == 0


@pytest.mark.asyncio
async def test_otp_login_and_me(client: AsyncClient):
    session = await _login(client)
    assert "accessToken" in session
    assert session["user"]["phone"] == "9876543210"
    headers = {"Authorization": f"Bearer {session['accessToken']}"}
    me = await client.get("/v1/users/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["phone"] == "9876543210"


@pytest.mark.asyncio
async def test_plans_vehicle_payment_allocate_qr(client: AsyncClient):
    session = await _login(client, "9988776655")
    token = session["accessToken"]
    headers = {"Authorization": f"Bearer {token}"}

    plans = await client.get("/v1/plans", headers=headers)
    assert plans.status_code == 200
    assert len(plans.json()) >= 2

    veh = await client.post(
        "/v1/vehicles",
        headers=headers,
        json={"numberPlate": "MH12AB1234"},
    )
    assert veh.status_code == 201, veh.text
    assert veh.json()["numberPlate"] == "MH12AB1234"

    order = await client.post(
        "/v1/payments/create-order",
        headers=headers,
        json={"planType": "monthly"},
    )
    assert order.status_code == 200, order.text
    body = order.json()
    assert body["orderId"]
    assert body["amount"] > 0

    verify = await client.post(
        "/v1/payments/verify",
        headers=headers,
        json={
            "orderId": body["orderId"],
            "paymentId": "pay_test_1",
            "signature": "sig_test_1",
        },
    )
    assert verify.status_code == 200, verify.text
    assert verify.json()["status"] == "active"

    slot = await client.post("/v1/parking/allocate", headers=headers)
    assert slot.status_code == 200, slot.text
    assert slot.json()["tower"] == "A"

    qr = await client.get("/v1/qr/current", headers=headers)
    assert qr.status_code == 200, qr.text
    assert qr.json()["token"]

    gate = await client.post(
        "/v1/gate/validate",
        headers={"X-Gate-Key": "test-gate-key"},
        json={"token": qr.json()["token"], "action": "entry"},
    )
    assert gate.status_code == 200, gate.text
    assert gate.json()["valid"] is True

    exit_resp = await client.post(
        "/v1/gate/validate",
        headers={"X-Gate-Key": "test-gate-key"},
        json={"token": qr.json()["token"], "action": "exit"},
    )
    assert exit_resp.status_code == 200
    assert exit_resp.json()["valid"] is True


@pytest.mark.asyncio
async def test_hourly_parking_without_subscription(client: AsyncClient):
    """Users without a plan can allocate QR and pay ₹50/hour on exit."""
    session = await _login(client, "9111222333")
    token = session["accessToken"]
    headers = {"Authorization": f"Bearer {token}"}

    veh = await client.post(
        "/v1/vehicles",
        headers=headers,
        json={"numberPlate": "KA01HH5050"},
    )
    assert veh.status_code == 201, veh.text

    sub = await client.get("/v1/subscriptions/current", headers=headers)
    assert sub.status_code == 200
    assert sub.json() is None or sub.json().get("id") is None

    slot = await client.post("/v1/parking/allocate", headers=headers)
    assert slot.status_code == 200, slot.text

    # Hourly passes are minted via refresh — GET /current never auto-issues.
    qr = await client.post("/v1/qr/refresh", headers=headers)
    assert qr.status_code == 200, qr.text
    token_qr = qr.json()["token"]
    assert qr.json()["subscriptionType"] == "hourly"

    entry = await client.post(
        "/v1/gate/validate",
        headers={"X-Gate-Key": "test-gate-key"},
        json={"token": token_qr, "action": "entry"},
    )
    assert entry.status_code == 200, entry.text
    assert entry.json()["valid"] is True
    assert entry.json()["billingType"] == "hourly"

    exit_resp = await client.post(
        "/v1/gate/validate",
        headers={"X-Gate-Key": "test-gate-key"},
        json={"token": token_qr, "action": "exit"},
    )
    assert exit_resp.status_code == 200, exit_resp.text
    body = exit_resp.json()
    assert body["valid"] is True
    assert body["vehicleNumber"] == "KA01HH5050"
    assert body["billingType"] == "hourly"
    assert body["amountInPaise"] == 5000  # ceil to 1 hour × ₹50
    assert body["amountRupees"] == 50.0
    assert body["durationSeconds"] is not None
    assert body["durationLabel"]
    assert body["paymentStatus"] == "pending"
    assert body["action"] == "exit"
    history_id = body["historyId"]
    assert history_id

    # Pay the hourly charge via Razorpay (stub) and confirm it settles.
    order = await client.post(
        "/v1/payments/parking/create-order",
        headers=headers,
        json={"historyId": history_id},
    )
    assert order.status_code == 200, order.text
    order_id = order.json()["orderId"]
    assert order.json()["amount"] == 5000

    verify = await client.post(
        "/v1/payments/parking/verify",
        headers=headers,
        json={
            "historyId": history_id,
            "orderId": order_id,
            "paymentId": "pay_park_1",
            "signature": "sig_park_1",
        },
    )
    assert verify.status_code == 200, verify.text
    assert verify.json()["paymentStatus"] == "paid"

    hist = await client.get("/v1/parking/history", headers=headers)
    assert hist.status_code == 200
    paid_row = next(h for h in hist.json() if h["id"] == history_id)
    assert paid_row["paymentStatus"] == "paid"


@pytest.mark.asyncio
async def test_parking_scan_auto_entry_then_exit(client: AsyncClient):
    """In-app scanner: 1st auto scan = entry, 2nd = exit with amount."""
    session = await _login(client, "9333444555")
    headers = {"Authorization": f"Bearer {session['accessToken']}"}

    await client.post(
        "/v1/vehicles",
        headers=headers,
        json={"numberPlate": "TN09QR1122", "isDefault": True},
    )
    await client.post("/v1/parking/allocate", headers=headers)
    qr = await client.post("/v1/qr/refresh", headers=headers)
    assert qr.status_code == 200, qr.text
    token_qr = qr.json()["token"]

    entry = await client.post(
        "/v1/parking/scan",
        headers=headers,
        json={"token": token_qr, "action": "auto"},
    )
    assert entry.status_code == 200, entry.text
    assert entry.json()["valid"] is True
    assert entry.json()["action"] == "entry"
    assert entry.json()["vehicleNumber"] == "TN09QR1122"
    assert entry.json()["slotLabel"]

    exit_resp = await client.post(
        "/v1/parking/scan",
        headers=headers,
        json={"token": token_qr},  # default action = auto
    )
    assert exit_resp.status_code == 200, exit_resp.text
    body = exit_resp.json()
    assert body["valid"] is True
    assert body["action"] == "exit"
    assert body["amountInPaise"] == 5000
    assert body["paymentStatus"] == "pending"
    assert body["historyId"]


@pytest.mark.asyncio
async def test_staff_floor_filter_matches_allotted_slot(client: AsyncClient):
    """Allocate on floor 2 → staff F2 lists it, F1 does not; label matches floor."""
    from sqlalchemy import update

    from app.db.models import ParkingSlot
    from app.db.seed import seed_staff_accounts
    from app.db.session import get_session_factory

    async with get_session_factory()() as session:
        await session.execute(update(ParkingSlot).where(ParkingSlot.floor == 1).values(is_occupied=True))
        await session.commit()
        await seed_staff_accounts(session)

    member = await _login(client, "9444555666")
    headers = {"Authorization": f"Bearer {member['accessToken']}"}
    veh = await client.post(
        "/v1/vehicles",
        headers=headers,
        json={"numberPlate": "MH12FL0002", "isDefault": True},
    )
    assert veh.status_code == 201, veh.text

    slot = await client.post("/v1/parking/allocate", headers=headers)
    assert slot.status_code == 200, slot.text
    assert slot.json()["floor"] == 2

    qr = await client.post("/v1/qr/refresh", headers=headers)
    assert qr.status_code == 200, qr.text
    token_qr = qr.json()["token"]
    assert "Floor 2" in qr.json()["slotLabel"]

    staff_login = await client.post(
        "/v1/auth/staff/login",
        json={"username": "staff", "password": "Parking@123"},
    )
    assert staff_login.status_code == 200, staff_login.text
    staff_headers = {"Authorization": f"Bearer {staff_login.json()['accessToken']}"}

    scan = await client.post(
        "/v1/staff/scan",
        headers=staff_headers,
        json={"token": token_qr, "action": "entry"},
    )
    assert scan.status_code == 200, scan.text
    assert scan.json()["valid"] is True
    assert scan.json()["floor"] == 2
    assert "Floor 2" in scan.json()["slotLabel"]

    f2 = await client.get("/v1/staff/sessions", headers=staff_headers, params={"status": "parked", "floor": 2})
    assert f2.status_code == 200, f2.text
    plates_f2 = {row["vehicleNumber"] for row in f2.json()}
    assert "MH12FL0002" in plates_f2
    row = next(r for r in f2.json() if r["vehicleNumber"] == "MH12FL0002")
    assert row["floor"] == 2
    assert "Floor 2" in row["slotLabel"]

    f1 = await client.get("/v1/staff/sessions", headers=staff_headers, params={"status": "parked", "floor": 1})
    assert f1.status_code == 200, f1.text
    plates_f1 = {row["vehicleNumber"] for row in f1.json()}
    assert "MH12FL0002" not in plates_f1


@pytest.mark.asyncio
async def test_invalid_otp(client: AsyncClient):
    await client.post("/v1/auth/send-otp", json={"phone": "9123456789"})
    bad = await client.post(
        "/v1/auth/verify-otp",
        json={"phone": "9123456789", "otp": "000000"},
    )
    assert bad.status_code == 400
