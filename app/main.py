from __future__ import annotations

from fastapi import FastAPI

from app.api.github_webhook import router as github_router
from app.api.health import router as health_router
from app.clients.github_app import GitHubAppClient
from app.clients.github_issues import GitHubIssuesClient, NullGitHubIssuesClient
from app.clients.openclaw import OpenClawClient
from app.config import Settings, get_settings
from app.logging import configure_logging
from app.security.rate_limit import FixedWindowRateLimiter
from app.security.replay_protection import DeliveryReplayProtector
from app.services.dispatcher import DispatcherService


def _build_dispatcher(settings: Settings) -> DispatcherService:
    openclaw_client = OpenClawClient(
        hook_url=settings.openclaw_hook_url,
        token=settings.openclaw_hook_token,
        timeout_seconds=settings.request_timeout_seconds,
        hook_name=settings.openclaw_hook_name,
        agent_id=settings.openclaw_agent_id,
        deliver=settings.openclaw_hook_deliver,
        wake_mode=settings.openclaw_wake_mode,
        allow_request_session_key=settings.openclaw_allow_request_session_key,
    )

    if settings.github_writeback_enabled:
        app_client = GitHubAppClient(
            app_id=settings.github_app_id or "",
            private_key=settings.normalized_private_key or "",
            installation_id=settings.github_installation_id or "",
            api_url=settings.github_api_url,
            timeout_seconds=settings.request_timeout_seconds,
        )
        github_client = GitHubIssuesClient(
            app_client=app_client,
            api_url=settings.github_api_url,
            timeout_seconds=settings.request_timeout_seconds,
        )
    else:
        github_client = NullGitHubIssuesClient()

    return DispatcherService(settings=settings, openclaw_client=openclaw_client, github_client=github_client)


def create_app(settings: Settings | None = None, dispatcher: DispatcherService | None = None) -> FastAPI:
    runtime_settings = settings or get_settings()
    configure_logging(runtime_settings.log_level)

    app = FastAPI(title="Althea", version="0.1.0")
    app.state.settings = runtime_settings
    app.state.dispatcher = dispatcher or _build_dispatcher(runtime_settings)
    app.state.rate_limiter = FixedWindowRateLimiter(
        window_seconds=runtime_settings.rate_limit_window_seconds,
        max_requests=runtime_settings.rate_limit_max_requests,
    )
    app.state.replay_protector = DeliveryReplayProtector(
        ttl_seconds=runtime_settings.delivery_replay_ttl_seconds,
        max_entries=runtime_settings.delivery_replay_max_entries,
    )

    app.include_router(health_router)
    app.include_router(github_router)
    return app


app = create_app()
