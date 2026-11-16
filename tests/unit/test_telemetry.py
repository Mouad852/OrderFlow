import pytest

from app.core.telemetry import configure_telemetry


def test_telemetry_is_disabled_without_a_connection_string(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)

    assert configure_telemetry() is False
