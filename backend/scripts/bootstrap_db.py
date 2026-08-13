"""Create tables + seed against the configured DATABASE_URL with progress logs."""

from __future__ import annotations

import asyncio
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text

from app.core.config import get_settings
from app.core.security import verify_password
from app.db import models  # noqa: F401
from app.db.seed import seed_reference_data, seed_staff_accounts
from app.db.session import Base, get_engine, get_session_factory, reset_engine
from sqlalchemy import select
from app.db.models import User


async def main() -> int:
    reset_engine()
    settings = get_settings()
    print(f"DB host: {settings.database_url.split('@')[-1]}")
    print(f"sqlite? {settings.is_sqlite}")

    t0 = time.perf_counter()
    engine = get_engine()
    print(f"[{time.perf_counter()-t0:.1f}s] engine ready")

    async with engine.begin() as conn:
        print(f"[{time.perf_counter()-t0:.1f}s] connected, creating tables...")
        await conn.run_sync(Base.metadata.create_all)
        print(f"[{time.perf_counter()-t0:.1f}s] create_all done")
        tables = await conn.scalar(
            text(
                "select count(*) from information_schema.tables "
                "where table_schema = 'public'"
            )
            if not settings.is_sqlite
            else text("select count(*) from sqlite_master where type='table'")
        )
        print(f"[{time.perf_counter()-t0:.1f}s] public tables: {tables}")

    async with get_session_factory()() as session:
        print(f"[{time.perf_counter()-t0:.1f}s] seeding reference data...")
        await seed_reference_data(session)
        print(f"[{time.perf_counter()-t0:.1f}s] seeding staff accounts...")
        await seed_staff_accounts(session)
        staff = await session.scalar(select(User).where(User.username == "staff"))
        admin = await session.scalar(select(User).where(User.username == "admin"))
        print(
            f"[{time.perf_counter()-t0:.1f}s] staff ok={staff is not None and verify_password(settings.staff_password, staff.password_hash)}"
        )
        print(
            f"[{time.perf_counter()-t0:.1f}s] admin ok={admin is not None and verify_password(settings.admin_password, admin.password_hash)}"
        )

    await engine.dispose()
    print(f"[{time.perf_counter()-t0:.1f}s] DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
