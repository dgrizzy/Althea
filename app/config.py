from __future__ import annotations

from functools import lru_cache
from typing import Any

from pydantic import Field
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False)

    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    allowed_hosts: tuple[str, ...] = Field(default=("localhost", "127.0.0.1"), alias="ALLOWED_HOSTS")
    enforce_https_headers: bool = Field(default=False, alias="ENFORCE_HTTPS_HEADERS")

    @field_validator("allowed_hosts", mode="before")
    @classmethod
    def parse_allowed_hosts(cls, value: Any) -> tuple[str, ...]:
        if isinstance(value, str):
            items = tuple(host.strip() for host in value.split(",") if host.strip())
            return items or ("localhost", "127.0.0.1")
        if isinstance(value, (list, tuple)):
            return tuple(str(host).strip() for host in value if str(host).strip()) or ("localhost", "127.0.0.1")
        return ("localhost", "127.0.0.1")


@lru_cache
def get_settings() -> Settings:
    return Settings()
