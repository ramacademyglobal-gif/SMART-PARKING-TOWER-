"""Drop and recreate the public schema, then seed.

Use only against the app database — this wipes all tables.
"""

from __future__ import annotations

import asyncio
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select, text

from app.core.config import get_settings
from app.core.security import verify_password
from app.db import models  # noqa: F401
from app.db.models import User
from app.db.seed import seed_reference_data, seed_staff_accounts
from app.db.session import Base, get_engine, get_session_factory, reset_engine


async def main() -> int:
    reset_engine()
    settings = get_settings()
    if settings.is_sqlite:
        print("This reset script is for Postgres only.")
        return 1

    print(f"DB host: {settings.database_url.split('@')[-1]}")
    t0 = time.perf_counter()
    engine = get_engine()

    async with engine.begin() as conn:
        print(f"[{time.perf_counter()-t0:.1f}s] resetting public schema...")
        await conn.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
        await conn.execute(text("CREATE SCHEMA public"))
        await conn.execute(text("GRANT ALL ON SCHEMA public TO postgres"))
        await conn.execute(text("GRANT ALL ON SCHEMA public TO public"))
        print(f"[{time.perf_counter()-t0:.1f}s] creating tables...")
        await conn.run_sync(Base.metadata.create_all)
        print(f"[{time.perf_counter()-t0:.1f}s] create_all done")

    async with get_session_factory()() as session:
        print(f"[{time.perf_counter()-t0:.1f}s] seeding...")
        await seed_reference_data(session)
        await seed_staff_accounts(session)
        staff = await session.scalar(select(User).where(User.username == "staff"))
        admin = await session.scalar(select(User).where(User.username == "admin"))
        print(
            f"staff={staff is not None and verify_password(settings.staff_password, staff.password_hash)}"
        )
        print(
            f"admin={admin is not None and verify_password(settings.admin_password, admin.password_hash)}"
        )

    await engine.dispose()
    print(f"[{time.perf_counter()-t0:.1f}s] DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
