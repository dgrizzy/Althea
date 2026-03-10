import pytest

from app.api.health import healthz


@pytest.mark.asyncio
async def test_healthz_returns_ok() -> None:
    assert await healthz() == {"status": "ok"}
