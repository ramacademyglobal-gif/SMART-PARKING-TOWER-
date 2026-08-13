from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Index,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.security import utcnow
from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    # Null for staff/admin accounts, which sign in with username + password.
    phone: Mapped[Optional[str]] = mapped_column(
        String(15), unique=True, index=True, nullable=True
    )
    username: Mapped[Optional[str]] = mapped_column(
        String(60), unique=True, index=True, nullable=True
    )
    password_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_name: Mapped[str] = mapped_column(String(120), default="Member")
    photo_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    role: Mapped[str] = mapped_column(String(32), default="user")
    member_since: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    # These children all declare ON DELETE CASCADE, so let the database remove
    # them. Without passive_deletes the ORM would try to NULL their non-nullable
    # user_id instead and the delete would fail.
    vehicles: Mapped[list[Vehicle]] = relationship(
        back_populates="user", cascade="all, delete", passive_deletes=True
    )
    subscriptions: Mapped[list[Subscription]] = relationship(
        back_populates="user", cascade="all, delete", passive_deletes=True
    )
    payments: Mapped[list[Payment]] = relationship(
        back_populates="user", cascade="all, delete", passive_deletes=True
    )
    notifications: Mapped[list[AppNotification]] = relationship(
        back_populates="user", cascade="all, delete", passive_deletes=True
    )
    device_tokens: Mapped[list[DeviceToken]] = relationship(
        back_populates="user", cascade="all, delete", passive_deletes=True
    )


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    phone: Mapped[str] = mapped_column(String(15), index=True)
    code_hash: Mapped[str] = mapped_column(String(255))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(255), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Vehicle(Base):
    __tablename__ = "vehicles"
    __table_args__ = (UniqueConstraint("user_id", "number_plate", name="uq_user_plate"),)

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    number_plate: Mapped[str] = mapped_column(String(20), index=True)
    make: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    model: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    color: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[User] = relationship(back_populates="vehicles")


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    type: Mapped[str] = mapped_column(String(20), unique=True)  # monthly | annual
    name: Mapped[str] = mapped_column(String(120))
    price_in_paise: Mapped[int] = mapped_column(Integer)
    duration_days: Mapped[int] = mapped_column(Integer)
    features_json: Mapped[str] = mapped_column(Text, default="[]")
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_type: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expiry_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    razorpay_payment_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    parking_slot_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("parking_slots.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[User] = relationship(back_populates="subscriptions")
    parking_slot: Mapped[Optional[ParkingSlot]] = relationship(back_populates="subscriptions")


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    amount_in_paise: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(8), default="INR")
    plan_type: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20), default="created")
    razorpay_order_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True, index=True)
    razorpay_payment_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    razorpay_signature: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[User] = relationship(back_populates="payments")


class ParkingSlot(Base):
    __tablename__ = "parking_slots"
    __table_args__ = (
        UniqueConstraint("tower", "floor", "zone", "slot_number", name="uq_slot_location"),
        Index("ix_slot_available", "is_premium", "is_occupied"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    tower: Mapped[str] = mapped_column(String(8))
    floor: Mapped[int] = mapped_column(Integer)
    zone: Mapped[str] = mapped_column(String(8))
    slot_number: Mapped[str] = mapped_column(String(16))
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    is_occupied: Mapped[bool] = mapped_column(Boolean, default=False)
    assigned_user_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id"), nullable=True, index=True
    )

    subscriptions: Mapped[list[Subscription]] = relationship(back_populates="parking_slot")


class ParkingHistory(Base):
    __tablename__ = "parking_history"
    __table_args__ = (Index("ix_history_plate_status", "vehicle_number", "status"),)

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    # Null for staff-registered walk-ins, who have no app account.
    user_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=True
    )
    vehicle_number: Mapped[str] = mapped_column(String(20), index=True)
    entry_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    exit_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    tower: Mapped[str] = mapped_column(String(8))
    floor: Mapped[int] = mapped_column(Integer)
    zone: Mapped[str] = mapped_column(String(8))
    slot_number: Mapped[str] = mapped_column(String(16))
    parking_slot_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("parking_slots.id"), nullable=True
    )
    subscription_type: Mapped[str] = mapped_column(String(20), default="hourly")
    status: Mapped[str] = mapped_column(String(20), default="parked")
    amount_in_paise: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    billing_type: Mapped[str] = mapped_column(String(20), default="hourly")
    # free | pending | paid — hourly exits with a charge start as "pending".
    payment_status: Mapped[str] = mapped_column(String(20), default="free")

    is_walk_in: Mapped[bool] = mapped_column(Boolean, default=False)
    driver_name: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    contact_phone: Mapped[Optional[str]] = mapped_column(String(15), nullable=True)
    # Staff member who registered / closed the session at the counter.
    created_by_staff_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    closed_by_staff_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )


class QrAccess(Base):
    __tablename__ = "qr_access"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    vehicle_id: Mapped[Optional[str]] = mapped_column(ForeignKey("vehicles.id"), nullable=True)
    subscription_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("subscriptions.id"), nullable=True
    )
    parking_slot_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("parking_slots.id"), nullable=True
    )
    token_hash: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    token_cipher: Mapped[str] = mapped_column(Text)  # opaque token returned to client
    is_permanent: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AppNotification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text)
    type: Mapped[str] = mapped_column(String(40), default="general")
    data_json: Mapped[str] = mapped_column(Text, default="{}")
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[User] = relationship(back_populates="notifications")


class DeviceToken(Base):
    __tablename__ = "device_tokens"
    __table_args__ = (UniqueConstraint("user_id", "token", name="uq_user_fcm"),)

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(512))
    platform: Mapped[str] = mapped_column(String(32), default="android")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[User] = relationship(back_populates="device_tokens")
