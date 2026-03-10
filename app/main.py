from __future__ import annotations

from fastapi import FastAPI

from app.config import Settings, get_settings
from app.logging import configure_logging


def create_app(settings: Settings | None = None) -> FastAPI:
    runtime_settings = settings or get_settings()
    configure_logging(runtime_settings.log_level)

    app = FastAPI(title="Althea", version="0.1.0")
    app.state.settings = runtime_settings
    return app


app = create_app()
