"""Settlement logic shared by the verify endpoints and the Razorpay webhook.

Both entry points must produce the same result, and both may run for the same
order (the app verifies while the webhook also fires), so every function here
is idempotent.
"""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, NotFoundError
from app.core.security import new_id, utcnow
from app.db.models import ParkingHistory, Payment, Plan, Subscription
from app.db.models import User
from app.services.allocation import (
    allocate_slot_for_user,
    get_active_subscription,
    issue_qr_for_user,
)
from app.services.notifications import push_notification


async def find_payment_by_order(db: AsyncSession, order_id: str) -> Payment | None:
    return await db.scalar(
        select(Payment).where(Payment.razorpay_order_id == order_id)
    )


def _mark_paid(payment: Payment, *, payment_id: str, signature: str | None) -> None:
    payment.status = "success"
    payment.razorpay_payment_id = payment_id
    if signature:
        payment.razorpay_signature = signature


async def settle_subscription_payment(
    db: AsyncSession,
    *,
    payment: Payment,
    payment_id: str,
    signature: str | None = None,
) -> Subscription:
    """Activate the plan bought by ``payment``. Safe to call more than once."""
    user = await db.get(User, payment.user_id)
    if user is None:
        raise NotFoundError("User not found")

    if payment.status == "success":
        existing = await get_active_subscription(db, user.id)
        if existing is not None:
            return existing

    plan = await db.scalar(select(Plan).where(Plan.type == payment.plan_type))
    if plan is None:
        raise NotFoundError("Plan not found")

    _mark_paid(payment, payment_id=payment_id, signature=signature)

    actives = await db.scalars(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.status == "active",
        )
    )
    for row in actives:
        row.status = "cancelled"

    start = utcnow()
    sub = Subscription(
        id=new_id("sub"),
        user_id=user.id,
        plan_type=plan.type,
        status="active",
        start_date=start,
        expiry_date=start + timedelta(days=plan.duration_days),
        razorpay_payment_id=payment_id,
    )
    db.add(sub)
    await db.commit()
    await db.refresh(sub)

    await allocate_slot_for_user(db, user)
    try:
        await issue_qr_for_user(db, user)
    except AppError:
        # Vehicle may not exist yet during onboarding — QR is issued later.
        pass

    await push_notification(
        db,
        user_id=user.id,
        title="Payment Successful",
        body=f"Your {plan.name} subscription is now active.",
        type_="payment",
        data={"subscriptionId": sub.id, "planType": plan.type},
    )
    await db.refresh(sub)
    return sub


async def settle_parking_payment(
    db: AsyncSession,
    *,
    payment: Payment,
    session: ParkingHistory,
    payment_id: str,
    signature: str | None = None,
) -> ParkingHistory:
    """Mark an hourly parking session as paid. Safe to call more than once."""
    if payment.status == "success" and session.payment_status == "paid":
        return session

    _mark_paid(payment, payment_id=payment_id, signature=signature)
    session.payment_status = "paid"
    await db.commit()

    amount_rupees = (session.amount_in_paise or 0) / 100.0
    await push_notification(
        db,
        user_id=session.user_id,
        title="Parking Paid",
        body=f"{session.vehicle_number} · ₹{amount_rupees:.0f} paid. Thank you!",
        type_="payment",
        data={"historyId": session.id, "amountInPaise": session.amount_in_paise},
    )
    await db.refresh(session)
    return session
