"""Unit tests for DATABASE_URL normalization (no live database)."""

from app.core.config import normalize_database_url, redact_database_url

_SQLITE = "sqlite+aiosqlite:///./multiparking.db"


def test_blank_and_placeholder_use_sqlite():
    assert normalize_database_url("") == _SQLITE
    assert normalize_database_url("   ") == _SQLITE
    assert "sqlite" in normalize_database_url(
        "postgresql+asyncpg://postgres:YOUR_PASSWORD@db.YOUR_PROJECT.supabase.co:5432/postgres"
    )


def test_real_supabase_url_is_not_coerced_to_sqlite():
    url = "postgresql://postgres:secret@db.abcdefghijklmn.supabase.co:5432/postgres"
    out = normalize_database_url(url)
    assert out.startswith("postgresql+asyncpg://")
    assert "abcdefghijklmn.supabase.co" in out
    assert "sqlite" not in out


def test_postgres_scheme_rewritten_and_sslmode_stripped():
    url = (
        "postgres://postgres.abc123:s3cret@aws-0-ap-south-1.pooler.supabase.com:6543"
        "/postgres?sslmode=require"
    )
    out = normalize_database_url(url)
    assert out.startswith("postgresql+asyncpg://")
    assert "sslmode" not in out
    assert "6543" in out
    assert "postgres.abc123" in out


def test_password_is_url_encoded():
    url = "postgresql://postgres:p%40ss@db.abcdefghijklmn.supabase.co:5432/postgres"
    out = normalize_database_url(url)
    assert "p%40ss" in out
    assert redact_database_url(out).count("***") == 1
    assert "p%40ss" not in redact_database_url(out)
