from __future__ import annotations

from urllib.parse import quote

import httpx

from app.clients.github_app import GitHubAppClient


class NullGitHubIssuesClient:
    async def add_labels(self, owner: str, repo: str, issue_number: int, labels: list[str]) -> None:
        return None

    async def remove_label(self, owner: str, repo: str, issue_number: int, label: str) -> None:
        return None

    async def post_comment(self, owner: str, repo: str, issue_number: int, body: str) -> None:
        return None

    async def update_project_fields(self, task_key: str, fields: dict[str, str]) -> None:
        return None


class GitHubIssuesClient:
    def __init__(
        self,
        app_client: GitHubAppClient,
        api_url: str = "https://api.github.com",
        timeout_seconds: float = 15.0,
    ) -> None:
        self.app_client = app_client
        self.api_url = api_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    async def _headers(self) -> dict[str, str]:
        token = await self.app_client.get_installation_token()
        return {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }

    async def add_labels(self, owner: str, repo: str, issue_number: int, labels: list[str]) -> None:
        if not labels:
            return

        url = f"{self.api_url}/repos/{owner}/{repo}/issues/{issue_number}/labels"
        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(url, headers=await self._headers(), json={"labels": labels})

        response.raise_for_status()

    async def remove_label(self, owner: str, repo: str, issue_number: int, label: str) -> None:
        safe_label = quote(label, safe="")
        url = f"{self.api_url}/repos/{owner}/{repo}/issues/{issue_number}/labels/{safe_label}"

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.delete(url, headers=await self._headers())

        if response.status_code not in (200, 204, 404):
            response.raise_for_status()

    async def post_comment(self, owner: str, repo: str, issue_number: int, body: str) -> None:
        url = f"{self.api_url}/repos/{owner}/{repo}/issues/{issue_number}/comments"
        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(url, headers=await self._headers(), json={"body": body})

        response.raise_for_status()

    async def update_project_fields(self, task_key: str, fields: dict[str, str]) -> None:
        # GitHub Projects v2 item field mutation is intentionally deferred for v1.
        # Keep this interface so dispatcher/status-sync can call it in phase 2.
        return None
