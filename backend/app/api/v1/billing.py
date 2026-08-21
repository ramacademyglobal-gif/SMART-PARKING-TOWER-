from __future__ import annotations

import json
import logging

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.exceptions import AppError, NotFoundError, UnauthorizedError
from app.core.security import new_id, utcnow
from app.db.models import Payment, ParkingHistory, ParkingSlot, Plan, User, Vehicle
from app.db.session import get_db
from app.schemas.common import (
    CreateOrderIn,
    CreateOrderOut,
    MessageOut,
    ParkingHistoryOut,
    ParkingOrderIn,
    ParkingVerifyIn,
    PaymentOut,
    PlanOut,
    QrOut,
    SubscriptionOut,
    VerifyPaymentIn,
)
from app.services.allocation import (
    get_active_subscription,
    has_active_plan,
    slot_label,
)
from app.services.payments import (
    settle_booking_payment,
    settle_parking_payment,
    settle_subscription_payment,
)
from app.core.config import get_settings
from app.services.razorpay_service import (
    create_razorpay_order,
    verify_razorpay_signature,
    verify_webhook_signature,
)

logger = logging.getLogger(__name__)

plans_router = APIRouter(prefix="/plans", tags=["plans"])
subs_router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])
payments_router = APIRouter(prefix="/payments", tags=["payments"])


def _plan_out(plan: Plan) -> PlanOut:
    features = json.loads(plan.features_json or "[]")
    return PlanOut(
        id=plan.id,
        type=plan.type,
        name=plan.name,
        price_in_paise=plan.price_in_paise,
        duration_days=plan.duration_days,
        features=features,
        is_premium=plan.is_premium,
    )


@plans_router.get("", response_model=list[PlanOut])
async def list_plans(db: AsyncSession = Depends(get_db)) -> list[PlanOut]:
    rows = await db.scalars(select(Plan).where(Plan.active.is_(True)))
    return [_plan_out(p) for p in rows]


