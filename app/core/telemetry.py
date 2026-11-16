import logging
import os

from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)


def telemetry_enabled() -> bool:
    return bool(os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"))


def configure_telemetry() -> bool:
    connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")

    if not connection_string:
        logger.info("Azure Monitor telemetry is disabled: no connection string is configured")
        return False

    os.environ.setdefault("OTEL_SERVICE_NAME", "orderflow-api")

    from microsoft.opentelemetry import use_microsoft_opentelemetry

    use_microsoft_opentelemetry(
        enable_azure_monitor=True,
        azure_monitor_connection_string=connection_string,
    )

    logger.info("Azure Monitor telemetry is enabled")
    return True


def instrument_sqlalchemy(engine: Engine) -> bool:
    if not telemetry_enabled():
        return False

    from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

    SQLAlchemyInstrumentor().instrument(engine=engine)
    return True
