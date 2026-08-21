"""Additive column patches for existing databases.

``create_all`` does not alter existing tables. These IF NOT EXISTS statements
keep production Supabase/Postgres (and local SQLite) compatible without wiping
slot inventory.
"""

from __future__ import annotations

import logging

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

logger = logging.getLogger("multiparking.schema")

_PATCHES: list[tuple[str, str, str]] = [
    ("parking_history", "booking_fee_paise", "INTEGER DEFAULT 0"),
    ("parking_history", "booking_fee_paid", "BOOLEAN DEFAULT FALSE"),
    ("parking_history", "booking_fee_payment_id", "VARCHAR(64)"),
    ("parking_history", "gross_amount_in_paise", "INTEGER"),
    ("qr_access", "booking_fee_paise", "INTEGER DEFAULT 0"),
    ("qr_access", "booking_fee_paid", "BOOLEAN DEFAULT FALSE"),
    ("qr_access", "booking_fee_payment_id", "VARCHAR(64)"),
]


async def ensure_schema_patches(engine: AsyncEngine) -> None:
    dialect = engine.dialect.name
    async with engine.begin() as conn:
        for table, column, col_type in _PATCHES:
            if dialect == "sqlite":
                # SQLite lacks IF NOT EXISTS for ADD COLUMN on older builds;
                # ignore duplicate-column errors.
                try:
                    await conn.execute(
                        text(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")
                    )
                    logger.info("Added column %s.%s", table, column)
                except Exception as exc:  # noqa: BLE001
                    if "duplicate column" not in str(exc).lower():
                        logger.debug("Skip %s.%s: %s", table, column, exc)
            else:
                await conn.execute(
                    text(
                        f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS "
                        f"{column} {col_type}"
                    )
                )
