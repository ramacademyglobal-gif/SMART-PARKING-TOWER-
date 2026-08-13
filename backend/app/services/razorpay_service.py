from __future__ import annotations

import hashlib
import hmac
import logging
from typing import Any

import httpx

from app.core.config import get_settings
from app.core.exceptions import AppError
from app.core.security import new_id

logger = logging.getLogger(__name__)


async def create_razorpay_order(
    *,
    amount_paise: int,
    receipt: str,
    notes: dict[str, Any],
) -> dict[str, Any]:
    settings = get_settings()
    if not settings.razorpay_enabled:
        # Stub/dev-only — empty keys. Not production checkout.
        logger.warning(
            "Razorpay stub order created (keys empty / razorpay_enabled=false). "
            "Not for production."
        )
        order_id = f"order_stub_{new_id()}"
        return {
            "id": order_id,
            "amount": amount_paise,
            "currency": "INR",
            "key": settings.razorpay_key_id or "rzp_test_stub",
        }

    auth = (settings.razorpay_key_id, settings.razorpay_key_secret)
    payload = {
        "amount": amount_paise,
        "currency": "INR",
        "receipt": receipt[:40],
        "notes": notes,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            "https://api.razorpay.com/v1/orders",
            json=payload,
            auth=auth,
        )
        if response.status_code >= 400:
            raise AppError("Unable to create Razorpay order")
        data = response.json()
        return {
            "id": data["id"],
            "amount": data["amount"],
            "currency": data.get("currency", "INR"),
            "key": settings.razorpay_key_id,
        }


def verify_razorpay_signature(order_id: str, payment_id: str, signature: str) -> bool:
    settings = get_settings()
    if not settings.razorpay_enabled:
        # Stub mode: accept any non-empty signature for local/dev.
        return bool(order_id and payment_id and signature)

    body = f"{order_id}|{payment_id}".encode("utf-8")
    expected = hmac.new(
        settings.razorpay_key_secret.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def verify_webhook_signature(raw_body: bytes, signature: str) -> bool:
    """Validate the ``X-Razorpay-Signature`` header against the raw request body.

    Unlike checkout signatures this is keyed by the webhook secret configured in
    the Razorpay dashboard, not the API secret.
    """
    settings = get_settings()
    secret = settings.razorpay_webhook_secret
    if not secret or not signature:
        return False
    expected = hmac.new(
        secret.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)
