import json

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.security.github_signature import build_signature
from app.services.dispatcher import DispatcherService


class FakeOpenClawClient:
    async def dispatch_task(self, task):
        return type("Result", (), {"success": True, "status_code": 200, "run_id": "run-123", "error": None, "retryable": False})()


class FakeGitHubIssuesClient:
    async def add_labels(self, owner, repo, issue_number, labels):
        return None

    async def remove_label(self, owner, repo, issue_number, label):
        return None

    async def post_comment(self, owner, repo, issue_number, body):
        return None


def _settings() -> Settings:
    return Settings(
        GITHUB_WEBHOOK_SECRET="secret",
        OPENCLAW_HOOK_URL="http://example.com",
        OPENCLAW_HOOK_TOKEN="token",
        ALLOWED_REPOS="acme/althea-queue",
        ALLOWED_ORGS="acme",
    )


def _payload(action: str = "opened") -> dict:
    return {
        "action": action,
        "repository": {"full_name": "acme/althea-queue"},
        "issue": {
            "number": 1,
            "title": "hello",
            "html_url": "https://github.com/acme/althea-queue/issues/1",
            "labels": [],
            "body": "### Target Repo\nacme/service\n",
        },
        "sender": {"login": "human"},
    }


def test_invalid_signature_rejected() -> None:
    settings = _settings()
    dispatcher = DispatcherService(settings, FakeOpenClawClient(), FakeGitHubIssuesClient())
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    response = client.post(
        "/webhooks/github",
        json=_payload(),
        headers={
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "d-1",
            "X-Hub-Signature-256": "sha256=bad",
        },
    )

    assert response.status_code == 401


def test_unsupported_event_returns_202() -> None:
    settings = _settings()
    dispatcher = DispatcherService(settings, FakeOpenClawClient(), FakeGitHubIssuesClient())
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
            "X-GitHub-Event": "push",
            "X-GitHub-Delivery": "d-2",
            "X-Hub-Signature-256": signature,
        },
    )

    assert response.status_code == 202
    assert response.json()["accepted"] is False


def test_duplicate_delivery_id_returns_202() -> None:
    settings = _settings()
    dispatcher = DispatcherService(settings, FakeOpenClawClient(), FakeGitHubIssuesClient())
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    payload = _payload(action="edited")
    body = json.dumps(payload).encode("utf-8")
    signature = build_signature("secret", body)
    headers = {
        "Content-Type": "application/json",
        "X-GitHub-Event": "issues",
        "X-GitHub-Delivery": "dup-1",
        "X-Hub-Signature-256": signature,
    }

    first = client.post("/webhooks/github", content=body, headers=headers)
    second = client.post("/webhooks/github", content=body, headers=headers)

    assert first.status_code == 200
    assert second.status_code == 202
    assert second.json()["reason"] == "duplicate_delivery"


def test_rate_limit_returns_429() -> None:
    settings = Settings(
        GITHUB_WEBHOOK_SECRET="secret",
        OPENCLAW_HOOK_URL="http://example.com",
        OPENCLAW_HOOK_TOKEN="token",
        ALLOWED_REPOS="acme/althea-queue",
        ALLOWED_ORGS="acme",
        RATE_LIMIT_ENABLED=True,
        RATE_LIMIT_WINDOW_SECONDS=60,
        RATE_LIMIT_MAX_REQUESTS=1,
    )
    dispatcher = DispatcherService(settings, FakeOpenClawClient(), FakeGitHubIssuesClient())
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    payload = _payload(action="edited")
    body = json.dumps(payload).encode("utf-8")
    signature = build_signature("secret", body)

    response_1 = client.post(
        "/webhooks/github",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "rl-1",
            "X-Hub-Signature-256": signature,
        },
    )
    response_2 = client.post(
        "/webhooks/github",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "rl-2",
            "X-Hub-Signature-256": signature,
        },
    )

    assert response_1.status_code == 200
    assert response_2.status_code == 429
    assert response_2.json()["detail"] == "rate_limited"


def test_labeled_action_returns_no_dispatch() -> None:
    settings = _settings()
    dispatcher = DispatcherService(settings, FakeOpenClawClient(), FakeGitHubIssuesClient())
    app = create_app(settings=settings, dispatcher=dispatcher)
    client = TestClient(app)

    payload = _payload(action="labeled")
    body = json.dumps(payload).encode("utf-8")
    signature = build_signature("secret", body)

    response = client.post(
        "/webhooks/github",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": "issues",
            "X-GitHub-Delivery": "lbl-1",
            "X-Hub-Signature-256": signature,
        },
    )

    assert response.status_code == 200
    assert response.json()["reason"] == "issue_labeled_no_dispatch"
    assert response.json()["dispatched"] is False
