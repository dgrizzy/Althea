from __future__ import annotations

from pydantic import BaseModel, Field


class DispatchDecision(BaseModel):
    should_dispatch: bool
    reason: str
    task_key: str | None = None


class IssueRef(BaseModel):
    repo: str
    number: int
    url: str


class ControlFlags(BaseModel):
    require_human_approval: bool = True
    allow_pr_open: bool = True
    allow_issue_comment: bool = True


class NormalizedTask(BaseModel):
    source: str = "github"
    event_id: str
    task_key: str
    title: str
    description: str
    target_repo: str
    target_branch: str = "main"
    task_type: str = "other"
    risk_level: str = "medium"
    execution_mode: str = "plan-only"
    acceptance_criteria: list[str] = Field(default_factory=list)
    constraints: list[str] = Field(default_factory=list)
    requested_by: str
    issue: IssueRef
    controls: ControlFlags = Field(default_factory=ControlFlags)


class TransformationResult(BaseModel):
    task: NormalizedTask
    warnings: list[str] = Field(default_factory=list)


class OpenClawDispatchResult(BaseModel):
    success: bool
    status_code: int | None = None
    run_id: str | None = None
    error: str | None = None
    retryable: bool = False


class WebhookResult(BaseModel):
    accepted: bool
    reason: str
    delivery_id: str
    dispatched: bool
    run_id: str | None = None
    task_key: str | None = None
