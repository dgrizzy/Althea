from app.clients.openclaw import OpenClawClient
from app.domain.models import ControlFlags, IssueRef, NormalizedTask


def _task() -> NormalizedTask:
    return NormalizedTask(
        event_id="delivery-1",
        task_key="gh:acme/althea-queue:issue:7",
        title="Implement endpoint",
        description="Please add endpoint X",
        target_repo="acme/service",
        target_branch="main",
        task_type="feature",
        risk_level="medium",
        execution_mode="execute",
        acceptance_criteria=["endpoint exists", "tests pass"],
        constraints=["no db migration"],
        requested_by="human",
        issue=IssueRef(repo="acme/althea-queue", number=7, url="https://github.com/acme/althea-queue/issues/7"),
        controls=ControlFlags(),
    )


def test_build_agent_payload_native_shape() -> None:
    client = OpenClawClient(
        hook_url="http://openclaw/hooks/agent",
        token="token",
        hook_name="GitHub",
        agent_id="main",
        deliver=False,
        wake_mode="now",
        allow_request_session_key=False,
    )

    payload = client.build_agent_payload(_task())

    assert payload["name"] == "GitHub"
    assert payload["agentId"] == "main"
    assert payload["wakeMode"] == "now"
    assert payload["deliver"] is False
    assert "message" in payload
    assert "Task Key: gh:acme/althea-queue:issue:7" in payload["message"]
    assert "sessionKey" not in payload


def test_build_agent_payload_includes_session_key_when_enabled() -> None:
    client = OpenClawClient(
        hook_url="http://openclaw/hooks/agent",
        token="token",
        allow_request_session_key=True,
    )

    payload = client.build_agent_payload(_task())

    assert payload["sessionKey"].startswith("hook:althea:")
    assert "/" not in payload["sessionKey"]
