# GitHub Secure Channel Setup (amplify-bots)

Use this checklist to securely connect GitHub -> Althea -> OpenClaw.

## 1) Create queue repository

Create: `<your-org>/amplify-bots-queue`

- Add issue form from `.github/ISSUE_TEMPLATE/althea_task.yml`
- Add labels:
  - `althea:queued`
  - `althea:triaged`
  - `althea:running`
  - `althea:blocked`
  - `althea:review`
  - `althea:done`
  - `althea:error`

## 2) Create a GitHub App (preferred over PAT)

App scope:

- Install only on repos Althea needs.
- Repository permissions:
  - `Issues: Read and write`
  - `Metadata: Read-only`
  - `Pull requests: Read and write` (if you want PR linking)

Subscribe to events:

- `Issues`
- `Issue comment` (optional for later controls)
- `Pull request` (optional for review sync)

After creation, capture:

- App ID -> `GITHUB_APP_ID`
- Installation ID -> `GITHUB_INSTALLATION_ID`
- Private key PEM -> `GITHUB_APP_PRIVATE_KEY`

## 3) Configure repository webhook

On `<your-org>/amplify-bots-queue`:

- Payload URL: Terraform output `webhook_url` (HTTPS recommended via `enable_caddy_https=true`)
- Content type: `application/json`
- Secret: same value as `GITHUB_WEBHOOK_SECRET`
- Events: send individual events for `Issues` (and optional extras)
- Active: enabled

## 4) Configure Althea sender policy

In Althea `.env`:

- `ALLOWED_REPOS=<your-org>/amplify-bots-queue`
- `ALLOWED_ORGS=<your-org>`
- `ALLOWED_TARGET_REPOS=<your-org>/repo-a,<your-org>/repo-b`
- `ALLOWED_TARGET_ORGS=<your-org>`
- `ALLOWED_GITHUB_SENDERS=<comma-separated maintainers>`
- `BLOCKED_GITHUB_SENDERS=<comma-separated blocked accounts>`
- `ALLOW_BOT_SENDERS=false`

Keep webhook protections enabled:

- `RATE_LIMIT_ENABLED=true`
- `DELIVERY_REPLAY_TTL_SECONDS=3600`

## 5) Configure OpenClaw hook auth

- `OPENCLAW_HOOK_URL=http://127.0.0.1:18789/hooks/agent`
- `OPENCLAW_HOOK_TOKEN=<long random token>`

OpenClaw should accept only the required agent IDs and run with approvals enabled.

## 6) End-to-end verification

1. Create issue in `amplify-bots-queue` via issue form.
2. Confirm GitHub `issues.opened` delivery is `2xx`.
3. Confirm Althea returns `{"reason":"dispatched","dispatched":true}` for that delivery.
4. Confirm Althea comments/labels transition.
5. Confirm OpenClaw receives task and approval flow is enforced.

## 7) Ongoing security hygiene

- Rotate webhook secret and hook token on schedule.
- Rotate GitHub App private key.
- Keep GitHub App permissions minimal.
- Audit who can open issues in the queue repository.
