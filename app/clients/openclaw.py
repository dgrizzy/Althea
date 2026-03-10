from __future__ import annotations

import re

import httpx

from app.domain.models import NormalizedTask, OpenClawDispatchResult


class OpenClawClient:
    def __init__(
        self,
        hook_url: str,
        token: str,
        timeout_seconds: float = 15.0,
        hook_name: str = "GitHub",
        agent_id: str | None = None,
        deliver: bool = False,
        wake_mode: str = "now",
        allow_request_session_key: bool = False,
    ) -> None:
        self.hook_url = hook_url
        self.token = token
        self.timeout_seconds = timeout_seconds
        self.hook_name = hook_name
        self.agent_id = agent_id
        self.deliver = deliver
        self.wake_mode = wake_mode
        self.allow_request_session_key = allow_request_session_key

    @staticmethod
    def _format_list(items: list[str]) -> str:
        if not items:
            return "- (none)"
        return "\n".join(f"- {item}" for item in items)

    @staticmethod
    def _sanitize_session_key(task_key: str) -> str:
        cleaned = re.sub(r"[^a-zA-Z0-9:_-]", "-", task_key)
        return f"hook:althea:{cleaned}"[:180]

    @classmethod
    def build_agent_message(cls, task: NormalizedTask) -> str:
        return "\n".join(
            [
                "GitHub task dispatch from Althea.",
                "",
                "Task Metadata:",
                f"- Task Key: {task.task_key}",
                f"- Source Event: {task.event_id}",
                f"- Requested By: {task.requested_by}",
                f"- Task Type: {task.task_type}",
                f"- Risk Level: {task.risk_level}",
                f"- Execution Mode: {task.execution_mode}",
                f"- Target Repo: {task.target_repo}",
                f"- Target Branch: {task.target_branch}",
                f"- Issue URL: {task.issue.url}",
                "",
                "Acceptance Criteria:",
                cls._format_list(task.acceptance_criteria),
                "",
                "Constraints:",
                cls._format_list(task.constraints),
                "",
                "Issue Description:",
                task.description or "(empty)",
            ]
        )

    def build_agent_payload(self, task: NormalizedTask) -> dict:
        payload: dict[str, str | bool] = {
            "message": self.build_agent_message(task),
            "name": self.hook_name,
            "wakeMode": self.wake_mode,
            "deliver": self.deliver,
        }

        if self.agent_id:
            payload["agentId"] = self.agent_id

        if self.allow_request_session_key:
            payload["sessionKey"] = self._sanitize_session_key(task.task_key)

        return payload

    async def dispatch_task(self, task: NormalizedTask) -> OpenClawDispatchResult:
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }
        payload = self.build_agent_payload(task)

        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                response = await client.post(self.hook_url, json=payload, headers=headers)
        except httpx.TimeoutException:
            return OpenClawDispatchResult(success=False, error="timeout", retryable=True)
        except httpx.HTTPError as exc:
            return OpenClawDispatchResult(success=False, error=str(exc), retryable=True)

        run_id = None
        try:
            payload = response.json()
            run_id = payload.get("run_id") or payload.get("session_id") or payload.get("sessionKey")
        except ValueError:
            payload = {}

        if 200 <= response.status_code < 300:
            return OpenClawDispatchResult(success=True, status_code=response.status_code, run_id=run_id)

        retryable = response.status_code >= 500
        error = payload.get("error") if isinstance(payload, dict) else response.text
        return OpenClawDispatchResult(
            success=False,
            status_code=response.status_code,
            run_id=run_id,
            error=error or f"http_{response.status_code}",
            retryable=retryable,
        )
