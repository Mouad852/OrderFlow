from functools import lru_cache

from pydantic import PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: PostgresDsn
    environment: str
    log_level: str
    applicationinsights_connection_string: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
