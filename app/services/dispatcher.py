from __future__ import annotations

import logging

from app.clients.github_issues import GitHubIssuesClient, NullGitHubIssuesClient
from app.clients.openclaw import OpenClawClient
from app.config import Settings
from app.domain.events import SUPPORTED_EVENTS, SUPPORTED_ISSUES_ACTIONS
from app.domain.models import WebhookResult
from app.domain.rules import should_dispatch_opened_issue, target_repo_is_allowed
from app.domain.transform import transform_issue_to_task


class DispatcherService:
    def __init__(
        self,
        settings: Settings,
        openclaw_client: OpenClawClient,
        github_client: GitHubIssuesClient | NullGitHubIssuesClient,
    ) -> None:
        self.settings = settings
        self.openclaw_client = openclaw_client
        self.github_client = github_client
        self.logger = logging.getLogger(__name__)

    async def _safe_github_update(self, operation: str, coro) -> None:
        try:
            await coro
        except Exception as exc:  # noqa: BLE001
            self.logger.error(
                "github_writeback_failed",
                extra={"decision": operation, "error_type": exc.__class__.__name__},
            )

    async def handle(self, event: str, delivery_id: str, payload: dict) -> WebhookResult:
        if event not in SUPPORTED_EVENTS:
            return WebhookResult(
                accepted=False,
                reason="unsupported_event",
                delivery_id=delivery_id,
                dispatched=False,
            )

        action = payload.get("action", "")
        if action not in SUPPORTED_ISSUES_ACTIONS:
            return WebhookResult(
                accepted=False,
                reason="unsupported_action",
                delivery_id=delivery_id,
                dispatched=False,
            )

        if action == "opened":
            return await self._handle_opened(payload, delivery_id)

        if action == "edited":
            return WebhookResult(
                accepted=True,
                reason="issue_edited_no_dispatch",
                delivery_id=delivery_id,
                dispatched=False,
            )

        return WebhookResult(
            accepted=True,
            reason="issue_labeled_no_dispatch",
            delivery_id=delivery_id,
            dispatched=False,
        )

    async def _handle_opened(self, payload: dict, delivery_id: str) -> WebhookResult:
        decision = should_dispatch_opened_issue(
            payload=payload,
            allowed_repos=self.settings.allowed_repos,
            allowed_orgs=self.settings.allowed_orgs,
            allowed_senders=set(self.settings.allowed_github_senders),
            blocked_senders=set(self.settings.blocked_github_senders),
            allow_bot_senders=self.settings.allow_bot_senders,
        )

        if not decision.should_dispatch:
            self.logger.info(
                "event_ignored",
                extra={
                    "delivery_id": delivery_id,
                    "task_key": decision.task_key,
                    "decision": decision.reason,
                },
            )
            return WebhookResult(
                accepted=True,
                reason=decision.reason,
                delivery_id=delivery_id,
                dispatched=False,
                task_key=decision.task_key,
            )

        transform_result = transform_issue_to_task(payload, delivery_id)
        task = transform_result.task

        target_allowed, target_reason = target_repo_is_allowed(
            target_repo_full_name=task.target_repo,
            allowed_target_repos=self.settings.allowed_target_repos,
            allowed_target_orgs=self.settings.allowed_target_orgs,
        )
        if not target_allowed:
            self.logger.info(
                "event_ignored",
                extra={
                    "delivery_id": delivery_id,
                    "task_key": task.task_key,
                    "decision": target_reason,
                },
            )
            return WebhookResult(
                accepted=True,
                reason=target_reason,
                delivery_id=delivery_id,
                dispatched=False,
                task_key=task.task_key,
            )

        owner, repo = task.issue.repo.split("/", 1)
        issue_number = task.issue.number

        await self._safe_github_update(
            "add_running_label",
            self.github_client.add_labels(owner, repo, issue_number, ["althea:running"]),
        )
        await self._safe_github_update(
            "comment_dispatched",
            self.github_client.post_comment(
                owner,
                repo,
                issue_number,
                f"Dispatched to OpenClaw. Delivery: `{delivery_id}`.",
            ),
        )

        if transform_result.warnings:
            self.logger.info(
                "transform_warnings",
                extra={
                    "delivery_id": delivery_id,
                    "task_key": task.task_key,
                    "decision": ",".join(transform_result.warnings),
                },
            )

        result = await self.openclaw_client.dispatch_task(task)
        if result.success:
            comment = "OpenClaw accepted task"
            if result.run_id:
                comment += f". Run ID: `{result.run_id}`"
            await self._safe_github_update(
                "comment_openclaw_accepted",
                self.github_client.post_comment(owner, repo, issue_number, comment),
            )
            return WebhookResult(
                accepted=True,
                reason="dispatched",
                delivery_id=delivery_id,
                dispatched=True,
                run_id=result.run_id,
                task_key=task.task_key,
            )

        await self._safe_github_update(
            "add_error_label",
            self.github_client.add_labels(owner, repo, issue_number, ["althea:error"]),
        )
        await self._safe_github_update(
            "comment_dispatch_failed",
            self.github_client.post_comment(
                owner,
                repo,
                issue_number,
                f"Dispatch failed: `{result.error or 'unknown_error'}`. Retryable: `{result.retryable}`.",
            ),
        )

        return WebhookResult(
            accepted=True,
            reason="dispatch_failed",
            delivery_id=delivery_id,
            dispatched=False,
            task_key=task.task_key,
        )
