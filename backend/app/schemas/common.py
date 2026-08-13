from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


def to_camel(string: str) -> str:
    parts = string.split("_")
    return parts[0] + "".join(word.capitalize() for word in parts[1:])


class CamelModel(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        from_attributes=True,
    )


class MessageOut(CamelModel):
    message: str
    # Present for live MSG91 OTP sends — look this up under OTP → Logs.
    request_id: str | None = None


class PublicConfigOut(CamelModel):
    """Non-secret bootstrap values for the mobile/web client."""

    otp_dev_mode: bool
    razorpay_key_id: str = ""
    razorpay_enabled: bool = False
    msg91_enabled: bool = False
    # True when backend/.env was found on disk (helps diagnose misconfigured paths).
    env_file_loaded: bool = False
    tower_id: str = "A"
    tower_name: str = "MultiParking Tower A"
    total_slots: int = 1100
    available_slots: int = 1100
    occupied_slots: int = 0
    premium_slots: int = 220
    standard_slots: int = 880
    hourly_rate_rupees: float = 50.0


class TowerCapacityOut(CamelModel):
    tower_id: str = "A"
    tower_name: str = "MultiParking Tower A"
    total_slots: int
    available_slots: int
    occupied_slots: int
    premium_available: int
    standard_available: int
    hourly_rate_rupees: float = 50.0


class UserOut(CamelModel):
    id: str
    phone: str = ""
    username: Optional[str] = None
    display_name: str
    photo_url: Optional[str] = None
    member_since: datetime
    role: str = "user"

    @field_validator("phone", mode="before")
    @classmethod
    def _blank_phone(cls, value: Optional[str]) -> str:
        # Staff accounts have no phone number.
        return value or ""


class UserUpdate(CamelModel):
    display_name: Optional[str] = None
    photo_url: Optional[str] = None


class SendOtpIn(CamelModel):
    phone: str


class VerifyOtpIn(CamelModel):
    phone: str
    otp: str


class FirebaseLoginIn(CamelModel):
    """Exchange a verified Firebase ID token for an app JWT session."""

    id_token: str
    phone: Optional[str] = None


class RefreshIn(CamelModel):
    refresh_token: str


class StaffLoginIn(CamelModel):
    username: str
    password: str


class AuthSessionOut(CamelModel):
    access_token: str
    refresh_token: str
    user: UserOut
    is_new_user: bool


class VehicleIn(CamelModel):
    number_plate: str
    make: Optional[str] = None
    model: Optional[str] = None
    color: Optional[str] = None
    is_default: bool = False


class VehicleOut(CamelModel):
    id: str
    user_id: str
    number_plate: str
    make: Optional[str] = None
    model: Optional[str] = None
    color: Optional[str] = None
    is_default: bool
    created_at: datetime


class PlanOut(CamelModel):
    id: str
    type: str
    name: str
    price_in_paise: int
    duration_days: int
    features: list[str] = Field(default_factory=list)
    is_premium: bool


class SubscriptionOut(CamelModel):
    id: str
    user_id: str
    plan_type: str
    status: str
    start_date: datetime
    expiry_date: datetime
    razorpay_payment_id: Optional[str] = None


class CreateOrderIn(CamelModel):
    plan_type: str


class CreateOrderOut(CamelModel):
    order_id: str
    amount: int
    currency: str = "INR"
    key: str


class VerifyPaymentIn(CamelModel):
    order_id: str
    payment_id: str
    signature: str


class ParkingOrderIn(CamelModel):
    history_id: str


class ParkingVerifyIn(CamelModel):
    history_id: str
    order_id: str
    payment_id: str
    signature: str


class PaymentOut(CamelModel):
    id: str
    amount_in_paise: int
    currency: str
    plan_type: str
    status: str
    created_at: datetime
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None


class ParkingSlotOut(CamelModel):
    id: str
    tower: str
    floor: int
    zone: str
    slot_number: str
    is_premium: bool
    is_occupied: bool


class ParkingHistoryOut(CamelModel):
    id: str
    vehicle_number: str
    entry_at: datetime
    exit_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    tower: str
    floor: int
    zone: str
    slot_number: str
    subscription_type: str
    status: str
    amount_in_paise: Optional[int] = None
    billing_type: str = "hourly"
    payment_status: str = "free"


class QrOut(CamelModel):
    token: str
    user_name: str
    vehicle_number: str
    slot_label: str
    subscription_type: str
    expires_at: datetime
    is_permanent: bool


class NotificationOut(CamelModel):
    id: str
    title: str
    body: str
    type: str
    created_at: datetime
    is_read: bool
    data: dict[str, Any] = Field(default_factory=dict)


class MarkReadIn(CamelModel):
    ids: list[str] = Field(default_factory=list)


class FcmRegisterIn(CamelModel):
    token: str
    platform: str = "android"


class GateValidateIn(CamelModel):
    token: str
    action: str = "auto"  # entry | exit | auto


class GateScanIn(CamelModel):
    """In-app / attendant scanner — auto entry on 1st scan, exit on 2nd."""

    token: str
    action: str = "auto"


class GateValidateOut(CamelModel):
    valid: bool
    message: str
    vehicle_number: Optional[str] = None
    slot_label: Optional[str] = None
    entry_at: Optional[datetime] = None
    exit_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    duration_label: Optional[str] = None
    amount_in_paise: Optional[int] = None
    amount_rupees: Optional[float] = None
    billing_type: Optional[str] = None
    hourly_rate_rupees: Optional[float] = None
    history_id: Optional[str] = None
    payment_status: Optional[str] = None
    action: Optional[str] = None  # entry | exit
    # Identity of the pass holder, shown on the staff scanner result card.
    user_name: Optional[str] = None
    user_phone: Optional[str] = None
    subscription_type: Optional[str] = None
    tower: Optional[str] = None
    floor: Optional[int] = None
    zone: Optional[str] = None
    slot_number: Optional[str] = None
    is_walk_in: bool = False


class WalkInIn(CamelModel):
    """Counter booking for a driver who does not have the app."""

    number_plate: str
    driver_name: Optional[str] = None
    contact_phone: Optional[str] = None


class StaffSessionOut(CamelModel):
    id: str
    vehicle_number: str
    driver_name: Optional[str] = None
    contact_phone: Optional[str] = None
    user_name: Optional[str] = None
    user_phone: Optional[str] = None
    is_walk_in: bool = False
    slot_label: str
    tower: str
    floor: int
    zone: str
    slot_number: str
    entry_at: datetime
    exit_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    duration_label: Optional[str] = None
    status: str
    billing_type: str = "hourly"
    payment_status: str = "free"
    amount_in_paise: Optional[int] = None
    amount_rupees: Optional[float] = None
    hourly_rate_rupees: float = 50.0


class StaffOverviewOut(CamelModel):
    staff_name: str
    role: str = "staff"
    total_slots: int
    occupied_slots: int
    available_slots: int
    parked_now: int
    walk_ins_parked: int
    entries_today: int
    exits_today: int
    pending_payments: int
    collected_today_rupees: float
    hourly_rate_rupees: float = 50.0
