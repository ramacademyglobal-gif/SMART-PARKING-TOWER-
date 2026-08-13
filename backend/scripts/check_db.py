"""Connectivity smoke test for the configured DATABASE_URL.

Run: python -m scripts.check_db
"""

from __future__ import annotations

import asyncio
import socket
import sys
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.db.session import get_engine  # noqa: E402


def _resolve(host: str, port: int) -> None:
    print(f"Resolving {host} ...")
    try:
        infos = socket.getaddrinfo(host, port, proto=socket.IPPROTO_TCP)
    except socket.gaierror as exc:
        print(f"  DNS FAILED: {exc}")
        return
    for family, _, _, _, sockaddr in infos:
        print(f"  {family.name} -> {sockaddr[0]}")


async def main() -> int:
    settings = get_settings()
    url = settings.database_url
    print(f"DATABASE_URL = {url.split('@')[-1] if '@' in url else url}")

    if not settings.is_sqlite:
        parts = urlsplit(url)
        if parts.hostname:
            _resolve(parts.hostname, parts.port or 5432)

    try:
        engine = get_engine()
        async with engine.connect() as conn:
            version = await conn.scalar(text("select version()"))
            print(f"CONNECTED OK\n  {version}")
        await engine.dispose()
    except Exception as exc:  # noqa: BLE001
        print(f"CONNECT FAILED: {type(exc).__name__}: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
