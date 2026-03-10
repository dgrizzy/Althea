import json

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.security.github_signature import build_signature
from app.services.dispatcher import DispatcherService


class FakeOpenClawClient:
    def __init__(self, success: bool = True):
        self.success = success
        self.tasks = []

    async def dispatch_task(self, task):
        self.tasks.append(task)
        return type(
            "Result",
            (),
            {
                "success": self.success,
                "status_code": 200 if self.success else 500,
                "run_id": "run-999" if self.success else None,
                "error": None if self.success else "server_error",
                "retryable": not self.success,
            },
        )()


class FakeGitHubIssuesClient:
    def __init__(self):
        self.added = []
        self.comments = []

    async def add_labels(self, owner, repo, issue_number, labels):
        self.added.append((owner, repo, issue_number, labels))

    async def post_comment(self, owner, repo, issue_number, body):
        self.comments.append((owner, repo, issue_number, body))


def _settings() -> Settings:
    return Settings(
        GITHUB_WEBHOOK_SECRET="secret",
        OPENCLAW_HOOK_URL="http://example.com",
        OPENCLAW_HOOK_TOKEN="token",
        ALLOWED_REPOS="acme/althea-queue",
        ALLOWED_ORGS="acme",
    )


def _payload() -> dict:
    return {
        "action": "opened",
        "repository": {"full_name": "acme/althea-queue"},
        "issue": {
            "number": 7,
            "title": "Do task",
            "html_url": "https://github.com/acme/althea-queue/issues/7",
            "labels": [],
            "body": "### Target Repo\nacme/service\n\n### Task Type\nfeature\n",
        },
        "sender": {"login": "human"},
    }


def test_dispatch_success_writes_running_and_comment() -> None:
    settings = _settings()
    openclaw = FakeOpenClawClient(success=True)
    github = FakeGitHubIssuesClient()

    dispatcher = DispatcherService(settings, openclaw, github)
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    payload = _payload()
    body = json.dumps(payload).encode("utf-8")
    signature = build_signature("secret", body)

    response = client.post(
        "/webhooks/github",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "d-3",
            "X-Hub-Signature-256": signature,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["dispatched"] is True
    assert len(openclaw.tasks) == 1

    assert any("althea:running" in labels for _, _, _, labels in github.added)
    assert any("Dispatched to OpenClaw" in comment[-1] for comment in github.comments)


def test_dispatch_failure_sets_error_label() -> None:
    settings = _settings()
    openclaw = FakeOpenClawClient(success=False)
    github = FakeGitHubIssuesClient()

    dispatcher = DispatcherService(settings, openclaw, github)
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    payload = _payload()
    body = json.dumps(payload).encode("utf-8")
    signature = build_signature("secret", body)

    response = client.post(
        "/webhooks/github",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "d-4",
            "X-Hub-Signature-256": signature,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["dispatched"] is False
    assert any("althea:error" in labels for _, _, _, labels in github.added)


def test_dispatch_skips_when_target_repo_not_allowlisted() -> None:
    settings = Settings(
        GITHUB_WEBHOOK_SECRET="secret",
        OPENCLAW_HOOK_URL="http://example.com",
        OPENCLAW_HOOK_TOKEN="token",
        ALLOWED_REPOS="acme/althea-queue",
        ALLOWED_ORGS="acme",
        ALLOWED_TARGET_REPOS="acme/service-allowed",
    )
    openclaw = FakeOpenClawClient(success=True)
    github = FakeGitHubIssuesClient()

    dispatcher = DispatcherService(settings, openclaw, github)
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    payload = _payload()
    body = json.dumps(payload).encode("utf-8")
    signature = build_signature("secret", body)

    response = client.post(
        "/webhooks/github",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "d-5",
            "X-Hub-Signature-256": signature,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["dispatched"] is False
    assert data["reason"] == "target_repo_not_allowed"
    assert len(openclaw.tasks) == 0