@subs_router.get("", response_model=SubscriptionOut | None)
async def current_subscription(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SubscriptionOut | None:
    sub = await get_active_subscription(db, user.id)
    if sub is None:
        return None
    return SubscriptionOut.model_validate(sub)


@subs_router.get("/current", response_model=SubscriptionOut | None)
async def current_subscription_alias(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SubscriptionOut | None:
    return await current_subscription(user, db)


@payments_router.get("", response_model=list[PaymentOut])
async def payment_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PaymentOut]:
    rows = await db.scalars(
        select(Payment)
        .where(Payment.user_id == user.id)
        .order_by(Payment.created_at.desc())
    )
    return [PaymentOut.model_validate(p) for p in rows]


@payments_router.post("/create-order", response_model=CreateOrderOut)
async def create_order(
    body: CreateOrderIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CreateOrderOut:
    plan_type = body.plan_type.lower().strip()
    plan = await db.scalar(select(Plan).where(Plan.type == plan_type, Plan.active.is_(True)))
    if plan is None:
        raise NotFoundError("Plan not found")

    order = await create_razorpay_order(
        amount_paise=plan.price_in_paise,
        receipt=f"mp_{user.id[-8:]}_{plan_type}",
        notes={"userId": user.id, "planType": plan_type},
    )
    payment = Payment(
        id=new_id("pay"),
        user_id=user.id,
        amount_in_paise=plan.price_in_paise,
        currency="INR",
        plan_type=plan_type,
        status="created",
        razorpay_order_id=order["id"],
        created_at=utcnow(),
    )
    db.add(payment)
    await db.commit()
    return CreateOrderOut(
        order_id=order["id"],
        amount=order["amount"],
        currency=order.get("currency", "INR"),
        key=order["key"],
    )


@payments_router.post("/verify", response_model=SubscriptionOut)
async def verify_payment(
    body: VerifyPaymentIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    if not verify_razorpay_signature(body.order_id, body.payment_id, body.signature):
        raise AppError("Payment signature verification failed")

    payment = await db.scalar(
        select(Payment).where(
            Payment.user_id == user.id,
            Payment.razorpay_order_id == body.order_id,
        )
    )
    if payment is None:
        raise NotFoundError("Payment order not found")

    sub = await settle_subscription_payment(
        db,
        payment=payment,
        payment_id=body.payment_id,
        signature=body.signature,
    )
    return SubscriptionOut.model_validate(sub)


@payments_router.post("/parking/create-order", response_model=CreateOrderOut)
async def create_parking_order(
    body: ParkingOrderIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CreateOrderOut:
    session = await db.get(ParkingHistory, body.history_id)
    if session is None or session.user_id != user.id:
        raise NotFoundError("Parking session not found")
    if session.payment_status == "paid":
        raise AppError("This parking session is already paid")
    amount = session.amount_in_paise or 0
    if amount <= 0:
        raise AppError("No payment is due for this session")

    order = await create_razorpay_order(
        amount_paise=amount,
        receipt=f"park_{session.id[-8:]}",
        notes={"userId": user.id, "historyId": session.id, "type": "parking"},
    )
    payment = Payment(
        id=new_id("pay"),
        user_id=user.id,
        amount_in_paise=amount,
        currency="INR",
        plan_type="hourly",
        status="created",
        razorpay_order_id=order["id"],
        created_at=utcnow(),
    )
    db.add(payment)
    await db.commit()
    return CreateOrderOut(
        order_id=order["id"],
        amount=order["amount"],
        currency=order.get("currency", "INR"),
        key=order["key"],
    )


@payments_router.post("/parking/verify", response_model=ParkingHistoryOut)
async def verify_parking_payment(
    body: ParkingVerifyIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ParkingHistoryOut:
    if not verify_razorpay_signature(body.order_id, body.payment_id, body.signature):
        raise AppError("Payment signature verification failed")

    session = await db.get(ParkingHistory, body.history_id)
    if session is None or session.user_id != user.id:
        raise NotFoundError("Parking session not found")

    payment = await db.scalar(
        select(Payment).where(
            Payment.user_id == user.id,
            Payment.razorpay_order_id == body.order_id,
        )
    )
    if payment is None:
        raise NotFoundError("Payment order not found")

    settled = await settle_parking_payment(
        db,
        payment=payment,
        session=session,
        payment_id=body.payment_id,
        signature=body.signature,
    )
    return ParkingHistoryOut.model_validate(settled)


async def _qr_out_for_access(db: AsyncSession, user: User, access) -> QrOut:
    sub = await get_active_subscription(db, user.id)
    slot = await db.get(ParkingSlot, access.parking_slot_id) if access.parking_slot_id else None
    vehicle = await db.get(Vehicle, access.vehicle_id) if access.vehicle_id else None
    return QrOut(
        token=access.token_cipher,
        user_name=user.display_name,
        vehicle_number=vehicle.number_plate if vehicle else "",
        slot_label=slot_label(slot) if slot else "Unassigned",
        subscription_type=sub.plan_type if sub else "hourly",
        expires_at=access.expires_at,
        is_permanent=access.is_permanent,
        booking_fee_paise=int(getattr(access, "booking_fee_paise", 0) or 0),
        booking_fee_paid=bool(getattr(access, "booking_fee_paid", False)),
    )


@payments_router.post("/booking/create-order", response_model=CreateOrderOut)
async def create_booking_fee_order(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CreateOrderOut:
    """Create a Razorpay order for the non-refundable hourly booking fee."""
    sub = await get_active_subscription(db, user.id)
    if has_active_plan(sub):
        raise AppError("Subscribers do not pay a booking fee. Refresh your QR instead.")

    settings = get_settings()
    amount = settings.booking_fee_paise
    if amount <= 0:
        raise AppError("Booking fee is not configured")

    order = await create_razorpay_order(
        amount_paise=amount,
        receipt=f"book_{user.id[-8:]}",
        notes={"userId": user.id, "type": "booking"},
    )
    payment = Payment(
        id=new_id("pay"),
        user_id=user.id,
        amount_in_paise=amount,
        currency="INR",
        plan_type="booking",
        status="created",
        razorpay_order_id=order["id"],
        created_at=utcnow(),
    )
    db.add(payment)
    await db.commit()
    return CreateOrderOut(
        order_id=order["id"],
        amount=order["amount"],
        currency=order.get("currency", "INR"),
        key=order["key"],
    )


@payments_router.post("/booking/verify", response_model=QrOut)
async def verify_booking_fee_payment(
    body: VerifyPaymentIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> QrOut:
    """Verify booking-fee payment, then allot a slot and issue the temporary QR."""
    if not verify_razorpay_signature(body.order_id, body.payment_id, body.signature):
        raise AppError("Payment signature verification failed")

    payment = await db.scalar(
        select(Payment).where(
            Payment.user_id == user.id,
            Payment.razorpay_order_id == body.order_id,
            Payment.plan_type == "booking",
        )
    )
    if payment is None:
        raise NotFoundError("Booking payment order not found")

    access = await settle_booking_payment(
        db,
        payment=payment,
        payment_id=body.payment_id,
        signature=body.signature,
    )
    return await _qr_out_for_access(db, user, access)


# Events that mean money has actually been captured.
_SETTLING_EVENTS = {"payment.captured", "order.paid"}


@payments_router.post("/razorpay/webhook", response_model=MessageOut)
async def razorpay_webhook(
    request: Request,
    x_razorpay_signature: str = Header(default=""),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    """Server-to-server settlement fallback.

    The app already verifies the signature after checkout, but it may be killed
    before that call lands. Razorpay retries this endpoint, so the subscription
    or parking session still settles. Configure the secret as
    ``RAZORPAY_WEBHOOK_SECRET``.
    """
    raw = await request.body()
    if not verify_webhook_signature(raw, x_razorpay_signature):
        raise UnauthorizedError("Invalid webhook signature")

    try:
        event = json.loads(raw.decode("utf-8"))
    except ValueError as exc:
        raise AppError("Malformed webhook payload") from exc

    event_type = str(event.get("event", ""))
    if event_type not in _SETTLING_EVENTS:
        return MessageOut(message=f"Ignored {event_type or 'unknown event'}")

    entity = (
        event.get("payload", {}).get("payment", {}).get("entity")
        or event.get("payload", {}).get("order", {}).get("entity")
        or {}
    )
    order_id = entity.get("order_id") or entity.get("id")
    payment_id = entity.get("id") or ""
    notes = entity.get("notes") or {}

    if not order_id:
        return MessageOut(message="Ignored event without an order id")

    payment = await db.scalar(
        select(Payment).where(Payment.razorpay_order_id == order_id)
    )
    if payment is None:
        # Orders created outside this app (or already pruned) are not an error.
        logger.info("Razorpay webhook for unknown order %s", order_id)
        return MessageOut(message="Unknown order ignored")

    if payment.plan_type == "booking" or notes.get("type") == "booking":
        await settle_booking_payment(db, payment=payment, payment_id=payment_id)
        return MessageOut(message="Booking fee settled")

    history_id = notes.get("historyId")
    if history_id:
        session = await db.get(ParkingHistory, history_id)
        if session is None:
            return MessageOut(message="Parking session no longer exists")
        await settle_parking_payment(
            db, payment=payment, session=session, payment_id=payment_id
        )
        return MessageOut(message="Parking payment settled")

    await settle_subscription_payment(db, payment=payment, payment_id=payment_id)
    return MessageOut(message="Subscription payment settled")
