from functools import lru_cache
from pathlib import Path
from typing import List
from urllib.parse import parse_qsl, quote, unquote, urlencode, urlsplit, urlunsplit

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Always load backend/.env regardless of the process working directory.
_BACKEND_DIR = Path(__file__).resolve().parents[2]
_ENV_FILE = _BACKEND_DIR / ".env"

_DEFAULT_SQLITE_URL = "sqlite+aiosqlite:///./multiparking.db"

_PLACEHOLDER_MARKERS = ("your_project", "your_password", "your-project")

_SCHEME_REWRITES = (
    ("postgresql+asyncpg://", "postgresql+asyncpg://"),
    ("postgres+asyncpg://", "postgresql+asyncpg://"),
    ("postgresql+psycopg2://", "postgresql+asyncpg://"),
    ("postgresql+psycopg://", "postgresql+asyncpg://"),
    ("postgres://", "postgresql+asyncpg://"),
    ("postgresql://", "postgresql+asyncpg://"),
)


def normalize_database_url(value: object) -> str:
    """SQLite only for blank / copy-paste placeholders. Real Postgres is kept.

    - ``postgresql://`` / ``postgres://`` → ``postgresql+asyncpg://``
    - URL-encodes user/password so special characters do not break parsing
    - Strips libpq ``sslmode`` (asyncpg uses connect_args SSL instead)
    """
    raw = (str(value) if value is not None else "").strip().strip('"').strip("'")
    if not raw:
        return _DEFAULT_SQLITE_URL
    lowered = raw.lower()
    if any(marker in lowered for marker in _PLACEHOLDER_MARKERS):
        return _DEFAULT_SQLITE_URL
    if lowered.startswith("sqlite"):
        return raw

    for src, dst in _SCHEME_REWRITES:
        if lowered.startswith(src):
            raw = dst + raw[len(src) :]
            break

    parts = urlsplit(raw)
    if not parts.hostname:
        return raw

    user = quote(unquote(parts.username or ""), safe=".-_")
    password = parts.password
    auth = user
    if password is not None:
        auth = f"{user}:{quote(unquote(password), safe='')}"
    host = parts.hostname
    if parts.port:
        host = f"{parts.hostname}:{parts.port}"
    netloc = f"{auth}@{host}" if auth else host

    query = urlencode(
        [
            (k, v)
            for k, v in parse_qsl(parts.query, keep_blank_values=True)
            if k.lower() not in {"sslmode", "ssl"}
        ]
    )
    path = parts.path or "/postgres"
    return urlunsplit((parts.scheme, netloc, path, query, parts.fragment))


def redact_database_url(url: str) -> str:
    """Safe-to-log form (password replaced)."""
    parts = urlsplit(url)
    if parts.password is None:
        return url
    host = parts.hostname or ""
    if parts.port:
        host = f"{host}:{parts.port}"
    user = parts.username or ""
    netloc = f"{user}:***@{host}" if user else f"***@{host}"
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def describe_db_connect_error(url: str, exc: BaseException) -> str:
    parts = urlsplit(url)
    host = parts.hostname or "(unknown host)"
    port = parts.port or ("5432" if "postgres" in (parts.scheme or "") else "")
    return (
        f"Cannot connect to Postgres at {host}:{port or '?'}. "
        "A real DATABASE_URL is never silently replaced with SQLite. "
        "Check: (1) host / project ref, (2) SSL (Supabase requires SSL), "
        "(3) URL-encode special characters in the password "
        "(@ → %40, : → %3A, / → %2F, # → %23, % → %25), "
        "(4) use the URI from Supabase → Project Settings → Database. "
        f"Redacted URL: {redact_database_url(url)}. "
        f"Original error: {type(exc).__name__}: {exc}"
    )


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "MultiParking Tower API"
    app_env: str = "development"
    database_url: str = _DEFAULT_SQLITE_URL

    jwt_secret: str = "dev-jwt-secret-change-me"
    jwt_access_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 30
    qr_secret: str = "dev-qr-secret-change-me-32-bytes!!"

    msg91_auth_key: str = ""
    msg91_template_id: str = ""
    msg91_sender_id: str = "MPARK"
    msg91_flow_url: str = "https://control.msg91.com/api/v5/flow/"

    otp_dev_mode: bool = True
    otp_length: int = 6
    otp_expiry_seconds: int = 300
    otp_resend_seconds: int = 30
    otp_max_attempts: int = 5
    otp_max_per_hour: int = 5

    # Firebase Phone Auth — project id from google-services.json / Console.
    firebase_project_id: str = "multiparking-tower"

    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    # Dashboard → Webhooks secret. Empty disables the webhook endpoint.
    razorpay_webhook_secret: str = ""

    cors_origins: str = "*"
    gate_api_key: str = "dev-gate-key-change-me"
    # Pay-as-you-go rate for users without a subscription (₹50 / hour).
    hourly_rate_paise: int = 5000
    # Non-refundable booking fee charged before hourly slot + QR issuance.
    # Credited against the final exit charge; never refunded on cancel/unused.
    booking_fee_paise: int = 5000

    # Gate-staff console account, provisioned on startup.
    staff_username: str = "staff"
    staff_password: str = "Parking@123"
    staff_display_name: str = "Gate Staff"
    admin_username: str = "admin"
    admin_password: str = "Admin@123"
    admin_display_name: str = "Tower Admin"

    @field_validator("database_url", mode="before")
    @classmethod
    def _coerce_database_url(cls, value: object) -> str:
        return normalize_database_url(value)

    @property
    def cors_origin_list(self) -> List[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def msg91_enabled(self) -> bool:
        return bool(self.msg91_auth_key) and not self.otp_dev_mode

    @property
    def razorpay_enabled(self) -> bool:
        return bool(self.razorpay_key_id and self.razorpay_key_secret)

    @property
    def razorpay_webhook_enabled(self) -> bool:
        return bool(self.razorpay_webhook_secret)

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")

    @property
    def is_production(self) -> bool:
        return self.app_env.strip().lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
