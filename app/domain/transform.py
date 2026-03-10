from __future__ import annotations

import re

from app.domain.models import IssueRef, NormalizedTask, TransformationResult
from app.domain.rules import build_task_key

HEADING_PATTERN = re.compile(r"^#{1,6}\s*(.+?)\s*$")

VALID_TASK_TYPES = {"bugfix", "feature", "ops", "docs", "other"}
VALID_RISK_LEVELS = {"low", "medium", "high"}
VALID_EXECUTION_MODES = {"plan-only", "execute"}


def _parse_sections(markdown: str) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current = ""
    sections[current] = []

    for line in (markdown or "").splitlines():
        match = HEADING_PATTERN.match(line.strip())
        if match:
            current = match.group(1).strip().lower()
            sections.setdefault(current, [])
            continue
        sections.setdefault(current, []).append(line)

    return {k: "\n".join(v).strip() for k, v in sections.items()}


def _coerce_list(value: str) -> list[str]:
    if not value:
        return []
    items: list[str] = []
    for raw_line in value.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("- "):
            line = line[2:].strip()
        items.append(line)
    return items


def _normalize(value: str, valid: set[str], default: str) -> str:
    candidate = (value or "").strip().lower()
    return candidate if candidate in valid else default


def transform_issue_to_task(payload: dict, delivery_id: str) -> TransformationResult:
    warnings: list[str] = []

    issue = payload.get("issue", {})
    repo = payload.get("repository", {})
    sender = payload.get("sender", {})

    repo_full_name = repo.get("full_name", "")
    issue_number = int(issue.get("number", 0))
    task_key = build_task_key(repo_full_name, issue_number)

    title = issue.get("title", "")
    body = issue.get("body", "") or ""
    sections = _parse_sections(body)

    target_repo = sections.get("target repo", "").strip() or repo_full_name
    if not sections.get("target repo", "").strip():
        warnings.append("missing_target_repo_defaulted")

    target_branch = sections.get("target branch", "").strip() or "main"

    task_type = _normalize(sections.get("task type", ""), VALID_TASK_TYPES, "other")
    risk_level = _normalize(sections.get("risk level", ""), VALID_RISK_LEVELS, "medium")
    execution_mode = _normalize(sections.get("execution mode", ""), VALID_EXECUTION_MODES, "plan-only")

    acceptance_criteria = _coerce_list(sections.get("acceptance criteria", ""))
    constraints = _coerce_list(sections.get("constraints", ""))

    if not acceptance_criteria:
        warnings.append("missing_acceptance_criteria")

    task = NormalizedTask(
        event_id=delivery_id,
        task_key=task_key,
        title=title,
        description=body,
        target_repo=target_repo,
        target_branch=target_branch,
        task_type=task_type,
        risk_level=risk_level,
        execution_mode=execution_mode,
        acceptance_criteria=acceptance_criteria,
        constraints=constraints,
        requested_by=sender.get("login", "unknown"),
        issue=IssueRef(
            repo=repo_full_name,
            number=issue_number,
            url=issue.get("html_url", ""),
        ),
    )

    return TransformationResult(task=task, warnings=warnings)
