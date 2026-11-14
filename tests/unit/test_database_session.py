import pytest

from app.core.config import get_settings
from app.database.session import get_db, get_engine, get_session_factory

DATABASE_URL = "postgresql+psycopg://orderflow:orderflow@localhost:5432/orderflow"


def test_database_session_factory_uses_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", DATABASE_URL)
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("LOG_LEVEL", "INFO")

    get_settings.cache_clear()
    get_engine.cache_clear()
    get_session_factory.cache_clear()

    engine = get_engine()
    session = get_session_factory()()
    dependency = get_db()
    dependency_session = next(dependency)

    try:
        assert engine.url.drivername == "postgresql+psycopg"
        assert engine.url.username == "orderflow"
        assert engine.url.host == "localhost"
        assert engine.url.port == 5432
        assert engine.url.database == "orderflow"
        assert session.bind is engine
        assert dependency_session.bind is engine
    finally:
        session.close()
        dependency.close()
        engine.dispose()
        get_session_factory.cache_clear()
        get_engine.cache_clear()
        get_settings.cache_clear()
