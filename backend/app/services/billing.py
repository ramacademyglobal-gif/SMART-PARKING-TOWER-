from __future__ import annotations

import math

from app.core.config import get_settings


def billable_hours(duration_seconds: int) -> int:
    """Round up to whole hours; minimum 1 hour once parking has started."""
    if duration_seconds <= 0:
        return 1
    return max(1, math.ceil(duration_seconds / 3600))


def calculate_hourly_charge_paise(duration_seconds: int) -> int:
    settings = get_settings()
    hours = billable_hours(duration_seconds)
    return hours * settings.hourly_rate_paise


def apply_booking_fee_credit(
    *,
    gross_paise: int,
    booking_fee_paise: int = 0,
    booking_fee_paid: bool = False,
) -> tuple[int, int]:
    """Return ``(gross, net_due)`` after non-refundable booking-fee credit.

    The booking fee is never refunded — unused credit is simply forfeited.
    """
    gross = max(0, int(gross_paise))
    credit = int(booking_fee_paise) if booking_fee_paid else 0
    credit = max(0, credit)
    return gross, max(0, gross - credit)


def format_duration(duration_seconds: int) -> str:
    total = max(0, duration_seconds)
    hours, rem = divmod(total, 3600)
    minutes, seconds = divmod(rem, 60)
    if hours > 0:
        return f"{hours}h {minutes}m"
    if minutes > 0:
        return f"{minutes}m {seconds}s"
    return f"{seconds}s"
