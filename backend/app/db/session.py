from collections.abc import AsyncGenerator
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings


class Base(DeclarativeBase):
    pass


_engine = None
_session_factory = None


def get_engine():
    global _engine, _session_factory
    if _engine is None:
        settings = get_settings()
        if settings.is_sqlite:
            connect_args: dict = {"check_same_thread": False}
            engine_kwargs: dict = {}
        else:
            # Supabase pooler (pgbouncer, port 6543) rejects reused prepared names.
            connect_args = {
                "timeout": 60,
                "command_timeout": 60,
                "ssl": "require",
                "statement_cache_size": 0,
                "prepared_statement_name_func": lambda: f"__mp_{uuid4().hex}__",
            }
            engine_kwargs = {
                "pool_pre_ping": True,
                "pool_size": 3,
                "max_overflow": 2,
                "pool_recycle": 300,
            }
        _engine = create_async_engine(
            settings.database_url,
            echo=False,
            connect_args=connect_args,
            **engine_kwargs,
        )
        _session_factory = async_sessionmaker(
            _engine, class_=AsyncSession, expire_on_commit=False
        )
    return _engine


def get_session_factory():
    get_engine()
    assert _session_factory is not None
    return _session_factory


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    factory = get_session_factory()
    async with factory() as session:
        yield session


def reset_engine() -> None:
    """Used by tests to rebuild engine after env changes."""
    global _engine, _session_factory
    _engine = None
    _session_factory = None
