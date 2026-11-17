from functools import lru_cache

from pydantic import PostgresDsn, model_validator
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
    build_sha: str = "development"
    applicationinsights_connection_string: str | None = None

    auth_enabled: bool = False
    entra_tenant_id: str | None = None
    entra_api_client_id: str | None = None
    entra_required_role: str = "OrderFlow.Orders.ReadWrite"

    @model_validator(mode="after")
    def validate_entra_configuration(self) -> "Settings":
        if self.auth_enabled and (not self.entra_tenant_id or not self.entra_api_client_id):
            raise ValueError("AUTH_ENABLED requires ENTRA_TENANT_ID and ENTRA_API_CLIENT_ID.")

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
