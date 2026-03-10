from app.domain.transform import transform_issue_to_task


def test_transform_parses_markdown_fields() -> None:
    payload = {
        "repository": {"full_name": "acme/althea-queue"},
        "sender": {"login": "requester"},
        "issue": {
            "number": 9,
            "title": "Add feature",
            "html_url": "https://github.com/acme/althea-queue/issues/9",
            "body": """### Target Repo
acme/service-repo

### Target Branch
main

### Task Type
feature

### Risk Level
low

### Execution Mode
execute

### Acceptance Criteria
- endpoint added
- tests pass

### Constraints
- no db migrations
""",
        },
    }

    result = transform_issue_to_task(payload, delivery_id="d-1")

    assert result.task.task_key == "gh:acme/althea-queue:issue:9"
    assert result.task.target_repo == "acme/service-repo"
    assert result.task.task_type == "feature"
    assert result.task.risk_level == "low"
    assert result.task.execution_mode == "execute"
    assert result.task.acceptance_criteria == ["endpoint added", "tests pass"]
    assert result.task.constraints == ["no db migrations"]


def test_transform_applies_safe_defaults() -> None:
    payload = {
        "repository": {"full_name": "acme/althea-queue"},
        "sender": {"login": "requester"},
        "issue": {
            "number": 10,
            "title": "No structure",
            "html_url": "https://github.com/acme/althea-queue/issues/10",
            "body": "free-form issue body",
        },
    }

    result = transform_issue_to_task(payload, delivery_id="d-2")

    assert result.task.target_repo == "acme/althea-queue"
    assert result.task.target_branch == "main"
    assert result.task.task_type == "other"
    assert result.task.risk_level == "medium"
    assert result.task.execution_mode == "plan-only"
    assert "missing_target_repo_defaulted" in result.warnings
