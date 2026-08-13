from fastapi import APIRouter

from app.api.v1 import (
    auth,
    billing,
    config,
    notifications,
    parking,
    qr,
    staff,
    users,
    vehicles,
)

api_router = APIRouter()
api_router.include_router(config.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(vehicles.router)
api_router.include_router(billing.plans_router)
api_router.include_router(billing.subs_router)
api_router.include_router(billing.payments_router)
api_router.include_router(parking.router)
api_router.include_router(qr.router)
api_router.include_router(staff.router)
api_router.include_router(notifications.notifications_router)
api_router.include_router(notifications.fcm_router)
api_router.include_router(notifications.gate_router)
