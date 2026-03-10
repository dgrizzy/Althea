# Althea v1 Implementation Prompt (GitHub-Native Queue)

## Goal
Build Althea as a thin, secure adapter between GitHub Issues and OpenClaw:
- GitHub Issues/Project: system of record
- GitHub Webhook: event source
- Althea ingress service: verification + normalization + dispatch decision
- OpenClaw: execution engine
- Telegram/OpenClaw approvals: human safety gate

## Non-Goals (v1)
- No Notion integration
- No n8n in the critical dispatch path
- No multi-tenant auth model
- No autonomous destructive actions without approval

## Stack Decision
- Language: Python 3.12
- API framework: FastAPI
- HTTP client: `httpx`
- Validation: `pydantic`
- Test framework: `pytest`
- Container: Docker + Docker Compose

## Repository Layout
Use this exact structure:

```text
althea/
  pyproject.toml
  README.md
  .env.example
  docker-compose.yml
  Dockerfile
  docs/
    architecture.md
    operations.md
    github-setup.md
  app/
    __init__.py
    main.py
    config.py
    logging.py
    api/
      __init__.py
      health.py
      github_webhook.py
    domain/
      __init__.py
      events.py
      models.py
      rules.py
      transform.py
    security/
      __init__.py
      github_signature.py
    clients/
      __init__.py
      openclaw.py
      github_app.py
      github_issues.py
    services/
      __init__.py
      dispatcher.py
      status_sync.py
  tests/
    unit/
      test_github_signature.py
      test_rules.py
      test_transform.py
    integration/
      test_webhook_endpoint.py
      test_dispatch_flow.py
```

## Environment Contract
Support these variables:
- `GITHUB_WEBHOOK_SECRET` (required)
- `GITHUB_APP_ID` (required for status writeback)
- `GITHUB_APP_PRIVATE_KEY` (PEM string, required for status writeback)
- `GITHUB_INSTALLATION_ID` (required for status writeback)
- `OPENCLAW_HOOK_URL` (required)
- `OPENCLAW_HOOK_TOKEN` (required)
- `ALLOWED_REPOS` (comma-separated `owner/repo`)
- `ALLOWED_ORGS` (comma-separated org names)
- `LOG_LEVEL` (default `INFO`)
- `REQUEST_TIMEOUT_SECONDS` (default `15`)

## API Endpoints
Implement:

1. `GET /healthz`
- Returns: `{"status":"ok"}`
- No auth.

2. `POST /webhooks/github`
- Headers required:
  - `X-GitHub-Event`
  - `X-GitHub-Delivery`
  - `X-Hub-Signature-256`
- Body: raw GitHub webhook JSON.
- Behavior:
  - Verify HMAC SHA-256 signature from raw body and webhook secret.
  - Reject invalid/missing signature with HTTP `401`.
  - Reject unsupported events/actions with HTTP `202` and no-op decision.
  - Process supported events and, when eligible, dispatch to OpenClaw.
- Response shape:
  - `{"accepted":true|false,"reason":"...","delivery_id":"...","dispatched":true|false}`

## Supported GitHub Events (v1)
- `issues`:
  - `opened` -> validate and add `althea:queued` if missing
  - `edited` -> refresh normalized task summary comment (optional in v1)
  - `labeled` -> if label is `althea:approved`, evaluate dispatch rules
- Optional stretch:
  - `issue_comment.created` for operator commands

## Label Taxonomy
- `althea:queued`
- `althea:triaged`
- `althea:approved`
- `althea:running`
- `althea:blocked`
- `althea:review`
- `althea:done`
- `althea:error`

## Dispatch Rule Engine
Implement `domain/rules.py` with deterministic checks:
1. Repo allowlist check (`ALLOWED_REPOS` / `ALLOWED_ORGS`)
2. Event must be `issues.labeled`
3. Label must equal `althea:approved`
4. Issue must not include terminal labels (`althea:done`, `althea:error`)
5. Sender must not be bot-denied (configurable blocklist optional)

Return:
- `DispatchDecision(should_dispatch: bool, reason: str, task_key: str)`

`task_key` format:
- `gh:{owner}/{repo}:issue:{issue_number}`

## Normalized Task Contract (Althea -> OpenClaw)
Create a strict payload model in `domain/models.py`:

