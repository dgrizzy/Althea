from __future__ import annotations

import time
from datetime import datetime, timezone

import httpx
import jwt


class GitHubAppClient:
    def __init__(
        self,
        app_id: str,
        private_key: str,
        installation_id: str,
        api_url: str = "https://api.github.com",
        timeout_seconds: float = 15.0,
    ) -> None:
        self.app_id = app_id
        self.private_key = private_key
        self.installation_id = installation_id
        self.api_url = api_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

        self._cached_token: str | None = None
        self._cached_token_expiry: datetime | None = None

    def _build_app_jwt(self) -> str:
        now = int(time.time())
        payload = {"iat": now - 60, "exp": now + 540, "iss": self.app_id}
        return jwt.encode(payload, self.private_key, algorithm="RS256")

    def _token_valid(self) -> bool:
        if not self._cached_token or not self._cached_token_expiry:
            return False
        return datetime.now(timezone.utc) < self._cached_token_expiry

    async def get_installation_token(self) -> str:
        if self._token_valid():
            return self._cached_token or ""

        app_jwt = self._build_app_jwt()
        url = f"{self.api_url}/app/installations/{self.installation_id}/access_tokens"
        headers = {
            "Authorization": f"Bearer {app_jwt}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(url, headers=headers)

        response.raise_for_status()
        payload = response.json()

        token = payload["token"]
        expires_at = payload["expires_at"].replace("Z", "+00:00")
        expiry = datetime.fromisoformat(expires_at)

        self._cached_token = token
        self._cached_token_expiry = expiry
        return token
