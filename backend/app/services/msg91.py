from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings
from app.core.exceptions import AppError

logger = logging.getLogger(__name__)

# Match MSG91's documented SendOTP host/path.
DEFAULT_OTP_URL = "https://control.msg91.com/api/v5/otp"


async def send_otp_sms(phone: str, otp: str) -> str:
    """Send OTP via MSG91 SendOTP v5 API.

    Returns the MSG91 ``request_id`` so delivery can be traced under
    SendOTP → Logs. ``type=success`` only means MSG91 accepted the request.
    """
    phone = (phone or "").strip()
    if len(phone) != 10 or not phone.isdigit():
        raise AppError("Invalid phone number for SMS OTP")
    otp = (otp or "").strip()
    if not otp.isdigit():
        raise AppError("Invalid OTP payload for SMS")

    settings = get_settings()
    if not settings.msg91_auth_key:
        raise AppError("MSG91 is not configured")
    if not settings.msg91_template_id:
        raise AppError("MSG91 template ID is not configured")

    otp_url = (settings.msg91_flow_url or "").strip() or DEFAULT_OTP_URL
    if otp_url.rstrip("/").endswith("/flow"):
        otp_url = DEFAULT_OTP_URL
    # Prefer the documented control host for SendOTP templates.
    if "api.msg91.com" in otp_url:
        otp_url = DEFAULT_OTP_URL

    # Docs put authkey/template/mobile in the query string.
    params = {
        "template_id": settings.msg91_template_id,
        "mobile": f"91{phone}",
        "authkey": settings.msg91_auth_key,
        "otp": otp,
        "otp_length": str(settings.otp_length),
        "otp_expiry": str(max(1, settings.otp_expiry_seconds // 60)),
    }
    if settings.msg91_sender_id:
        params["sender"] = settings.msg91_sender_id

    headers = {
        "authkey": settings.msg91_auth_key,
        "Content-Type": "application/json",
        "accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(otp_url, params=params, headers=headers, json={})
        body_text = (response.text or "")[:800]
        logger.info(
            "MSG91 OTP url=%s status=%s body=%s",
            otp_url,
            response.status_code,
            body_text,
        )

        try:
            data = response.json() if body_text else {}
        except Exception:
            data = {}

        if response.status_code >= 400:
            detail = (
                (data.get("message") if isinstance(data, dict) else None)
                or body_text
                or f"HTTP {response.status_code}"
            )
            raise AppError(f"Failed to send OTP SMS: {detail}")

        if isinstance(data, dict):
            err_type = str(data.get("type") or "").lower()
            if err_type == "error" or str(data.get("message") or "").lower() in {
                "error",
                "failure",
                "failed",
            }:
                detail = data.get("message") or data.get("msg") or body_text
                raise AppError(f"Failed to send OTP SMS: {detail}")

            request_id = str(data.get("request_id") or data.get("requestId") or "")
            if not request_id:
                raise AppError(
                    "MSG91 accepted the call but returned no request_id. "
                    "Check OTP → Templates / Authkey permissions."
                )
            return request_id

        raise AppError(f"Unexpected MSG91 response: {body_text or 'empty body'}")
