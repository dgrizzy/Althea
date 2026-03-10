from __future__ import annotations

from app.domain.events import TERMINAL_LABELS
from app.domain.models import DispatchDecision


def build_task_key(repo_full_name: str, issue_number: int) -> str:
    return f"gh:{repo_full_name}:issue:{issue_number}"


def repo_is_allowed(repo_full_name: str, allowed_repos: list[str], allowed_orgs: list[str]) -> tuple[bool, str]:
    owner = repo_full_name.split("/", 1)[0] if "/" in repo_full_name else ""

    if allowed_repos and repo_full_name not in allowed_repos:
        return False, "repo_not_allowed"

    if allowed_orgs and owner not in allowed_orgs:
        return False, "org_not_allowed"

    return True, "ok"


def target_repo_is_allowed(
    target_repo_full_name: str,
    allowed_target_repos: list[str],
    allowed_target_orgs: list[str],
) -> tuple[bool, str]:
    owner = target_repo_full_name.split("/", 1)[0] if "/" in target_repo_full_name else ""

    if allowed_target_repos and target_repo_full_name not in allowed_target_repos:
        return False, "target_repo_not_allowed"

    if allowed_target_orgs and owner not in allowed_target_orgs:
        return False, "target_org_not_allowed"

    return True, "ok"


def should_dispatch_opened_issue(
    payload: dict,
    allowed_repos: list[str],
    allowed_orgs: list[str],
    allowed_senders: set[str] | None = None,
    blocked_senders: set[str] | None = None,
    allow_bot_senders: bool = False,
) -> DispatchDecision:
    allowed_senders = allowed_senders or set()
    blocked_senders = blocked_senders or set()

    action = payload.get("action")
    if action != "opened":
        return DispatchDecision(should_dispatch=False, reason="not_opened_action")

    repo_full_name = payload.get("repository", {}).get("full_name", "")
    issue_number = payload.get("issue", {}).get("number")
    if not repo_full_name or not issue_number:
        return DispatchDecision(should_dispatch=False, reason="missing_issue_context")

    task_key = build_task_key(repo_full_name, int(issue_number))

    allowed, reason = repo_is_allowed(repo_full_name, allowed_repos, allowed_orgs)
    if not allowed:
        return DispatchDecision(should_dispatch=False, reason=reason, task_key=task_key)

    sender = payload.get("sender", {})
    sender_login = sender.get("login", "")
    sender_type = (sender.get("type") or "").lower()

    if not sender_login:
        return DispatchDecision(should_dispatch=False, reason="sender_missing", task_key=task_key)

    if sender_login in blocked_senders:
        return DispatchDecision(should_dispatch=False, reason="sender_blocked", task_key=task_key)

    if allowed_senders and sender_login not in allowed_senders:
        return DispatchDecision(should_dispatch=False, reason="sender_not_allowlisted", task_key=task_key)

    sender_looks_bot = sender_type == "bot" or sender_login.endswith("[bot]")
    if sender_looks_bot and not allow_bot_senders:
        return DispatchDecision(should_dispatch=False, reason="sender_bot_disallowed", task_key=task_key)

    existing_labels = {item.get("name") for item in payload.get("issue", {}).get("labels", [])}
    if existing_labels.intersection(TERMINAL_LABELS):
        return DispatchDecision(should_dispatch=False, reason="terminal_state", task_key=task_key)

    return DispatchDecision(should_dispatch=True, reason="dispatch_on_open", task_key=task_key)
