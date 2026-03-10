from __future__ import annotations

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False)

    github_webhook_secret: str = Field(default="change-me", alias="GITHUB_WEBHOOK_SECRET")
    github_app_id: str | None = Field(default=None, alias="GITHUB_APP_ID")
    github_app_private_key: str | None = Field(default=None, alias="GITHUB_APP_PRIVATE_KEY")
    github_installation_id: str | None = Field(default=None, alias="GITHUB_INSTALLATION_ID")

    openclaw_hook_url: str = Field(default="http://localhost:8081/hooks/agent", alias="OPENCLAW_HOOK_URL")
    openclaw_hook_token: str = Field(default="change-me", alias="OPENCLAW_HOOK_TOKEN")
    openclaw_hook_name: str = Field(default="GitHub", alias="OPENCLAW_HOOK_NAME")
    openclaw_agent_id: str | None = Field(default=None, alias="OPENCLAW_AGENT_ID")
    openclaw_hook_deliver: bool = Field(default=False, alias="OPENCLAW_HOOK_DELIVER")
    openclaw_wake_mode: str = Field(default="now", alias="OPENCLAW_WAKE_MODE")
    openclaw_allow_request_session_key: bool = Field(default=False, alias="OPENCLAW_ALLOW_REQUEST_SESSION_KEY")

    allowed_repos: list[str] = Field(default_factory=list, alias="ALLOWED_REPOS")
    allowed_orgs: list[str] = Field(default_factory=list, alias="ALLOWED_ORGS")
    allowed_target_repos: list[str] = Field(default_factory=list, alias="ALLOWED_TARGET_REPOS")
    allowed_target_orgs: list[str] = Field(default_factory=list, alias="ALLOWED_TARGET_ORGS")
    allowed_github_senders: list[str] = Field(default_factory=list, alias="ALLOWED_GITHUB_SENDERS")
    blocked_github_senders: list[str] = Field(default_factory=list, alias="BLOCKED_GITHUB_SENDERS")
    allow_bot_senders: bool = Field(default=False, alias="ALLOW_BOT_SENDERS")

    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    request_timeout_seconds: float = Field(default=15.0, alias="REQUEST_TIMEOUT_SECONDS")
    rate_limit_enabled: bool = Field(default=True, alias="RATE_LIMIT_ENABLED")
    rate_limit_window_seconds: int = Field(default=60, alias="RATE_LIMIT_WINDOW_SECONDS")
    rate_limit_max_requests: int = Field(default=120, alias="RATE_LIMIT_MAX_REQUESTS")
    delivery_replay_ttl_seconds: int = Field(default=3600, alias="DELIVERY_REPLAY_TTL_SECONDS")
    delivery_replay_max_entries: int = Field(default=20000, alias="DELIVERY_REPLAY_MAX_ENTRIES")

    github_api_url: str = Field(default="https://api.github.com", alias="GITHUB_API_URL")

    @field_validator(
        "allowed_repos",
        "allowed_orgs",
        "allowed_target_repos",
        "allowed_target_orgs",
        "allowed_github_senders",
        "blocked_github_senders",
        mode="before",
    )
    @classmethod
    def parse_csv(cls, value: str | list[str] | None) -> list[str]:
        if value is None:
            return []
        if isinstance(value, list):
            return [v.strip() for v in value if v and v.strip()]
        return [v.strip() for v in value.split(",") if v and v.strip()]

    @property
    def normalized_private_key(self) -> str | None:
        if not self.github_app_private_key:
            return None
        return self.github_app_private_key.replace("\\n", "\n")

    @property
    def github_writeback_enabled(self) -> bool:
        return bool(self.github_app_id and self.github_installation_id and self.normalized_private_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
