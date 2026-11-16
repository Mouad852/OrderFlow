import pytest
from pydantic import ValidationError

from app.core.config import Settings, get_settings

DATABASE_URL = "postgresql+psycopg://orderflow:orderflow@localhost:5432/orderflow"


def test_settings_accepts_required_values() -> None:
    settings = Settings(
        database_url=DATABASE_URL,
        environment="test",
        log_level="INFO",
    )

    assert settings.environment == "test"
    assert settings.log_level == "INFO"
    assert settings.build_sha == "development"


def test_settings_requires_database_url() -> None:
    with pytest.raises(ValidationError, match="database_url"):
        Settings(
            environment="test",
            log_level="INFO",
        )


def test_get_settings_reads_environment_variables(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", DATABASE_URL)
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("LOG_LEVEL", "INFO")
    monkeypatch.setenv("BUILD_SHA", "abc123")

    settings = get_settings()

    assert settings.environment == "test"
    assert settings.build_sha == "abc123"
    get_settings.cache_clear()