```json
{
  "source": "github",
  "event_id": "delivery-uuid",
  "task_key": "gh:org/repo:issue:123",
  "title": "Issue title",
  "description": "Issue body markdown",
  "target_repo": "org/target-repo",
  "target_branch": "main",
  "task_type": "bugfix|feature|ops|docs|other",
  "risk_level": "low|medium|high",
  "execution_mode": "plan-only|execute",
  "acceptance_criteria": ["..."],
  "constraints": ["..."],
  "requested_by": "github-login",
  "issue": {
    "repo": "org/althea-queue",
    "number": 123,
    "url": "https://github.com/org/althea-queue/issues/123"
  },
  "controls": {
    "require_human_approval": true,
    "allow_pr_open": true,
    "allow_issue_comment": true
  }
}
```

Notes:
- Parse structured fields from issue body (Markdown headings).
- If missing fields, apply defaults and include parse warnings in logs.

## OpenClaw Client Contract
Implement `clients/openclaw.py`:
- `POST {OPENCLAW_HOOK_URL}`
- Headers:
  - `Authorization: Bearer <OPENCLAW_HOOK_TOKEN>`
  - `Content-Type: application/json`
- Timeout: configurable
- On success: return external run/session id if present.
- On failure: emit structured error log and return retryable/non-retryable classification.

## GitHub Writeback Contract
Implement in `clients/github_issues.py`:
- Add/remove labels
- Post issue comment
- Update project fields (stub + interface in v1; full implementation can be phase 2)

Minimum v1 writeback behavior:
- On dispatch start:
  - add `althea:running`
  - remove `althea:approved`
  - comment: "Dispatched to OpenClaw. Delivery: `<delivery_id>`."
- On dispatch failure:
  - add `althea:error`
  - comment with error classification

Use GitHub App installation token flow in `clients/github_app.py`.

## Security Requirements
- Verify `X-Hub-Signature-256` against raw bytes exactly.
- Use constant-time comparison.
- Do not process requests with missing signature.
- Log:
  - `delivery_id`
  - `event`
  - `action`
  - `repo`
  - decision outcome
- Never log secrets or full auth headers.

## Logging Format
JSON structured logs to stdout:
- `timestamp`
- `level`
- `message`
- `delivery_id`
- `task_key` (if available)
- `decision`
- `error_type` (if any)

## Docker/Compose
`docker-compose.yml` services:
1. `althea` (FastAPI service)
2. `mock-openclaw` (simple HTTP mock for local integration tests)

Expose only ingress service port for local development (e.g., `8080`).

## Test Plan
Implement at least these tests:

1. Signature Verification
- Valid signature accepted
- Invalid signature rejected
- Missing signature rejected
- Payload tampering rejected

2. Event Filtering
- Unsupported event no-ops with `202`
- `issues.labeled` with non-approved label no dispatch
- `issues.labeled` with `althea:approved` dispatches

3. Transformation
- Parses structured fields correctly
- Applies safe defaults on missing fields
- Produces deterministic `task_key`

4. Dispatch Flow
- Successful OpenClaw call updates labels/comments
- OpenClaw error sets `althea:error`

5. Repo Policy
- Allowed repo passes
- Disallowed repo rejected

## Issue Form Spec (althea-queue)
Create `.github/ISSUE_TEMPLATE/althea_task.yml` with fields:
- Task type (dropdown)
- Target repo (input)
- Target branch (input)
- Risk level (dropdown)
- Execution mode (dropdown)
- Desired outcome (textarea)
- Acceptance criteria (textarea)
- Constraints (textarea)

## Execution Sequence (Implementation)
1. Scaffold project and baseline FastAPI app.
2. Add config + structured logging.
3. Implement signature verification.
4. Implement webhook endpoint + event parsing.
5. Implement dispatch rule engine.
6. Implement transformation to normalized OpenClaw payload.
7. Implement OpenClaw client and send flow.
8. Implement minimal GitHub writeback client.
9. Add tests.
10. Add Docker/Compose and docs.

## Definition of Done (v1)
- Webhook endpoint verifies GitHub signatures.
- `althea:approved` label causes eligible task dispatch.
- Invalid signatures are rejected.
- OpenClaw receives normalized payload.
- GitHub issue receives dispatch status comment and labels.
- Test suite passes locally.
- Docker Compose starts service and mock dependency.

## Constraints for the Implementing Agent
- Keep service stateless.
- Avoid introducing a DB in v1.
- Prefer explicit types and small pure functions.
- Keep policy logic in `domain/rules.py` for testability.
- Do not couple webhook parsing directly to OpenClaw client calls; use service layer.
