from app.domain.rules import should_dispatch_opened_issue, target_repo_is_allowed


def _payload(action: str = "opened", repo: str = "acme/althea-queue") -> dict:
    return {
        "action": action,
        "repository": {"full_name": repo},
        "issue": {
            "number": 42,
            "labels": [],
        },
        "sender": {"login": "human", "type": "User"},
    }


def test_dispatches_for_opened_issue() -> None:
    decision = should_dispatch_opened_issue(
        payload=_payload(),
        allowed_repos=["acme/althea-queue"],
        allowed_orgs=["acme"],
    )

    assert decision.should_dispatch is True
    assert decision.reason == "dispatch_on_open"


def test_does_not_dispatch_for_non_opened_action() -> None:
    decision = should_dispatch_opened_issue(
        payload=_payload(action="labeled"),
        allowed_repos=["acme/althea-queue"],
        allowed_orgs=["acme"],
    )

    assert decision.should_dispatch is False
    assert decision.reason == "not_opened_action"


def test_does_not_dispatch_for_disallowed_repo() -> None:
    decision = should_dispatch_opened_issue(
        payload=_payload(repo="other/repo"),
        allowed_repos=["acme/althea-queue"],
        allowed_orgs=["acme"],
    )

    assert decision.should_dispatch is False
    assert decision.reason == "repo_not_allowed"


def test_does_not_dispatch_for_bot_sender_by_default() -> None:
    payload = _payload()
    payload["sender"] = {"login": "dependabot[bot]", "type": "Bot"}
    decision = should_dispatch_opened_issue(
        payload=payload,
        allowed_repos=["acme/althea-queue"],
        allowed_orgs=["acme"],
    )

    assert decision.should_dispatch is False
    assert decision.reason == "sender_bot_disallowed"


def test_dispatches_for_bot_sender_when_allowed() -> None:
    payload = _payload()
    payload["sender"] = {"login": "dependabot[bot]", "type": "Bot"}
    decision = should_dispatch_opened_issue(
        payload=payload,
        allowed_repos=["acme/althea-queue"],
        allowed_orgs=["acme"],
        allow_bot_senders=True,
    )

    assert decision.should_dispatch is True
    assert decision.reason == "dispatch_on_open"


def test_sender_allowlist_is_enforced() -> None:
    decision = should_dispatch_opened_issue(
        payload=_payload(),
        allowed_repos=["acme/althea-queue"],
        allowed_orgs=["acme"],
        allowed_senders={"octocat"},
    )

    assert decision.should_dispatch is False
    assert decision.reason == "sender_not_allowlisted"


def test_target_repo_allowlist_matches_exact_repo() -> None:
    allowed, reason = target_repo_is_allowed(
        target_repo_full_name="acme/service-a",
        allowed_target_repos=["acme/service-a", "acme/service-b"],
        allowed_target_orgs=[],
    )

    assert allowed is True
    assert reason == "ok"


def test_target_repo_allowlist_blocks_unknown_repo() -> None:
    allowed, reason = target_repo_is_allowed(
        target_repo_full_name="acme/unknown",
        allowed_target_repos=["acme/service-a", "acme/service-b"],
        allowed_target_orgs=[],
    )

    assert allowed is False
    assert reason == "target_repo_not_allowed"
