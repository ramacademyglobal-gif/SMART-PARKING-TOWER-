from contextlib import asynccontextmanager
import asyncio
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import describe_db_connect_error, get_settings, redact_database_url
from app.db import models  # noqa: F401
from app.db.seed import seed_reference_data, seed_staff_accounts
from app.db.session import get_engine, get_session_factory, Base

logger = logging.getLogger("multiparking")


def _log_production_warnings(settings) -> None:
    if not settings.is_production:
        return
    if settings.otp_dev_mode:
        logger.warning(
            "APP_ENV=production but OTP_DEV_MODE=true — legacy /auth/send-otp accepts "
            "OTP 123456. Member login uses Firebase Phone Auth (POST /auth/firebase), "
            "not MSG91. OTP_DEV_MODE does not affect Firebase member login."
        )
    if not settings.razorpay_enabled:
        logger.warning(
            "APP_ENV=production but Razorpay keys are empty — checkout is stub/dev-only. "
            "Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET (never put the secret in Flutter)."
        )
    if settings.is_sqlite:
        logger.warning(
            "APP_ENV=production is using SQLite. Set DATABASE_URL to Supabase/Postgres "
            "for a shared cloud database. SQLite is laptop-only."
        )


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    logger.info("Database URL (redacted): %s", redact_database_url(settings.database_url))
    _log_production_warnings(settings)

    engine = get_engine()
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as exc:  # noqa: BLE001 — convert to an actionable startup error
        if not settings.is_sqlite:
            raise RuntimeError(describe_db_connect_error(settings.database_url, exc)) from exc
        raise

    async with get_session_factory()() as session:
        # Reseeds when empty or slot count ≠ 1100 (Tower A, 11×100).
        await seed_reference_data(session)
        await seed_staff_accounts(session)

    try:
        from app.services.firebase_auth import warm_firebase_certs

        await asyncio.to_thread(warm_firebase_certs)
    except Exception:  # noqa: BLE001 — never block startup on optional FCM certs
        pass
    yield
    await engine.dispose()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        # Browsers reject credentials with wildcard origins; local Flutter web
        # needs open CORS without credentials cookies.
        allow_credentials=settings.cors_origins.strip() != "*",
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(api_router, prefix="/v1")

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException):
        detail = exc.detail
        if isinstance(detail, dict):
            message = detail.get("message") or detail.get("error") or str(detail)
        else:
            message = str(detail)
        return JSONResponse(
            status_code=exc.status_code,
            content={"message": message, "error": message},
        )

    @app.get("/health")
    async def health():
        return {"status": "ok", "app": settings.app_name, "env": settings.app_env}

    return app


app = create_app()
